/*
 * writ_mem.cc - Genode host binding code for the Bend runtime's memory
 * calls. This is host binding code, not Writ policy: it makes no
 * authority, label, budget, or release decision, and nothing in it is
 * consulted by Writ's Bend verification. It is the memory part of the
 * single authored C++ unit GB-006 allows in a Bend component (the shim);
 * see hosts/genode/INVENTORY.md for its exported symbols and sessions.
 *
 * What it supplies, and why. Genode 26.08's libc commits and zeroes every
 * anonymous mmap from the component's RAM quota
 * (repos/libports/src/lib/libc/file_operations.cc:648-671) and its
 * mprotect is a weak dummy returning -1 (repos/libports/src/lib/libc/
 * dummies.cc:126). The Bend runtime reserves an 8 GiB term heap and a
 * 2 GiB evaluation stack per lane and places a 16 KiB PROT_NONE guard
 * page above each stack. This unit gives exactly those reservations
 * reserve-now, charge-on-touch semantics and a real, faulting guard.
 *
 * Scope. Only mmap(addr-hint, len >= 1 GiB, PROT_READ|PROT_WRITE,
 * MAP_PRIVATE|MAP_ANON, -1, 0) without MAP_FIXED or MAP_SHARED is
 * handled here ("qualifying"). Every other mmap, and mprotect/munmap on
 * ranges that do not touch a qualifying reservation, is forwarded to the
 * libc implementation looked up in libc.lib.so at component construction.
 *
 * Mechanism. A qualifying mmap creates a region map of the requested size
 * through an RM session (repos/base/include/rm_session/connection.h,
 * Rm_connection::create) and attaches its dataspace into the component's
 * address space (Env::rm(), repos/base/include/base/local.h); nothing is
 * populated, so no RAM is charged. The first touch of an unpopulated
 * 2 MiB chunk faults; the fault handler allocates a 2 MiB RAM dataspace
 * from the component's own PD (Pd_session::alloc_ram,
 * repos/base/include/pd_session/pd_session.h:120) and attaches it at the
 * chunk's offset in the region map (Region_map_client::attach,
 * repos/base/include/region_map/client.h). The faulting access is then
 * retried and succeeds.
 *
 * Guards. mprotect(PROT_NONE) on a page-aligned range inside a
 * reservation records the range as a guard. Any populated chunk that
 * overlaps it is detached and its same dataspace re-attached in pieces
 * that leave the guard range unmapped, so data outside the guard is kept
 * and the guard has no mapping. The fault handler never populates a
 * guard range: a touch there is refused and the component dies. mprotect
 * is never a no-op: a request this unit cannot carry out exactly fails
 * with -1.
 *
 * Fault delivery (base-linux only). On base-linux the Region_map fault
 * signal is never delivered: region_map.h documents it ("On Linux, this
 * signal is never delivered because page-fault handling is performed by
 * the Linux kernel"), Region_map_client::fault_handler is an empty body
 * (repos/base-linux/src/lib/base/region_map_client.cc:49-56), and an
 * unpopulated part of a managed dataspace is a PROT_NONE Linux mapping
 * (repos/base-linux/src/lib/base/region_map_mmap.cc:76-119). This unit
 * therefore installs a Linux SIGSEGV handler with the raw rt_sigaction
 * system call, the same way base-linux installs its own exception
 * handler (repos/base-linux/src/lib/base/thread_env.cc:42-73,
 * repos/base-linux/src/lib/syscall/linux_syscalls.h:347-378). It is
 * installed at the first qualifying mmap and replaces base-linux's
 * handler process-wide. The handler resolves the fault on the faulting
 * thread, which makes a PD RPC from signal context; that is acceptable
 * for the probe, and is recorded as a limit. On kernels where Genode
 * delivers region-map faults (base-hw, NOVA, seL4) the front end must be
 * the Region_map fault signal handled on a separate entrypoint instead;
 * that front end is not built here and nothing in this file claims it.
 *
 * Failure behaviour. Every refusal kills the component: a fault on a
 * guard, on a populated chunk (cannot be resolved by populating again),
 * outside every reservation, or a fault whose chunk cannot be charged
 * because the PD's remaining RAM quota is smaller than a chunk (checked
 * before alloc_ram, so the fault never turns into a blocking resource
 * request). A refusal prints one line with Genode::raw, restores the
 * default SIGSEGV action, and returns; the retried access then faults
 * again and Linux terminates the process.
 */

/* Genode includes */
#include <base/heap.h>
#include <base/log.h>
#include <base/mutex.h>
#include <base/shared_object.h>
#include <libc/component.h>
#include <libc/args.h>
#include <region_map/client.h>
#include <rm_session/connection.h>
#include <util/reconstructible.h>

/* libc includes (FreeBSD 12.0 constants: MAP_*, PROT_*, errno values) */
#include <errno.h>
#include <stdlib.h>
#include <sys/mman.h>

using namespace Genode;


/********************
 ** Static bounds  **
 ********************/

/*
 * GB-006 bounds. The runtime makes one heap reservation and one stack
 * reservation per lane (at most 128 lanes, but a component's quota is the
 * practical bound); a reservation carries at most one guard in the
 * runtime's use.
 */
enum : size_t {
	MIN_QUALIFYING = 1ul << 30,   /* 1 GiB: smaller requests go to libc */
	CHUNK          = 2ul << 20,   /* populate granularity, 2 MiB       */
	PAGE           = 4096,
	MAX_RESERVATIONS = 32,
	MAX_GUARDS       = 4,
};


/*****************************************
 ** Linux ABI pieces (base-linux only)  **
 *****************************************/

/*
 * Genode's libc headers are FreeBSD's, so the Linux values are spelled out
 * here (x86_64 Linux UAPI) rather than taken from <signal.h>.
 */
enum : unsigned long {
	LX_SYS_RT_SIGACTION = 13,
	LX_SIGSEGV          = 11,
	LX_SA_SIGINFO       = 0x00000004,
	LX_SA_RESTORER      = 0x04000000,
	LX_SA_ONSTACK       = 0x08000000,
	LX_SA_RESTART       = 0x10000000,
	LX_SIG_DFL          = 0,
};

struct Lx_siginfo   /* leading fields of Linux siginfo_t for SIGSEGV */
{
	int   signo, err, code, pad;
	void *addr;      /* si_addr: the faulting address */
};

struct Lx_sigaction /* struct kernel_sigaction, x86_64 */
{
	void         (*handler)(int, Lx_siginfo *, void *);
	unsigned long  flags;
	void         (*restorer)(void);
	unsigned long  mask;   /* 64 signals, sigsetsize 8 */
};

/* Restorer for SA_RESTORER: issue rt_sigreturn (as lx_restore_rt.S). */
extern "C" void writ_mem_restore_rt(void);
asm(".text\n"
    ".type writ_mem_restore_rt, @function\n"
    "writ_mem_restore_rt:\n"
    "\tmovq $15, %rax\n"
    "\tsyscall\n");

static long lx_rt_sigaction(unsigned long sig, Lx_sigaction const *act)
{
	long ret;
	register unsigned long r10 asm("r10") = 8;  /* sigsetsize */
	asm volatile ("syscall"
	              : "=a" (ret)
	              : "0" (LX_SYS_RT_SIGACTION), "D" (sig), "S" (act),
	                "d" (0ul), "r" (r10)
	              : "rcx", "r11", "memory");
	return ret;
}


/************************
 ** Reservation table  **
 ************************/

static constexpr size_t _page_round(size_t n) { return (n + PAGE - 1) & ~(size_t(PAGE) - 1); }

struct Guard { addr_t off, len; };  /* offsets relative to the base */

struct Chunk { Ram_dataspace_capability ds { }; bool populated = false; };

struct Reservation
{
	bool                     used       = false;
	addr_t                   base       = 0;   /* local address of the region map */
	size_t                   size       = 0;   /* page-rounded length */
	Capability<Region_map>   rm_cap     { };
	Chunk                   *chunks     = nullptr;  /* size / CHUNK, rounded up */
	size_t                   num_chunks = 0;
	Guard                    guards[MAX_GUARDS] { };
	unsigned                 num_guards = 0;

	bool contains(addr_t a) const { return used && a >= base && a - base < size; }

	bool in_guard(addr_t off) const
	{
		for (unsigned i = 0; i < num_guards; i++)
			if (off >= guards[i].off && off - guards[i].off < guards[i].len)
				return true;
		return false;
	}

	/*
	 * Call fn(start, end) for each maximal sub-range of [c, e) that lies
	 * outside every guard. These are the pieces a populated chunk is
	 * attached as, so guard ranges never carry a mapping.
	 */
	void for_each_piece(addr_t c, addr_t e, auto const &fn) const
	{
		addr_t pos = c;
		while (pos < e) {
			bool skipped = false;
			for (unsigned i = 0; i < num_guards; i++) {
				Guard const &g = guards[i];
				if (pos >= g.off && pos - g.off < g.len) {
					pos = g.off + g.len; skipped = true; break; }
			}
			if (skipped) continue;
			addr_t next = e;
			for (unsigned i = 0; i < num_guards; i++)
				if (guards[i].off > pos && guards[i].off < next)
					next = guards[i].off;
			fn(pos, next);
			pos = next;
		}
	}

	addr_t chunk_end(size_t idx) const { return min((idx + 1)*CHUNK, size); }
};


/*****************
 ** Shim state  **
 *****************/

using Mmap_fn     = void *(*)(void *, ::size_t, int, int, int, ::off_t);
using Munmap_fn   = int    (*)(void *, ::size_t);
using Mprotect_fn = int    (*)(void *, ::size_t, int);

static Env                         *_env;
static Constructible<Heap>          _heap;
static Constructible<Rm_connection> _rm_connection;
static Mmap_fn                      _libc_mmap;
static Munmap_fn                    _libc_munmap;
static Mprotect_fn                  _libc_mprotect;
static bool                         _fault_handler_installed;
static Reservation                  _res[MAX_RESERVATIONS];

/* counters for writ_mem_report (diagnostics only) */
static unsigned long _chunks_populated, _faults_resolved;

static Mutex &_mutex() { static Mutex m { }; return m; }

static Reservation *_lookup(addr_t a)
{
	for (Reservation &r : _res)
		if (r.contains(a)) return &r;
	return nullptr;
}


/*****************************
 ** Population and pieces   **
 *****************************/

static Region_map::Attr _piece_attr(addr_t start, addr_t end, addr_t c)
{
	return { .size = end - start, .offset = start - c, .use_at = true,
	         .at = start, .executable = false, .writeable = true };
}

/* Attach chunk idx's dataspace as the pieces outside the guards. */
static bool _attach_pieces(Reservation &r, size_t idx)
{
	Region_map_client rm(r.rm_cap);
	addr_t const c = idx*CHUNK, e = r.chunk_end(idx);
	bool ok = true;
	r.for_each_piece(c, e, [&] (addr_t s, addr_t t) {
		if (rm.attach(r.chunks[idx].ds, _piece_attr(s, t, c)).failed())
			ok = false; });
	return ok;
}

static void _detach_pieces(Reservation &r, size_t idx)
{
	Region_map_client rm(r.rm_cap);
	r.for_each_piece(idx*CHUNK, r.chunk_end(idx), [&] (addr_t s, addr_t) {
		rm.detach(s); });
}

/*
 * Populate the chunk containing offset off. Refuses (returns false)
 * without allocating if the PD's remaining quota cannot cover the chunk.
 */
static bool _populate(Reservation &r, addr_t off)
{
	size_t const idx = off / CHUNK;
	if (r.chunks[idx].populated) return false;

	size_t const len = _page_round(r.chunk_end(idx) - idx*CHUNK);

	if (_env->pd().stats().ram.avail().value < len + 64*1024)
		return false;

	Ram_dataspace_capability ds { };
	_env->pd().alloc_ram(len).with_result(
		[&] (Ram_dataspace_capability cap) { ds = cap; },
		[&] (Alloc_error) { });
	if (!ds.valid()) return false;

	r.chunks[idx] = { ds, true };
	if (!_attach_pieces(r, idx)) {
		_detach_pieces(r, idx);
		_env->pd().free_ram(ds);
		r.chunks[idx] = { { }, false };
		return false;
	}
	_chunks_populated++;
	return true;
}


/**********************
 ** Fault front end  **
 **********************/

static void _refuse(char const *why, addr_t a)
{
	raw("writ_mem: unresolved fault at ", Hex(a), " (", why,
	    "), component terminates");
	Lx_sigaction dfl { (void (*)(int, Lx_siginfo *, void *))LX_SIG_DFL,
	                   0, nullptr, 0 };
	lx_rt_sigaction(LX_SIGSEGV, &dfl);
}

static void _segv_handler(int, Lx_siginfo *info, void *)
{
	addr_t const a = addr_t(info->addr);

	Mutex::Guard guard(_mutex());

	Reservation *r = _lookup(a);
	if (!r)                         { _refuse("outside every reservation", a); return; }
	addr_t const off = a - r->base;
	if (r->in_guard(off))           { _refuse("guard page", a); return; }
	if (r->chunks[off/CHUNK].populated)
	                                { _refuse("populated chunk", a); return; }
	if (!_populate(*r, off))        { _refuse("chunk could not be charged", a); return; }

	_faults_resolved++;
	/* returning retries the access, which now hits the attached chunk */
}

static void _install_fault_handler()
{
	if (_fault_handler_installed) return;
	Lx_sigaction act { _segv_handler,
	                   LX_SA_SIGINFO | LX_SA_RESTORER | LX_SA_RESTART | LX_SA_ONSTACK,
	                   writ_mem_restore_rt, 0 };
	if (lx_rt_sigaction(LX_SIGSEGV, &act) != 0) {
		error("writ_mem: rt_sigaction(SIGSEGV) failed");
		return;
	}
	_fault_handler_installed = true;
}


/********************************
 ** Reservation create/destroy **
 ********************************/

static bool _qualifies(size_t len, int prot, int flags, int fd, ::off_t offset)
{
	return len >= MIN_QUALIFYING
	    && prot == (PROT_READ | PROT_WRITE)
	    && (flags & MAP_ANON) && (flags & MAP_PRIVATE)
	    && !(flags & (MAP_FIXED | MAP_SHARED))
	    && fd == -1 && offset == 0;
}

static void *_reserve(void *hint, size_t len)
{
	Reservation *r = nullptr;
	for (Reservation &cand : _res)
		if (!cand.used) { r = &cand; break; }
	if (!r) { errno = ENOMEM; return MAP_FAILED; }

	if (!_fault_handler_installed) _install_fault_handler();
	if (!_fault_handler_installed) { errno = ENOMEM; return MAP_FAILED; }

	size_t const size = _page_round(len);
	size_t const num_chunks = (size + CHUNK - 1) / CHUNK;

	Chunk *chunks = nullptr;
	if (_heap->try_alloc(num_chunks*sizeof(Chunk)).convert<bool>(
	        [&] (Memory::Allocation &a) {
	            a.deallocate = false; chunks = (Chunk *)a.ptr; return true; },
	        [&] (Alloc_error) { return false; }) == false) {
		errno = ENOMEM; return MAP_FAILED; }
	for (size_t i = 0; i < num_chunks; i++) construct_at<Chunk>(&chunks[i]);

	if (!_rm_connection.constructed()) _rm_connection.construct(*_env);
	Capability<Region_map> rm_cap = _rm_connection->create(size);
	if (!rm_cap.valid()) {
		_heap->free(chunks, num_chunks*sizeof(Chunk));
		errno = ENOMEM; return MAP_FAILED;
	}

	/*
	 * Linux treats the address as a hint: try it, then let the local
	 * region map choose. The runtime compares the result with its hint
	 * and unmaps a misplaced reservation itself.
	 */
	Region_map_client rm(rm_cap);
	auto attach_at = [&] (bool use_at, addr_t at) -> addr_t {
		return _env->rm().attach(rm.dataspace(), {
			.size = 0, .offset = 0, .use_at = use_at, .at = at,
			.executable = false, .writeable = true
		}).convert<addr_t>(
			[&] (Env::Local_rm::Attachment &a) {
				a.deallocate = false; return addr_t(a.ptr); },
			[&] (Env::Local_rm::Error) { return addr_t(0); });
	};
	addr_t base = 0;
	if (hint && (addr_t(hint) & (PAGE - 1)) == 0)
		base = attach_at(true, addr_t(hint));
	if (!base)
		base = attach_at(false, 0);
	if (!base) {
		_rm_connection->destroy(rm_cap);
		_heap->free(chunks, num_chunks*sizeof(Chunk));
		errno = ENOMEM; return MAP_FAILED;
	}

	*r = { .used = true, .base = base, .size = size, .rm_cap = rm_cap,
	       .chunks = chunks, .num_chunks = num_chunks, .guards = { },
	       .num_guards = 0 };
	return (void *)base;
}

static void _release(Reservation &r)
{
	for (size_t i = 0; i < r.num_chunks; i++)
		if (r.chunks[i].populated) {
			_detach_pieces(r, i);
			_env->pd().free_ram(r.chunks[i].ds);
		}
	/* Local_rm_session::destroy also detaches the region map locally */
	_env->rm().detach(r.base);
	_rm_connection->destroy(r.rm_cap);
	_heap->free(r.chunks, r.num_chunks*sizeof(Chunk));
	r = { };
}


/****************************
 ** Exported entry points  **
 ****************************/

/*
 * Public entry points: mmap, munmap, mprotect (POSIX signatures, called by
 * the Bend runtime and the probe). writ_mem_report is a diagnostics helper
 * for the probes only. Libc::Component::construct is the component entry.
 */

extern "C" void *mmap(void *addr, ::size_t len, int prot, int flags,
                      int fd, ::off_t offset)
{
	if (!_qualifies(len, prot, flags, fd, offset))
		return _libc_mmap(addr, len, prot, flags, fd, offset);

	Mutex::Guard guard(_mutex());
	return _reserve(addr, len);
}

extern "C" int munmap(void *addr, ::size_t len)
{
	addr_t const a = addr_t(addr), e = a + len;
	{
		Mutex::Guard guard(_mutex());
		for (Reservation &r : _res) {
			if (!r.used || e <= r.base || a >= r.base + r.size) continue;
			/* only the whole reservation can be unmapped */
			if (a != r.base || _page_round(len) != r.size) {
				errno = EINVAL; return -1; }
			_release(r);
			return 0;
		}
	}
	return _libc_munmap(addr, len);
}

extern "C" int mprotect(void *addr, ::size_t len, int prot)
{
	addr_t const a = addr_t(addr);
	size_t const n = _page_round(len);

	Mutex::Guard guard(_mutex());

	Reservation *r = nullptr;
	for (Reservation &cand : _res)
		if (cand.used && a < cand.base + cand.size && a + n > cand.base) {
			r = &cand; break; }
	if (!r) return _libc_mprotect(addr, len, prot);

	addr_t const off = a - r->base;
	if ((a & (PAGE - 1)) || len == 0 || a < r->base || off + n > r->size) {
		errno = EINVAL; return -1; }

	auto overlaps_guard = [&] {
		for (unsigned i = 0; i < r->num_guards; i++)
			if (off < r->guards[i].off + r->guards[i].len
			 && r->guards[i].off < off + n) return true;
		return false; };

	if (prot == (PROT_READ | PROT_WRITE)) {
		/* already readable and writeable unless a guard is involved;
		 * lifting a guard is not supported */
		if (overlaps_guard()) { errno = ENOTSUP; return -1; }
		return 0;
	}

	if (prot != PROT_NONE) { errno = ENOTSUP; return -1; }
	if (overlaps_guard())  { errno = ENOTSUP; return -1; }
	if (r->num_guards == MAX_GUARDS) { errno = ENOMEM; return -1; }

	/* detach the pieces of each populated chunk the guard will split */
	size_t const first = off / CHUNK, last = (off + n - 1) / CHUNK;
	for (size_t i = first; i <= last; i++)
		if (r->chunks[i].populated) _detach_pieces(*r, i);

	r->guards[r->num_guards++] = { off, n };

	/* re-attach the same dataspaces around the guard: data is kept */
	bool ok = true;
	for (size_t i = first; i <= last; i++)
		if (r->chunks[i].populated && !_attach_pieces(*r, i)) ok = false;

	if (!ok) {
		/*
		 * The guard range itself is unmapped either way (it is never a
		 * piece), so the guard holds; data outside it may be unreachable.
		 */
		errno = ENOMEM; return -1;
	}
	return 0;
}

extern "C" void writ_mem_report(char const *tag)
{
	Pd_session::Stats const s = _env->pd().stats();
	unsigned live = 0, guards = 0;
	{
		Mutex::Guard guard(_mutex());
		for (Reservation const &r : _res)
			if (r.used) { live++; guards += r.num_guards; }
	}
	log("writ_mem: [", tag, "] ram used=", s.ram.used.value,
	    " limit=", s.ram.limit.value, " reservations=", live,
	    " guards=", guards, " chunks populated (total)=", _chunks_populated,
	    " faults resolved=", _faults_resolved);
}


/**********************
 ** Component entry  **
 **********************/

extern char **environ;
extern "C" int main(int argc, char **argv, char **envp);

/*
 * Resolve libc's own mmap, munmap, and mprotect. The definitions in this
 * binary shadow them in the global scope, so look them up in libc.lib.so
 * by name and refuse to start if the lookup returns this unit's own
 * functions (forwarding would then recurse).
 */
static bool _resolve_libc()
{
	static Constructible<Shared_object> libc;
	try {
		libc.construct(*_env, *_heap, "libc.lib.so",
		               Shared_object::BIND_LAZY, Shared_object::KEEP);
		_libc_mmap     = libc->lookup<Mmap_fn>("mmap");
		_libc_munmap   = libc->lookup<Munmap_fn>("munmap");
		_libc_mprotect = libc->lookup<Mprotect_fn>("mprotect");
	} catch (...) { error("writ_mem: libc.lib.so lookup failed"); return false; }

	if ((void *)_libc_mmap == (void *)&mmap
	 || (void *)_libc_munmap == (void *)&munmap
	 || (void *)_libc_mprotect == (void *)&mprotect) {
		error("writ_mem: libc lookup returned the shim's own symbols");
		return false;
	}
	log("writ_mem: libc mmap=", (void *)_libc_mmap,
	    " munmap=", (void *)_libc_munmap, " mprotect=", (void *)_libc_mprotect,
	    " shim mmap=", (void *)&mmap);
	return true;
}

void Libc::Component::construct(Libc::Env &env)
{
	_env = &env;
	_heap.construct(env.ram(), env.rm());

	if (!_resolve_libc()) {
		env.parent().exit(1);
		return;
	}

	/* as repos/libports/src/lib/posix/construct.cc */
	Libc::with_libc([&] () {
		int argc = 0; char **argv = nullptr; char **envp = nullptr;
		populate_args_and_env(env, argc, argv, envp);
		environ = envp;
		exit(main(argc, argv, envp));
	});
}
