/*
 * writ_mem.cc - Genode host binding code for the Bend runtime's memory
 * calls and for the Genode.* console, time, and channel effects. This is
 * host binding code, not Writ policy: it makes no authority, label, budget,
 * or release decision, and nothing in it is consulted by Writ's Bend
 * verification. It is the single authored C++ unit GB-006 allows in a
 * Bend component (the shim): the memory host layer below, then the LOG
 * and Timer functions the effect twins in hosts/genode/effects/ call
 * ("Console and time"), then the Writ channel service behind Genode.take
 * and Genode.put ("Writ channel", with the session type in
 * writ_channel_session.h). See hosts/genode/INVENTORY.md for its exported
 * symbols, sessions, and bounds.
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
 * that leave the guard range unattached, so data outside the guard is kept
 * and the guard has no dataspace behind it. On base-linux the guard range
 * is not an unmapped hole: detaching a piece runs base-linux's
 * Region_map_mmap::detach, which munmaps the range and then re-reserves it
 * with _reserve_local, a PROT_NONE Linux mapping
 * (repos/base-linux/src/lib/base/region_map_mmap.cc:401-405). A touch
 * therefore still faults. If that re-reservation fails, base-linux logs
 * "_reserve_local unexpectedly failed" and the range is free address
 * space; the run scripts fail on that line. On base-hw a detached range
 * of a managed dataspace has no region in core's region map, so a touch
 * there is a region-map fault reflected to this unit's handler
 * (repos/base/src/core/include/region_map_component.h:427-440, the
 * NO_REGION case of _with_region_at_fault). The fault handler never
 * populates a guard range: a touch there is refused and the component
 * dies. mprotect
 * is never a no-op: a request this unit cannot carry out exactly fails
 * with -1.
 *
 * Fault delivery. Two front ends feed the same population path
 * (_resolve_fault: the same chunk table, guards, bounds, and counters);
 * exactly one is compiled, chosen at build time by the macro that
 * hosts/genode/shim/writ_shim.mk sets from the build directory's KERNEL
 * (WRIT_SHIM_FAULT_LINUX_SIGSEGV for KERNEL=linux,
 * WRIT_SHIM_FAULT_REGION_MAP for KERNEL=hw; any other kernel, or a build
 * without either macro, fails to compile). Build time rather than a config
 * attribute, because the base-linux front end issues raw Linux system
 * calls that are an unresolvable exception on base-hw (seen as
 * "unresolvable exception: pd='init -> writ_bend_hello', thread='ep'" on
 * the first base-hw run, verification/genode-bend-hello-base-hw.txt), so
 * a binary must not contain the wrong one, and a config attribute would
 * let the integrator select it.
 *
 * Case 1, base-linux (WRIT_SHIM_FAULT_LINUX_SIGSEGV). On base-linux the
 * Region_map fault
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
 * for the probe, and is recorded as a limit. Only kernel-generated
 * faults (si_code > 0) are handled; a SIGSEGV queued or sent with kill
 * gets the default action and is re-raised on the thread.
 *
 * Case 2, base-hw (WRIT_SHIM_FAULT_REGION_MAP). Core is the pager of every
 * thread. A touch of an unpopulated part of a reservation finds no region
 * in the reservation's region map; because a fault handler is registered
 * there (Region_map::fault_handler, repos/base/include/region_map/
 * region_map.h:79-87), core records the faulter, submits the handler's
 * signal (Region_map_component::fault, repos/base/src/core/
 * region_map_component.cc:476-486), and leaves the faulting thread halted
 * (the pager returns STOP, region_map_component.cc:72-113; base-hw's
 * Pager_entrypoint then calls fault_resolved(cap, false),
 * repos/base-hw/src/core/pager.cc:145-148). The signal is handled on the
 * dedicated entrypoint "writ_fault", started in construct before main. Its
 * handler takes the shim mutex, reads each live reservation's fault state
 * with Region_map_client::fault (repos/base/include/region_map/client.h:47;
 * the address is relative to the region map, the Fault/Type of
 * region_map.h:38-44) until it reports Type::NONE, and populates the chunk
 * at each faulting offset. The attach that populates it wakes every
 * faulter whose address lies in the attached range
 * (region_map_component.cc:272-278, Rm_faulter::continue_after_resolved_fault
 * -> Pager_object::wake_up), so the faulting thread resumes and repeats
 * the access, which core now resolves from the attached chunk. Signals to
 * one context coalesce, which is why the handler drains every queued
 * faulter of every reservation per signal rather than one.
 *   Coverage. The same handler is also registered, at construct, on the
 * PD's own address space and on its stack and linker areas
 * (Pd_session::address_space, stack_area, linker_area, repos/base/include/
 * pd_session/pd_session.h:235-248). Every fault this unit cannot resolve
 * anywhere in the component (a null pointer, a thread's stack guard, a
 * write to read-only code) is therefore reflected here and refused; core
 * does not log its own "illegal ..." line for it, because a region map
 * with a registered handler reflects instead of reporting ("omit
 * diagnostics", repos/base/src/core/include/region_map_component.h:
 * 430-440). Not covered: an exception that is not a page fault (an
 * invalid instruction, a raw Linux system call as in E2 of
 * verification/genode-bend-hello-base-hw.txt), which base-hw's pager
 * reports as "unresolvable exception" and halts (repos/base-hw/src/core/
 * pager.cc:131-140), a parent that registers its own handler on this
 * PD's address space (one handler per region map: the later one wins), and
 * a fault on the "writ_fault" thread itself (its own stack guard, or a bug
 * in the handler): it is reflected to the handler that thread would have
 * to run, so the component halts with no line, no exit, and no record.
 *   Why a dedicated entrypoint and not the channel's "writ_channel": that
 * one exists only with a <writ_channel> config node, while every
 * component with a reservation needs the fault handler; and a fault must
 * not wait behind session creation or a client signal (or behind libc's
 * main entrypoint, which libc keeps in wait_and_dispatch_one_io_signal
 * while Bend runs, the reason the channel has its own). The "writ_fault"
 * thread itself never touches reservation memory (only the chunk tables
 * in the shim Heap), so it cannot fault into its own handler.
 *   Retry table: not used on base-hw. On base-linux a fault on a populated
 * chunk is the benign result of a race and the access is retried by
 * returning from the signal handler; on base-hw core resolves a touch of
 * an attached range itself and never reflects it, and the attach that
 * populated or re-pieced a chunk has already woken every faulter in its
 * range. A reflected fault that still names a populated chunk outside
 * every guard (for example an execute or write access that the
 * attachment's rights refuse, region_map_component.h:465-473) therefore
 * cannot be resolved by this unit, and is refused like a guard touch.
 *
 * Failure behaviour. Every refusal kills the component: a fault on a
 * guard, outside every reservation (on base-hw also inside the stack or
 * linker area), a fault whose chunk cannot be charged or attached (the
 * attach error is named), or (base-linux) a fault on an already populated chunk that
 * keeps recurring at the same address (more than MAX_RETRIES times), or
 * (base-hw) any reflected fault on a populated chunk. A chunk is charged
 * through a plain Pd_session_client on Env::pd_session_cap(), not through
 * Env::pd(): the latter is an Expanding_pd_session_client
 * (repos/base/src/include/base/internal/expanding_pd_session_client.h)
 * that answers OUT_OF_RAM and OUT_OF_CAPS with a blocking parent
 * resource_request. The plain client returns the Alloc_error, and the
 * shim also checks the PD's available RAM and caps against a margin
 * first, so a fault never blocks on the parent. A chunk attach that core
 * refuses for RM-session quota (OUT_OF_RAM or OUT_OF_CAPS) is retried
 * after a bounded session upgrade paid from the PD's own quota under the
 * same margins (see _upgrade_rm_session); with RM routed to core through
 * init, as in these run scripts, the upgrade is answered without blocking
 * (child.cc, Child::upgrade, and component.cc, Env::upgrade, which blocks
 * only on PENDING). Under a parent that serves RM itself and answers
 * PENDING (a nested init or sandbox), Env::upgrade would block the
 * writ_fault thread, so there a fault could block on the parent. The
 * upgrade goes through Env::upgrade, which takes the Env's session mutex,
 * so a faulter halted while holding that mutex (inside a session request)
 * would leave the writ_fault thread blocked and the component halted with
 * no record, as with the LOG lock below. That cannot fire on the
 * single-lane runs here: Env's session, upgrade, and close code runs on
 * Genode stacks and the Genode heap and touches no reservation memory, so
 * the faulter would have to be the mutex holder faulting inside a
 * reservation, which no current path does; and a fault in the PD's own
 * areas (stack, linker, address space) inside a session request is
 * refused before any upgrade. Upgrades sent and declined are counted in
 * the exit report (rm upgrades) and, on base-hw, logged before a
 * refusal. On base-linux a refusal
 * prints one line with Genode::raw, restores the default SIGSEGV action,
 * and returns; the retried access then faults again and Linux terminates
 * the process. On base-hw a refusal logs the same line through the LOG
 * session (so init prefixes the component's label), leaves the faulting
 * thread halted in core (it is never woken, so it never resumes), and
 * ends the component through the parent with Parent::exit
 * (REFUSED_FAULT_EXIT, 139 = 128 + SIGSEGV, as a POSIX shell reports a
 * process killed by SIGSEGV; distinct from the runtime's own exit 1), so
 * init records the exit and destroys the protection domain. Until init
 * has done so, threads other than the faulting one may still run; with
 * --threads 1 nothing else evaluates Bend terms. The refusal is taken on
 * the "writ_fault" entrypoint, never on the faulting thread. The line is
 * logged before the exit so that it reaches the LOG before init destroys
 * the PD; if the halted faulter holds the LOG client's lock (it faulted
 * inside Genode::log, for example on a text buffer in writ_shim_log), the
 * refusal blocks on that lock and the component stays halted with no exit
 * and no record (fails closed: nothing resumes; not observed).
 *   On base-hw this is GB-003's halting substitute, and its record is
 * self-reported: the shim, inside the component, requests the exit; init
 * records an exit value, not a fault (139 is a convention, told apart from
 * a voluntary exit 139 only by the shim's preceding line, itself written by
 * the component); core records nothing.
 *
 * Concurrency. The shim's state is guarded by one mutex, which the fault
 * handler also takes (on base-hw the "writ_fault" entrypoint holds it
 * across its RPCs to core). On base-linux, a fault on a chunk that is
 * populated and outside every guard is the benign result of a race: another thread populated
 * the chunk first, or mprotect had its pieces detached while splitting it
 * around a guard. The handler then just returns and the access is
 * retried. The bound on such retries per address is what still kills a
 * truly unresolvable fault. That bound has two limits: the table has
 * 16 slots and its counts never decay while the reservation lives (munmap
 * clears the entries of its pages), so more than 16 concurrently stuck
 * addresses evict each other and can livelock, and a page that races
 * benignly more than 16 times over the reservation's life is refused.
 *
 * System calls do not populate (base-linux). A system call that reads or writes an
 * untouched chunk of a reservation (for example write(2) from, or read(2)
 * into, a buffer never touched by user code) gets EFAULT from Linux
 * instead of a SIGSEGV, so the chunk is not populated on that path.
 * Buffers handed to I/O must have been touched first. Not exercised.
 * On base-hw a component's libc does its I/O through RPC and shared
 * buffers in user space, so a buffer in a reservation is touched by the
 * component's own threads and faults normally; not exercised either.
 * Only single-lane use has been run
 * (verification/genode-reservation-probe-base-linux.txt and, for base-hw,
 * verification/genode-bend-hello-base-hw.txt); a fault taken
 * while the faulting thread itself holds a Genode lock the handler needs
 * (this mutex, an RPC or region-map lock) would deadlock.
 */

#if defined(WRIT_SHIM_FAULT_LINUX_SIGSEGV) == defined(WRIT_SHIM_FAULT_REGION_MAP)
#error "define exactly one of WRIT_SHIM_FAULT_LINUX_SIGSEGV (base-linux) and WRIT_SHIM_FAULT_REGION_MAP (base-hw); see hosts/genode/shim/writ_shim.mk"
#endif

/* Genode includes */
#include <base/attached_ram_dataspace.h>
#include <base/entrypoint.h>
#include <base/heap.h>
#include <base/log.h>
#include <base/mutex.h>
#include <base/semaphore.h>
#include <base/shared_object.h>
#include <base/signal.h>
#include <os/session_policy.h>
#include <pd_session/client.h>
#include <libc/component.h>
#include <libc/args.h>
#include <region_map/client.h>
#include <rm_session/connection.h>
#include <root/component.h>
#include <timer_session/connection.h>
#include <util/arg_string.h>
#include <util/construct_at.h>

/* the Writ channel session type (same directory) */
#include "writ_channel_session.h"

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
	MAX_RESERVATION = 1ul << 40,  /* 1 TiB: larger qualifying requests fail */
	CHUNK          = 2ul << 20,   /* populate granularity, 2 MiB       */
	PAGE           = 4096,
	MAX_RESERVATIONS = 32,
	MAX_GUARDS       = 4,
	MAX_RETRIES      = 16,          /* benign retries per faulting address */
	RETRY_SLOTS      = 16,
	RAM_MARGIN       = 64*1024,     /* kept free in the PD after a chunk  */
	CAP_MARGIN       = 8,           /* caps kept free in the PD           */
};

#if defined(WRIT_SHIM_FAULT_REGION_MAP)
enum : int { REFUSED_FAULT_EXIT = 139 };  /* 128 + SIGSEGV, see the header */
enum : size_t { FAULT_EP_STACK = 8*1024*sizeof(long) };
#endif


/*****************************************
 ** Linux ABI pieces (base-linux only)  **
 *****************************************/

#if defined(WRIT_SHIM_FAULT_LINUX_SIGSEGV)

/*
 * Genode's libc headers are FreeBSD's, so the Linux values are spelled out
 * here (x86_64 Linux UAPI) rather than taken from <signal.h>.
 */
enum : unsigned long {
	LX_SYS_RT_SIGACTION = 13,
	LX_SYS_GETPID       = 39,
	LX_SYS_GETTID       = 186,
	LX_SYS_TGKILL       = 234,
	LX_SIGSEGV          = 11,
	LX_SA_SIGINFO       = 0x00000004,
	LX_SA_RESTORER      = 0x04000000,
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
asm(".pushsection .text\n"
    ".p2align 4\n"
    ".type writ_mem_restore_rt, @function\n"
    "writ_mem_restore_rt:\n"
    "\tmovq $15, %rax\n"
    "\tsyscall\n"
    ".size writ_mem_restore_rt, .-writ_mem_restore_rt\n"
    ".popsection\n");

static long lx_syscall3(unsigned long nr, unsigned long a1,
                        unsigned long a2, unsigned long a3)
{
	long ret;
	asm volatile ("syscall"
	              : "=a" (ret)
	              : "0" (nr), "D" (a1), "S" (a2), "d" (a3)
	              : "rcx", "r11", "memory");
	return ret;
}

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

#endif /* WRIT_SHIM_FAULT_LINUX_SIGSEGV */


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

/*
 * Shim objects that live until the process ends. Constructible<T> would be
 * destroyed by static destruction inside exit(), while the runtime's
 * reservations are still mapped (it never unmaps its term heap): the Heap
 * destructor then reverts the live chunk tables ("dangling allocation"
 * warning, seen with the Bend hello), a later fault would read freed
 * tables, and the RM session would close under mapped memory. Kept<T>
 * has no destructor; the component's exit releases everything at once.
 */
template <typename T>
struct Kept
{
	alignas(T) char _bytes[sizeof(T)];
	bool            _constructed = false;

	template <typename... ARGS>
	void construct(ARGS &&... args)
	{
		construct_at<T>(_bytes, args...);
		_constructed = true;
	}

	bool constructed() const { return _constructed; }
	T *operator -> () { return reinterpret_cast<T *>(_bytes); }
	T &operator *  () { return *reinterpret_cast<T *>(_bytes); }
};

using Mmap_fn     = void *(*)(void *, ::size_t, int, int, int, ::off_t);
using Munmap_fn   = int    (*)(void *, ::size_t);
using Mprotect_fn = int    (*)(void *, ::size_t, int);

static Env                         *_env;
static Kept<Heap>                   _heap;
static Kept<Rm_connection>          _rm_connection;
static Mmap_fn                      _libc_mmap;
static Munmap_fn                    _libc_munmap;
static Mprotect_fn                  _libc_mprotect;
static bool                         _fault_handler_installed;
static Reservation                  _res[MAX_RESERVATIONS];

/* counters for writ_mem_report (diagnostics only) */
static unsigned long _chunks_populated, _faults_resolved;
static unsigned long _rm_upgrades_sent, _rm_upgrades_declined;
static unsigned long _reserved_at_hint, _reserved_elsewhere, _released;

static Mutex &_mutex() { static Mutex m { }; return m; }

/*
 * Benign-retry accounting for faults on populated chunks, keyed by page
 * address. Entries are reused round-robin; an address that exceeds
 * MAX_RETRIES is treated as unresolvable.
 *
 * Limits (see the header): the table has RETRY_SLOTS entries and counts
 * never decay while their reservation lives (_release clears them). More than RETRY_SLOTS addresses faulting on populated
 * chunks at once evict each other's entries before any reaches
 * MAX_RETRIES, so a truly unresolvable fault among them is retried
 * without bound (livelock instead of termination). And an address whose
 * entry survives accumulates benign retries over the reservation's life, so a
 * page that races legitimately more than MAX_RETRIES times in total is
 * refused and the component dies.
 */
static unsigned long _benign_retries;   /* stays 0 on base-hw (header) */

#if defined(WRIT_SHIM_FAULT_LINUX_SIGSEGV)
struct Retry { addr_t page; unsigned count; };
static Retry    _retries[RETRY_SLOTS];
static unsigned _retry_next;

static bool _retry_allowed(addr_t a)
{
	addr_t const page = a & ~addr_t(PAGE - 1);
	for (Retry &e : _retries)
		if (e.count && e.page == page)
			return ++e.count <= MAX_RETRIES;
	_retries[_retry_next] = { page, 1 };
	_retry_next = (_retry_next + 1) % RETRY_SLOTS;
	return true;
}
#endif /* WRIT_SHIM_FAULT_LINUX_SIGSEGV */

/*
 * Do [a, a+n) and [b, b+s) overlap? Written without a + n, so a length
 * near SIZE_MAX cannot wrap. b + s never wraps (a reservation is mapped).
 */
static bool _overlaps(addr_t a, size_t n, addr_t b, size_t s)
{
	return a >= b ? a - b < s : b - a < n;
}

#if defined(WRIT_SHIM_FAULT_LINUX_SIGSEGV)
/* the reservation holding a faulting address (base-hw's handler is given
 * the region map, so it needs no lookup) */
static Reservation *_lookup(addr_t a)
{
	for (Reservation &r : _res)
		if (r.contains(a)) return &r;
	return nullptr;
}
#endif


/*****************************
 ** Population and pieces   **
 *****************************/

static Region_map::Attr _piece_attr(addr_t start, addr_t end, addr_t c)
{
	return { .size = end - start, .offset = start - c, .use_at = true,
	         .at = start, .executable = false, .writeable = true };
}

/*
 * Non-expanding PD client for chunk allocation: Alloc_error comes back
 * instead of becoming a blocking resource_request (see header).
 */
static Kept<Pd_session_client> _pd;

/*
 * RM-session upgrade per attach retry, the amounts Rm_connection::create
 * uses (repos/base/include/rm_session/connection.h). Core charges the
 * metadata of every attached piece to the RM session's own quota (64 KiB
 * and 2 caps at session creation), and attach, unlike create, does not
 * upgrade on demand. The upgrade is a session upgrade: init moves the
 * amount from this component's own PD quota to core (child.cc,
 * Child::upgrade). It is not a resource_request, and it is attempted only
 * while the PD keeps RAM_MARGIN and CAP_MARGIN after the transfer, so a
 * component that cannot pay still gets the named attach error.
 */
static constexpr size_t RM_UPGRADE_RAM      = 8*1024;
static constexpr size_t RM_UPGRADE_CAPS     = 2;
static constexpr size_t RM_UPGRADE_ATTEMPTS = 4;   /* per piece; bounds the retry loop */

/* returns true when the upgrade was sent (affordable), false otherwise */
static bool _upgrade_rm_session(Region_map::Attach_error a)
{
	using E = Region_map::Attach_error;
	Pd_session::Stats const st = _pd->stats();
	if (a == E::OUT_OF_RAM) {
		if (st.ram.avail().value < RM_UPGRADE_RAM + size_t(RAM_MARGIN)) {
			_rm_upgrades_declined++; return false; }
		_rm_connection->upgrade_ram(RM_UPGRADE_RAM);
		_rm_upgrades_sent++;
		return true;
	}
	if (a == E::OUT_OF_CAPS) {
		if (st.caps.avail().value < RM_UPGRADE_CAPS + size_t(CAP_MARGIN)) {
			_rm_upgrades_declined++; return false; }
		_rm_connection->upgrade_caps(RM_UPGRADE_CAPS);
		_rm_upgrades_sent++;
		return true;
	}
	return false;   /* not a quota error: no upgrade, not counted */
}

/*
 * Attach chunk idx's dataspace as the pieces outside the guards. Returns
 * nullptr on success, otherwise the first attach error, named so that a
 * refusal tells RM-session quota (OUT_OF_RAM, OUT_OF_CAPS: the pieces are
 * core metadata charged to the Rm_connection) from a conflict. On a quota
 * error the RM session is upgraded from the PD's own quota and the attach
 * retried, at most RM_UPGRADE_ATTEMPTS times per piece; the error stands
 * when the PD cannot pay or the bound is reached.
 */
static char const *_attach_pieces(Reservation &r, size_t idx)
{
	using E = Region_map::Attach_error;
	Region_map_client rm(r.rm_cap);
	addr_t const c = idx*CHUNK, e = r.chunk_end(idx);
	char const *err = nullptr;
	r.for_each_piece(c, e, [&] (addr_t s, addr_t t) {
		if (err) return;
		for (size_t attempt = 0; ; attempt++) {
			bool attached = false;
			E failure = E::INVALID_DATASPACE;
			rm.attach(r.chunks[idx].ds, _piece_attr(s, t, c)).with_result(
				[&] (Region_map::Range) { attached = true; },
				[&] (E a) { failure = a; });
			if (attached) return;
			if (attempt < RM_UPGRADE_ATTEMPTS && _upgrade_rm_session(failure))
				continue;
			err = failure == E::OUT_OF_RAM      ? "chunk could not be attached: attach OUT_OF_RAM"
			    : failure == E::OUT_OF_CAPS     ? "chunk could not be attached: attach OUT_OF_CAPS"
			    : failure == E::REGION_CONFLICT ? "chunk could not be attached: attach REGION_CONFLICT"
			    :                                 "chunk could not be attached: attach INVALID_DATASPACE";
			return;
		}
	});
	return err;
}

static void _detach_pieces(Reservation &r, size_t idx)
{
	Region_map_client rm(r.rm_cap);
	r.for_each_piece(idx*CHUNK, r.chunk_end(idx), [&] (addr_t s, addr_t) {
		rm.detach(s); });
}

/*
 * Populate the chunk containing offset off. Returns nullptr on success,
 * otherwise the reason for refusal; never asks the parent for quota.
 */
static char const *_populate(Reservation &r, addr_t off)
{
	size_t const idx = off / CHUNK;
	size_t const len = _page_round(r.chunk_end(idx) - idx*CHUNK);

	Pd_session::Stats const st = _pd->stats();
	if (st.ram.avail().value < len + RAM_MARGIN)
		return "chunk could not be charged: RAM quota";
	if (st.caps.avail().value < CAP_MARGIN)
		return "chunk could not be charged: cap quota";

	Ram_dataspace_capability ds { };
	char const *err = nullptr;
	_pd->alloc_ram(len, CACHED).with_result(
		[&] (Ram_dataspace_capability cap) { ds = cap; },
		[&] (Alloc_error e) {
			err = e == Alloc_error::OUT_OF_CAPS ? "chunk could not be charged: alloc_ram OUT_OF_CAPS"
			    : e == Alloc_error::OUT_OF_RAM  ? "chunk could not be charged: alloc_ram OUT_OF_RAM"
			    :                                 "chunk could not be charged: alloc_ram DENIED"; });
	if (!ds.valid()) return err ? err : "chunk could not be charged: invalid dataspace";

	r.chunks[idx] = { ds, true };
	if (char const *why = _attach_pieces(r, idx)) {
		_detach_pieces(r, idx);
		_pd->free_ram(ds);
		r.chunks[idx] = { { }, false };
		return why;
	}
	_chunks_populated++;
	return nullptr;
}


/**********************
 ** Fault front end  **
 **********************/

/*
 * The population decision both front ends share (caller holds _mutex).
 * off is the faulting offset inside r. Returns the refusal reason, or
 * nullptr when the fault is resolved: either the chunk at off was
 * populated now (counted in _faults_resolved) or it was already populated
 * (populated set, nothing done; each front end decides what that means,
 * see "Retry table" in the header).
 */
static char const *_resolve_fault(Reservation &r, addr_t off, bool &populated)
{
	if (off >= r.size)  return "outside every reservation";
	if (r.in_guard(off)) return "guard page";
	if (r.chunks[off/CHUNK].populated) { populated = true; return nullptr; }
	if (char const *why = _populate(r, off)) return why;
	_faults_resolved++;
	return nullptr;
}

#if defined(WRIT_SHIM_FAULT_LINUX_SIGSEGV)

/* Case 1 of "Fault delivery": the raw Linux SIGSEGV handler. */

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
	/*
	 * si_code <= 0: sent by kill/tgkill/sigqueue, not a memory fault.
	 * Returning would not re-raise it, so take the default action now.
	 */
	if (info->code <= 0) {
		raw("writ_mem: SIGSEGV not from a fault (si_code ", info->code,
		    "), component terminates");
		Lx_sigaction dfl { (void (*)(int, Lx_siginfo *, void *))LX_SIG_DFL,
		                   0, nullptr, 0 };
		lx_rt_sigaction(LX_SIGSEGV, &dfl);
		lx_syscall3(LX_SYS_TGKILL, lx_syscall3(LX_SYS_GETPID, 0, 0, 0),
		            lx_syscall3(LX_SYS_GETTID, 0, 0, 0), LX_SIGSEGV);
		return;
	}

	addr_t const a = addr_t(info->addr);

	Mutex::Guard guard(_mutex());

	Reservation *r = _lookup(a);
	if (!r) { _refuse("outside every reservation", a); return; }

	bool populated = false;
	if (char const *why = _resolve_fault(*r, a - r->base, populated)) {
		_refuse(why, a); return; }

	if (populated) {
		/* benign race (see header): retry, but not without bound */
		if (!_retry_allowed(a)) {
			_refuse("populated chunk, fault keeps recurring", a); return; }
		_benign_retries++;
		return;
	}
	/* returning retries the access, which now hits the attached chunk */
}

static void _install_fault_handler()
{
	if (_fault_handler_installed) return;
	/*
	 * No SA_ONSTACK: base-linux sets each thread's alternate signal stack
	 * to that thread's whole primary stack
	 * (repos/base-linux/src/lib/base/thread_linux.cc:53-59), while libc
	 * runs application code on a separate stack. A handler taken onto the
	 * alternate stack starts at its top and can overwrite the suspended
	 * entrypoint's frames. With SA_ONSTACK the probe faulted at 0x5100
	 * inside libc.lib.so after five resolved faults, consistent with that
	 * (verification/genode-reservation-probe-base-linux.txt, section 8).
	 * The handler therefore runs on the faulting stack. A machine
	 * stack overflow then cannot run it, and Linux kills the process
	 * without the shim's line.
	 */
	Lx_sigaction act { _segv_handler,
	                   LX_SA_SIGINFO | LX_SA_RESTORER | LX_SA_RESTART,
	                   writ_mem_restore_rt, 0 };
	if (lx_rt_sigaction(LX_SIGSEGV, &act) != 0) {
		error("writ_mem: rt_sigaction(SIGSEGV) failed");
		return;
	}
	_fault_handler_installed = true;
}

/* The SIGSEGV handler covers every reservation; nothing to register. */
static void _watch_faults(Capability<Region_map>) { }

#elif defined(WRIT_SHIM_FAULT_REGION_MAP)

/*
 * Case 2 of "Fault delivery": the Region_map fault signal, handled on the
 * dedicated "writ_fault" entrypoint. Started once from construct, before
 * main, so it exists before the first qualifying mmap.
 */

/* Logs the refusal and ends the component through the parent; the
 * faulting thread stays halted in core and is never resumed. */
[[noreturn]] static void _refuse(char const *why, addr_t a)
{
	log("writ_mem: [refusal] rm upgrades sent=", _rm_upgrades_sent,
	    " declined=", _rm_upgrades_declined);
	log("writ_mem: unresolved fault at ", Hex(a), " (", why,
	    "), component terminates");
	_env->parent().exit(REFUSED_FAULT_EXIT);
	sleep_forever();
}

/* the PD's own region maps the handler also watches (_install_fault_handler) */
struct Pd_area { Capability<Region_map> cap { }; char const *why = nullptr; };
static Pd_area _pd_areas[3];

struct Rm_fault_handler
{
	Signal_handler<Rm_fault_handler> sigh;

	/*
	 * Drains every queued faulter of every live reservation: signals to
	 * one context coalesce, and Region_map::fault reports only the first
	 * faulter of a region map. Each resolved fault's attach wakes its
	 * faulter and removes it from core's queue, so the next fault() call
	 * reports the next one or Type::NONE. A faulter still queued at a
	 * populated chunk is refused (header, "Retry table"), which also ends
	 * the loop.
	 */
	void _handle()
	{
		/*
		 * A fault of the component's own address space, stack area, or
		 * linker area: an access with no region behind it outside every
		 * reservation (a null pointer, a thread's stack guard), or one the
		 * region's rights refuse. Nothing here can resolve it. The address
		 * is absolute for the address space and relative to the area for
		 * the other two (the refusal line names which). Checked before the
		 * shim mutex is taken: _pd_areas is written once in construct and
		 * only read afterwards, and the refusal needs no shim state, so a
		 * thread that faults here while holding the mutex (for example on
		 * its stack guard inside mmap or mprotect) still gets the recorded
		 * exit instead of a handler blocked on that mutex.
		 */
		for (Pd_area const &area : _pd_areas) {
			Region_map::Fault const f = Region_map_client(area.cap).fault();
			if (f.type != Region_map::Fault::Type::NONE)
				_refuse(area.why, f.addr);
		}

		Mutex::Guard guard(_mutex());

		for (Reservation &r : _res) {
			if (!r.used) continue;
			Region_map_client rm(r.rm_cap);
			for (;;) {
				Region_map::Fault const f = rm.fault();
				if (f.type == Region_map::Fault::Type::NONE) break;

				addr_t const off = f.addr;   /* relative to the region map */
				bool populated = false;
				if (char const *why = _resolve_fault(r, off, populated))
					_refuse(why, r.base + off);
				if (populated)
					_refuse("populated chunk, fault reflected", r.base + off);
			}
		}
	}

	Rm_fault_handler(Entrypoint &ep)
	: sigh(ep, *this, &Rm_fault_handler::_handle) { }
};

static Kept<Entrypoint>       _fault_ep;
static Kept<Rm_fault_handler> _rm_fault_handler;

/* Called from construct, outside libc's context, as the channel's is. */
static void _install_fault_handler()
{
	if (_fault_handler_installed) return;
	_fault_ep.construct(*_env, size_t(FAULT_EP_STACK), "writ_fault",
	                    Affinity::Location());
	_rm_fault_handler.construct(*_fault_ep);

	/*
	 * The same handler on the PD's own region maps: its address space
	 * (Pd_session::address_space, repos/base/include/pd_session/
	 * pd_session.h:235-238, as repos/os/src/test/fault_detection/
	 * main.cc:119-121 does for a child) and the stack and linker areas
	 * nested in it (pd_session.h:243-248; core's Region_map_components,
	 * repos/base/src/core/include/pd_session_component.h:77-78). A fault
	 * outside every reservation is then reflected here and refused, instead
	 * of core's "illegal ..." line and a halted thread with no exit
	 * (repos/base/src/core/region_map_component.cc:102-104). Registered
	 * before main runs. Only one handler per region map exists, so a
	 * parent that registers its own on this PD's address space (as the
	 * fault_detection test does) replaces this one, or is replaced by it.
	 */
	Pd_session &pd = _env->pd();
	_pd_areas[0] = { pd.address_space(), "outside every reservation" };
	_pd_areas[1] = { pd.stack_area(),    "stack area, offset in the area" };
	_pd_areas[2] = { pd.linker_area(),   "linker area, offset in the area" };
	for (Pd_area const &area : _pd_areas)
		Region_map_client(area.cap).fault_handler(_rm_fault_handler->sigh);
	_fault_handler_installed = true;
}

/* Registers the handler on a new reservation's region map before its
 * first touch can happen (the reservation is not yet returned). */
static void _watch_faults(Capability<Region_map> rm_cap)
{
	Region_map_client(rm_cap).fault_handler(_rm_fault_handler->sigh);
}

#endif /* WRIT_SHIM_FAULT_REGION_MAP */


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
	/*
	 * Bound len before any rounding: a len above SIZE_MAX - 4095 would
	 * page-round to 0 and create an empty region map. 1 TiB is far above
	 * what any quota can populate (and base-linux's region map holds at
	 * most 4096 pieces, 8 GiB of 2 MiB chunks), so a larger request fails
	 * with ENOMEM exactly as an exhausted address space would. The Bend
	 * runtime's corpus_grow treats that as "cannot grow". The bound
	 * therefore also caps corpus_grow, which doubles the term heap in
	 * place by mapping a span as large as the current one at its end
	 * (requests up to 4 TiB): growth stops after the 1 TiB request, at a
	 * 2 TiB corpus, and the runtime then posts ERR_HEAP ("out of memory").
	 */
	if (len > MAX_RESERVATION) { errno = ENOMEM; return MAP_FAILED; }

	Reservation *r = nullptr;
	for (Reservation &cand : _res)
		if (!cand.used) { r = &cand; break; }
	if (!r) { errno = ENOMEM; return MAP_FAILED; }

#if defined(WRIT_SHIM_FAULT_LINUX_SIGSEGV)
	/* base-linux installs the SIGSEGV handler at the first reservation */
	if (!_fault_handler_installed) _install_fault_handler();
#endif
	/*
	 * On base-hw construct has started the "writ_fault" entrypoint before
	 * main; it is never constructed here, from libc's context. Without it
	 * no reservation is made.
	 */
	if (!_fault_handler_installed) { errno = ENOMEM; return MAP_FAILED; }

	size_t const size = _page_round(len);
	size_t const num_chunks = (size + CHUNK - 1) / CHUNK;
	/* Unreachable after the bounds above; kept as defence in depth. */
	if (size == 0 || num_chunks == 0) { errno = ENOMEM; return MAP_FAILED; }

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
	_watch_faults(rm_cap);

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
	if (base) _reserved_at_hint++;
	if (!base) {
		base = attach_at(false, 0);
		if (base) _reserved_elsewhere++;
	}
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
			_pd->free_ram(r.chunks[i].ds);
		}
	/* Local_rm_session::destroy also detaches the region map locally */
	_env->rm().detach(r.base);
	_rm_connection->destroy(r.rm_cap);
	_heap->free(r.chunks, r.num_chunks*sizeof(Chunk));

#if defined(WRIT_SHIM_FAULT_LINUX_SIGSEGV)
	/*
	 * Forget benign-retry counts for pages of this reservation, so a later
	 * reservation at the same addresses does not inherit them.
	 */
	for (Retry &e : _retries)
		if (e.count && _overlaps(e.page, PAGE, r.base, r.size))
			e = { 0, 0 };
#endif

	r = { };
	_released++;
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
	if (!_env || !_libc_mmap) { errno = ENOSYS; return MAP_FAILED; }  /* before construct */

	if (!_qualifies(len, prot, flags, fd, offset))
		return _libc_mmap(addr, len, prot, flags, fd, offset);

	Mutex::Guard guard(_mutex());
	return _reserve(addr, len);
}

extern "C" int munmap(void *addr, ::size_t len)
{
	if (!_env || !_libc_munmap) { errno = ENOSYS; return -1; }  /* before construct */

	addr_t const a = addr_t(addr);
	{
		Mutex::Guard guard(_mutex());
		for (Reservation &r : _res) {
			if (!r.used || !_overlaps(a, len, r.base, r.size)) continue;
			/* only the whole reservation can be unmapped */
			if (a != r.base || len == 0 || len > r.size
			 || _page_round(len) != r.size) {
				errno = EINVAL; return -1; }
			_release(r);
			return 0;
		}
	}
	return _libc_munmap(addr, len);
}

extern "C" int mprotect(void *addr, ::size_t len, int prot)
{
	if (!_env || !_libc_mprotect) { errno = ENOSYS; return -1; }  /* before construct */

	addr_t const a = addr_t(addr);

	Mutex::Guard guard(_mutex());

	Reservation *r = nullptr;
	for (Reservation &cand : _res)
		if (cand.used && _overlaps(a, len, cand.base, cand.size)) {
			r = &cand; break; }
	if (!r) return _libc_mprotect(addr, len, prot);

	/*
	 * Validate before any sum: len is bounded by the reservation size,
	 * so the page-rounded n cannot wrap, and containment is tested as
	 * off <= size - n.
	 */
	if ((a & (PAGE - 1)) || len == 0 || len > r->size || a < r->base) {
		errno = EINVAL; return -1; }
	size_t const n   = _page_round(len);
	addr_t const off = a - r->base;
	if (n == 0 || n > r->size || off > r->size - n) {
		errno = EINVAL; return -1; }

	auto overlaps_guard = [&] {
		for (unsigned i = 0; i < r->num_guards; i++)
			if (_overlaps(off, n, r->guards[i].off, r->guards[i].len))
				return true;
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
		if (r->chunks[i].populated && _attach_pieces(*r, i)) ok = false;

	if (!ok) {
		/*
		 * The guard range itself is never a piece (it stays a PROT_NONE
		 * reservation, see the header), so the guard holds; data outside
		 * it may be unreachable.
		 */
		errno = ENOMEM; return -1;
	}
	return 0;
}


/***********************************
 ** Console and time (Genode.*)   **
 ***********************************/

/*
 * Host functions behind the Bend effects Genode.log, Genode.now, and
 * Genode.sleep (hosts/genode/effects/). Each moves bytes or reads a clock;
 * none decides anything, and the Bend program alone decides what is
 * logged and when it waits.
 *
 * LOG. writ_shim_log hands the bytes to Genode::log (repos/base/include/
 * base/log.h), which writes them to the component's own LOG session, the
 * one init routes to the parent's LOG service. The text is printed as a
 * Cstring of at most len bytes (repos/base/include/util/string.h:757), so
 * it ends at the first NUL; a line longer than the LOG session's
 * MAX_STRING_LEN (232, repos/base/include/log_session/log_session.h:48)
 * reaches the LOG in several pieces. Nothing is added to the text: the
 * LOG service prefixes the session label ("[init -> <name>] ").
 *
 * Timer. One Timer::Connection (repos/base/include/timer_session/
 * connection.h, label "writ_shim"), opened at the first now or sleep and
 * kept for the component's life (Kept<T>, no destructor, as the memory
 * state). It is used in the timer-session mode only: elapsed_ms is a
 * plain RPC, and msleep blocks the calling thread on the connection's
 * own Signal_receiver (connection.h:390-433), so it needs no entrypoint
 * dispatch and may run on a runtime helper thread. Invariant: the shim
 * never calls curr_time() on _timer and never hands it to a Timeout or
 * One_shot/Periodic timeout, so the connection never switches to the
 * timeout-framework mode, in which msleep would log an error and return
 * at once (connection.h:426-430). The session clock is monotone
 * milliseconds since this session was opened (the timer component
 * subtracts the session's creation time, repos/base/include/timer/
 * component.h:98-100 and :202), so the first reading is near 0.
 *
 * writ_shim_sleep_ms returns only when that clock has advanced by at
 * least ms, re-sleeping the remainder if msleep woke early (each early
 * wake is counted in _timer_short_wakes and shown in writ_mem_report), so
 * a Bend program's delta of two readings around a sleep is at least the
 * sleep.
 *
 * Failure behaviour (host failure handling, not policy: no Writ decision
 * depends on it; a component whose clock cannot be trusted stops). Every
 * case logs one error line and ends the component with exit value 1
 * through the parent (Parent::exit), so init records the exit instead of
 * the component hanging:
 *   - Timer route missing or denied. Env::session answers a DENIED session
 *     with an error line and sleep_forever (repos/base/src/lib/base/
 *     component.cc:200-202), so the shim first asks with Env::try_session
 *     under a probe id (component.cc:117-149) and stops on DENIED; the
 *     probe session is closed and Timer::Connection then opens the kept
 *     one. Any exception from the Connection's construction stops too.
 *   - Frozen or reversed clock: a reading after msleep that has not
 *     advanced past the reading before it, or a first reading before the
 *     sleep's start.
 *   - More than MAX_SLEEP_ROUNDS msleep calls for one sleep (this also
 *     bounds a connection that returned from msleep at once, as the
 *     timeout-framework mode would, while the clock creeps forward).
 */

enum : unsigned {
	MAX_SLEEP_ROUNDS = 16,            /* msleep calls per writ_shim_sleep_ms */
	TIMER_PROBE_RAM  = 10*1024,       /* as Timer::Connection requests */
	TIMER_PROBE_CAPS = Timer::Session::CAP_QUOTA,
};

static Kept<Timer::Connection> _timer;
static unsigned long           _timer_short_wakes;

static Mutex &_timer_mutex() { static Mutex m { }; return m; }

/* Ends the component with exit value 1 after one line; does not return. */
[[noreturn]] static void _timer_fail(char const *what)
{
	error("writ_shim: ", what, ", component exits 1");
	_env->parent().exit(1);
	sleep_forever();
}

/*
 * Whether the parent grants a Timer session labelled "writ_shim". Only
 * DENIED counts as no route; a quota answer means the route exists and is
 * left to the Connection's own quota upgrades.
 */
static bool _timer_route_granted()
{
	Parent::Client client { };
	Id_space<Parent::Client>::Element const probe(client, _env->id_space());
	String<Parent::Session_args::MAX_SIZE> const args(
		"label=\"writ_shim\", ram_quota=", unsigned(TIMER_PROBE_RAM),
		", cap_quota=", unsigned(TIMER_PROBE_CAPS));

	return _env->try_session(Timer::Session::service_name(), probe.id(),
	                         Parent::Session_args(args.string()), Affinity())
		.convert<bool>(
			[&] (Session_capability) { _env->close(probe.id()); return true; },
			[&] (Session_error e)    { return e != Session_error::DENIED; });
}

/* Opens the Timer session on first use; null before construct. */
static Timer::Connection *_timer_session()
{
	if (!_env) return nullptr;
	Mutex::Guard guard(_timer_mutex());
	if (!_timer.constructed()) {
		if (!_timer_route_granted())
			_timer_fail("Timer session denied (no route for label writ_shim)");
		try { _timer.construct(*_env, Timer::Connection::Label("writ_shim")); }
		catch (...) { _timer_fail("Timer session could not be opened"); }
	}
	return &*_timer;
}

extern "C" void writ_shim_log(char const *text, size_t len)
{
	if (!text) return;
	log(Cstring(text, len));
}

/* 0 before construct, which no effect can run before. */
extern "C" uint64_t writ_shim_now_ms(void)
{
	Timer::Connection *t = _timer_session();
	return t ? t->elapsed_ms() : 0;
}

extern "C" void writ_shim_sleep_ms(uint32_t ms)
{
	Timer::Connection *t = _timer_session();
	if (!t || ms == 0) return;
	uint64_t const start    = t->elapsed_ms();
	uint64_t const deadline = start + ms;
	uint64_t       last     = start;
	for (unsigned round = 0;; round++) {
		uint64_t const now = t->elapsed_ms();
		if (now >= deadline) return;
		if (now < start)
			_timer_fail("Timer clock went backwards during a sleep");
		if (round > 0) {
			if (now <= last)
				_timer_fail("Timer clock did not advance across msleep");
			_timer_short_wakes++;  /* msleep returned before the deadline */
		}
		if (round == MAX_SLEEP_ROUNDS)
			_timer_fail("sleep exceeded MAX_SLEEP_ROUNDS msleep calls");
		last = now;
		t->msleep(deadline - now);
	}
}

/*************************************
 ** Writ channel (Genode.take/put)  **
 *************************************/

/*
 * Host transport behind the Bend effects Genode.take and Genode.put
 * (hosts/genode/effects/, record layout in Channel.md). The shim moves
 * records and signals and makes no decision: every request record is
 * handed to Bend, which alone accepts or denies it, and Bend's reply record
 * is copied back unread. The session type is Writ_channel::Session
 * (writ_channel_session.h), whose four RPC functions only hand over
 * capabilities (GB-011).
 *
 * Service. Served only when the component's config has a <writ_channel>
 * node; otherwise nothing below runs and the component announces nothing.
 * Each session is one channel object (GB-010): a 4 KiB request bucket and a
 * 4 KiB result bucket (Attached_ram_dataspace, repos/base/include/base/
 * attached_ram_dataspace.h, zeroed RAM charged to this component and
 * covered by the client's session quota) and a request Signal_handler. The
 * root and every channel are served by a dedicated entrypoint
 * "writ_channel" (repos/base/include/base/entrypoint.h:135), not by the
 * component's main entrypoint: while the Bend main is suspended in libc,
 * libc's kernel keeps the main entrypoint in wait_and_dispatch_one_io_signal
 * (repos/libports/src/lib/libc/internal/kernel.h:460-533), which defers RPCs
 * and non-I/O signals (repos/base/src/lib/base/entrypoint.cc:145-199), so a
 * session request or client signal there would wait for Bend. Base's own
 * Root_proxy uses a separate entrypoint for the same reason
 * (repos/base/src/lib/base/root_proxy.cc:120).
 *
 * Identity (GB-007). The parent prefixes every session label with the
 * requesting child's name (repos/base/src/lib/base/child.cc:152-155), so a
 * client cannot choose the prefix. The channel's subject word is the
 * `subject` attribute of the <policy> under <writ_channel> that matches the
 * label best (os/session_policy.h with_matching_policy, label/label_prefix/
 * label_suffix scoring). Only a <policy> node with a `label` or
 * `label_prefix` attribute binds identity: a <default-policy>, a policy
 * matched only through `label_suffix` (the suffix is chosen by the client),
 * no match, or subject 0 refuses the session (DENIED). The policies are
 * read from libc's own attached config (Libc::Env::with_config,
 * repos/libports/include/libc/component.h:36-43), a read-only view of a ROM
 * that is never updated here, so the channel entrypoint may read it at
 * session creation without further locking. The integrator
 * writes that configuration; the shim only looks the word up. Bend maps
 * the word to an identity; the record body never supplies it.
 *
 * Queue. A client signal runs _channel_signalled on the "writ_channel"
 * entrypoint, which appends (channel id, subject) to a ring of
 * CHANNEL_QUEUE_DEPTH entries and ups _channel_ready. A channel has at most
 * one queued entry (a repeated signal is coalesced and counted), so one
 * client cannot fill the ring; a full ring drops and counts the signal.
 * writ_shim_take runs on a runtime io_work helper thread: it blocks in
 * _channel_ready.down() (base/semaphore.h, a Blockade, so the thread sleeps
 * and the loop spins nowhere), pops the entry, and copies the record out
 * of the channel's request bucket under _channel_mutex. The runtime's own
 * completion pipe (io_wake_fd over the component's vfs_pipe /pipe, the
 * libc wakeup the event loop already uses for io_work) then resumes the
 * loop, which packs the Request.
 *
 * Copy discipline. A bucket starts with a 16-byte header (length, sequence,
 * two reserved words); the record follows at offset 16 (Channel.md). The
 * shim copies exactly CHANNEL_RECORD_SIZE bytes, once, at take time; Bend
 * only ever sees that copy, so a client rewriting its bucket after the
 * signal cannot change what was decided. Words are copied in host
 * order; the targets are x86_64, little-endian.
 *
 * Transport refusal (GB-006, Task 3). A header whose length is not exactly
 * CHANNEL_RECORD_SIZE is never copied and never reaches Bend: take counts
 * it and answers it at once with a fixed refusal record in the result
 * bucket (version 1, kind CHANNEL_KIND_REFUSAL = 3, decision
 * CHANNEL_DECISION_REFUSED = 3, which is neither Committed nor Denied,
 * reason CHANNEL_REASON_BAD_LENGTH = 256, every other word 0, the request's
 * sequence in the header) and signals the client. This is the one result
 * the shim writes on its own. It carries no Writ decision: it is the same
 * record for every channel and subject, depends only on the length word,
 * and its kind, decision, and reason words are outside the monitor's
 * (kind 2, decisions 1 and 2, reasons 0 to 8), so a client cannot mistake
 * it for a decision by Bend.
 *
 * Close event (Task 3). When a session closes, the channel is removed from
 * the table and its slot is held as "closing" until Bend has taken a close
 * event for it: a ring entry marked close (an entry already queued for
 * the channel is turned into it; the queued request is dropped and counted
 * as stale), which take hands over as channel id with route subject 0 and
 * all record words 0. Subject 0 is never a channel's subject (a session
 * whose policy gives 0 is refused) and is not a record word, so a client
 * cannot forge a close event for its own or another channel. Holding the
 * slot keeps the bound: every ring entry belongs to a distinct slot, so the
 * ring still holds at most MAX_CHANNELS entries.
 *
 * Results. writ_shim_put runs on the Bend loop: it writes the record at
 * offset 16, the request's sequence number, and last the length (after a
 * release fence) into the channel's result bucket, then submits the
 * client's registered signal. A put for a channel that has closed or has
 * no taken request is skipped and counted. The shim never waits for a
 * client: the signal is submitted and not acknowledged, and the next reply
 * on the channel overwrites the result bucket, so a client that never
 * reads its replies holds at most one result (its own bucket) and one ring
 * entry, and cannot delay another channel (GB-008) in the cases run. The
 * submit itself is an RPC to this component's PD session in core; see
 * hosts/genode/INVENTORY.md "Signal submit" for when that could block and
 * which client cases are not shown. The client may map its result
 * bucket writable (Genode RAM dataspaces carry no read-only capability);
 * the shim never reads the result bucket, so that changes nothing here.
 *
 * Failure behaviour (host failure handling, not policy). Session creation
 * answers INSUFFICIENT_RAM when the donated quota is below
 * CHANNEL_SESSION_RAM (Root_component itself answers INSUFFICIENT_CAPS below
 * Writ_channel::Session::CAP_QUOTA), DENIED when no policy matches or MAX_CHANNELS are
 * open, or all slots are open or closing. A closed channel is removed
 * from the table under the mutex before it is destroyed, so take never
 * copies from a freed bucket.
 */

enum : unsigned {
	CHANNEL_BUCKET_SIZE  = Writ_channel::Session::BUCKET_SIZE,   /* 4096 */
	CHANNEL_HEADER_SIZE  = 16,
	CHANNEL_RECORD_WORDS = 16,
	CHANNEL_RECORD_SIZE  = CHANNEL_RECORD_WORDS*4,               /* 64   */
	CHANNEL_QUEUE_DEPTH  = 8,
	MAX_CHANNELS         = 8,
	CHANNEL_EP_STACK     = 8*1024*sizeof(long),
	CHANNEL_SESSION_RAM  = 2*CHANNEL_BUCKET_SIZE + 8*1024,

	/* the shim's own refusal record (transport, not a Writ decision) */
	CHANNEL_VERSION           = 1,
	CHANNEL_KIND_REFUSAL      = 3,
	CHANNEL_DECISION_REFUSED  = 3,   /* not a Writ decision word (1, 2) */
	CHANNEL_REASON_BAD_LENGTH = 256,

	/* the route subject take reports for a close event; never a channel's */
	CHANNEL_SUBJECT_CLOSED    = 0,
};

static_assert(CHANNEL_HEADER_SIZE + CHANNEL_RECORD_SIZE <= CHANNEL_BUCKET_SIZE,
              "a record fits its bucket");
/*
 * Every slot, open or closing, holds at most one ring entry, so with no
 * more slots than ring entries the ring cannot overflow: the "ring full"
 * count stays 0 by construction (the check in _channel_signalled is
 * defence in depth).
 */
static_assert(MAX_CHANNELS <= CHANNEL_QUEUE_DEPTH, "the ring cannot overflow");

static_assert(CHANNEL_SESSION_RAM <= Writ_channel::Session::RAM_QUOTA,
              "the client's donation covers a channel");

static Mutex &_channel_mutex() { static Mutex m { }; return m; }

static void _channel_signalled(uint32_t id);

struct Channel : Rpc_object<Writ_channel::Session>
{
	uint32_t      const id;
	uint32_t      const subject;
	Session_label const label;

	Attached_ram_dataspace request_ds;
	Attached_ram_dataspace result_ds;

	Signal_handler<Channel> request_handler;

	/* guarded by _channel_mutex */
	Signal_context_capability client_sigh { };
	bool     queued    = false;   /* an entry for this channel is in the ring */
	bool     taken     = false;   /* a record was handed to Bend, no put yet */
	uint32_t taken_seq = 0;

	void _handle_request() { _channel_signalled(id); }

	Channel(Env &env, Entrypoint &ep, uint32_t id, uint32_t subject,
	        Session_label const &label)
	:
		id(id), subject(subject), label(label),
		request_ds(env.ram(), env.rm(), CHANNEL_BUCKET_SIZE),
		result_ds (env.ram(), env.rm(), CHANNEL_BUCKET_SIZE),
		request_handler(ep, *this, &Channel::_handle_request)
	{ }

	Dataspace_capability request_bucket() override { return request_ds.cap(); }
	Dataspace_capability result_bucket()  override { return result_ds.cap(); }
	Signal_context_capability request_sigh() override { return request_handler; }

	void result_sigh(Signal_context_capability cap) override
	{
		Mutex::Guard guard(_channel_mutex());
		client_sigh = cap;
	}
};

struct Channel_entry { uint32_t id, subject; bool close; };

/* all guarded by _channel_mutex */
static Channel       *_channels[MAX_CHANNELS];
static uint32_t       _channel_closing[MAX_CHANNELS];  /* id whose close event is not yet taken */
static Channel_entry  _channel_ring[CHANNEL_QUEUE_DEPTH];
static unsigned       _channel_ring_head, _channel_ring_count;
static uint32_t       _channel_next_id = 1;

/* counters for writ_mem_report (diagnostics only), guarded by _channel_mutex */
static unsigned long _channel_signals, _channel_coalesced, _channel_ring_full,
                     _channel_bad_length, _channel_stale, _channel_taken,
                     _channel_put, _channel_put_skipped, _channel_closed;
static unsigned      _channel_ring_max;   /* most entries the ring has held at once */

static Semaphore &_channel_ready() { static Semaphore s { 0 }; return s; }

static Channel *_channel_lookup(uint32_t id)
{
	for (Channel *c : _channels)
		if (c && c->id == id) return c;
	return nullptr;
}

/* runs on the "writ_channel" entrypoint */
static void _channel_signalled(uint32_t id)
{
	{
		Mutex::Guard guard(_channel_mutex());
		_channel_signals++;
		Channel *c = _channel_lookup(id);
		if (!c) return;
		if (c->queued) { _channel_coalesced++; return; }
		if (_channel_ring_count == CHANNEL_QUEUE_DEPTH) { _channel_ring_full++; return; }
		_channel_ring[(_channel_ring_head + _channel_ring_count) % CHANNEL_QUEUE_DEPTH] =
			{ c->id, c->subject, false };
		_channel_ring_count++;
		if (_channel_ring_count > _channel_ring_max) _channel_ring_max = _channel_ring_count;
		c->queued = true;
	}
	_channel_ready().up();
}

/* libc's environment, for its already-attached config (set in _channel_init) */
static Libc::Env *_channel_libc_env;

struct Channel_root : Root_component<Channel>
{
	Env        &_env;
	Entrypoint &_ep;

	Channel_root(Env &env, Entrypoint &ep, Allocator &md_alloc)
	: Root_component<Channel>(ep, md_alloc), _env(env), _ep(ep) { }

	/*
	 * The subject word of the <policy> under <writ_channel> that matches
	 * the label best, 0 for none. Only a policy that names the label or a
	 * label prefix counts: the parent sets the prefix, while a suffix is
	 * the client's own choice and must not bind identity. The config is
	 * libc's, never updated, so every session sees the same policies.
	 */
	uint32_t _subject(Session_label const &label)
	{
		uint32_t subject = 0;
		_channel_libc_env->with_config([&] (Node const &config) {
			config.with_optional_sub_node("writ_channel", [&] (Node const &policies) {
				subject = with_matching_policy(label, policies,
					[&] (Node const &policy) -> uint32_t {
						if (!policy.has_type("policy")) return 0;   /* <default-policy> */
						if (!policy.has_attribute("label")
						 && !policy.has_attribute("label_prefix"))
							return 0;                               /* suffix-only */
						return policy.attribute_value("subject", uint32_t(0)); },
					[&] () -> uint32_t { return 0; }); }); });
		return subject;
	}

	Create_result _create_session(char const *args) override
	{
		Session_label const label = label_from_args(args);

		size_t const ram = Arg_string::find_arg(args, "ram_quota").ulong_value(0);
		if (ram < CHANNEL_SESSION_RAM) {
			warning("writ_channel: '", label, "' donated ", ram,
			        " bytes, a channel needs ", unsigned(CHANNEL_SESSION_RAM));
			return Create_error::INSUFFICIENT_RAM;
		}

		/*
		 * Caps need no check here: Local_service::budget_adjusted_args,
		 * which Root_component calls before _create_session, already
		 * refuses a cap_quota below Writ_channel::Session::CAP_QUOTA with
		 * INSUFFICIENT_CAPS (repos/base/include/base/service.h:170-177),
		 * and the args seen here are the adjusted ones.
		 */

		uint32_t const subject = _subject(label);
		if (!subject) {
			warning("writ_channel: no <policy> with a subject for '", label,
			        "', session denied");
			return Create_error::DENIED;
		}

		unsigned slot = MAX_CHANNELS;
		uint32_t id   = 0;
		{
			Mutex::Guard guard(_channel_mutex());
			for (unsigned i = 0; i < MAX_CHANNELS; i++)
				if (!_channels[i] && !_channel_closing[i]) { slot = i; break; }
			if (slot < MAX_CHANNELS) id = _channel_next_id++;
		}
		if (slot == MAX_CHANNELS) {
			warning("writ_channel: ", unsigned(MAX_CHANNELS),
			        " channels open or closing, session for '", label, "' denied");
			return Create_error::DENIED;
		}

		/* only this entrypoint creates sessions, so the slot stays free */
		Channel &c = *new (md_alloc()) Channel(_env, _ep, id, subject, label);
		{
			Mutex::Guard guard(_channel_mutex());
			_channels[slot] = &c;
		}
		log("writ_channel: channel ", id, " opened for '", label,
		    "' route subject ", subject);
		return c;
	}

	/*
	 * The slot stays closing until take has handed the close event to
	 * Bend; a request still queued for the channel becomes that event.
	 */
	void _destroy_session(Channel &c) override
	{
		bool queued_close = false;
		{
			Mutex::Guard guard(_channel_mutex());
			for (unsigned i = 0; i < MAX_CHANNELS; i++)
				if (_channels[i] == &c) {
					_channels[i]        = nullptr;
					_channel_closing[i] = c.id;
				}
			if (c.queued) {
				for (unsigned i = 0; i < _channel_ring_count; i++) {
					Channel_entry &e = _channel_ring[(_channel_ring_head + i) % CHANNEL_QUEUE_DEPTH];
					if (e.id == c.id) e.close = true;
				}
				_channel_stale++;
			} else if (_channel_ring_count < CHANNEL_QUEUE_DEPTH) {
				_channel_ring[(_channel_ring_head + _channel_ring_count) % CHANNEL_QUEUE_DEPTH] =
					{ c.id, c.subject, true };
				_channel_ring_count++;
				if (_channel_ring_count > _channel_ring_max) _channel_ring_max = _channel_ring_count;
				queued_close = true;
			} else {
				/* not reached (one entry per slot); then no event, slot freed */
				_channel_ring_full++;
				for (uint32_t &id : _channel_closing)
					if (id == c.id) id = 0;
			}
		}
		if (queued_close) _channel_ready().up();
		log("writ_channel: channel ", c.id, " closed, close event queued for Bend");
		Genode::destroy(md_alloc(), &c);
	}
};

static Kept<Entrypoint>             _channel_ep;
static Kept<Sliced_heap>            _channel_heap;
static Kept<Channel_root>           _channel_root;

/*
 * Announces the Writ_channel service when the config has a <writ_channel>
 * node. Called once from Libc::Component::construct before main runs.
 */
static void _channel_init(Libc::Env &env)
{
	_channel_libc_env = &env;
	env.with_config([&] (Node const &config) {
	config.with_optional_sub_node("writ_channel", [&] (Node const &) {
		_channel_ep.construct(env, size_t(CHANNEL_EP_STACK), "writ_channel",
		                      Affinity::Location());
		_channel_heap.construct(env.ram(), env.rm());
		_channel_root.construct(env, *_channel_ep, *_channel_heap);
		env.parent().announce(_channel_ep->manage(*_channel_root));
		log("writ_channel: service announced (bucket ", unsigned(CHANNEL_BUCKET_SIZE),
		    " bytes, record ", unsigned(CHANNEL_RECORD_SIZE), " bytes, queue depth ",
		    unsigned(CHANNEL_QUEUE_DEPTH), ", channels ", unsigned(MAX_CHANNELS), ")");
	}); });
}

/*
 * Writes the shim's fixed refusal record into c's result bucket (caller
 * holds _channel_mutex) and returns the client's signal to submit after
 * the mutex is released. Depends on nothing but the request's sequence.
 */
static Signal_context_capability _channel_refuse(Channel &c, uint32_t seq)
{
	uint32_t volatile *bucket = c.result_ds.local_addr<uint32_t volatile>();
	uint32_t const record[CHANNEL_RECORD_WORDS] = {
		CHANNEL_VERSION, CHANNEL_KIND_REFUSAL, CHANNEL_DECISION_REFUSED,
		CHANNEL_REASON_BAD_LENGTH, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };
	for (unsigned i = 0; i < CHANNEL_RECORD_WORDS; i++)
		bucket[CHANNEL_HEADER_SIZE/4 + i] = record[i];
	bucket[1] = seq;
	__atomic_thread_fence(__ATOMIC_RELEASE);
	bucket[0] = CHANNEL_RECORD_SIZE;
	return c.client_sigh;
}

/*
 * Wake-path observation (base-hw lane, Task 3; diagnostics only). Before
 * each down, take notes whether the semaphore was empty, so the down
 * parks the thread (counted in _channel_take_parked, shown in the channel
 * report as "take parked"), and the first take logs the name of the
 * thread it runs on. Together with the log order of the delayed runs this
 * shows what wakes the loop: the client signal ups the semaphore on the
 * "writ_channel" entrypoint, the parked helper thread returns from
 * writ_shim_take, and the runtime's io_help writes io_wake_fd, which wakes
 * the loop's select. The read of cnt() is unlocked; it can only misreport
 * a take that raced with a signal, never change what take returns.
 */
static unsigned long _channel_take_parked;
static bool          _channel_take_named;

extern "C" void writ_shim_take(uint32_t *record, uint32_t *channel, uint32_t *subject)
{
	for (;;) {
		bool const parks = _channel_ready().cnt() <= 0;
		if (!_channel_take_named) {
			_channel_take_named = true;
			Thread const *t = Thread::myself();
			log("writ_channel: take runs on thread '",
			    t ? t->name : Thread::Name("unknown"), "', ",
			    parks ? "parks in the semaphore" : "semaphore already up");
		}
		if (parks) _channel_take_parked++;
		_channel_ready().down();

		Signal_context_capability refused { };
		{
			Mutex::Guard guard(_channel_mutex());
			if (!_channel_ring_count) continue;   /* not reached: one up per entry */
			Channel_entry const e = _channel_ring[_channel_ring_head];
			_channel_ring_head = (_channel_ring_head + 1) % CHANNEL_QUEUE_DEPTH;
			_channel_ring_count--;

			if (e.close) {
				for (uint32_t &id : _channel_closing)
					if (id == e.id) id = 0;   /* the slot is free again */
				for (unsigned i = 0; i < CHANNEL_RECORD_WORDS; i++)
					record[i] = 0;
				_channel_closed++;
				*channel = e.id;
				*subject = CHANNEL_SUBJECT_CLOSED;
				return;
			}

			Channel *c = _channel_lookup(e.id);
			if (!c) { _channel_stale++; continue; }   /* not reached: closes convert */
			c->queued = false;

			uint32_t const volatile *bucket = c->request_ds.local_addr<uint32_t const volatile>();
			uint32_t const length = bucket[0];
			/*
			 * Pairs with the client's release fence before it writes the
			 * length: the record words read below are not read before the
			 * length that announced them.
			 */
			__atomic_thread_fence(__ATOMIC_ACQUIRE);
			uint32_t const seq    = bucket[1];
			if (length != CHANNEL_RECORD_SIZE) {
				_channel_bad_length++;
				warning("writ_channel: channel ", e.id, " request length ", length,
				        " is not ", unsigned(CHANNEL_RECORD_SIZE),
				        ", refused before Bend (bad length count ", _channel_bad_length, ")");
				refused = _channel_refuse(*c, seq);
			} else {
				for (unsigned i = 0; i < CHANNEL_RECORD_WORDS; i++)
					record[i] = bucket[CHANNEL_HEADER_SIZE/4 + i];

				c->taken     = true;
				c->taken_seq = seq;
				_channel_taken++;
				*channel = e.id;
				*subject = e.subject;
				return;
			}
		}
		/* a refusal: signal the client, then wait for the next entry */
		if (refused.valid())
			Signal_transmitter(refused).submit();
	}
}

extern "C" void writ_shim_put(uint32_t channel, uint32_t const *record)
{
	Signal_context_capability sigh { };
	{
		Mutex::Guard guard(_channel_mutex());
		Channel *c = _channel_lookup(channel);
		if (!c || !c->taken) { _channel_put_skipped++; return; }

		uint32_t volatile *bucket = c->result_ds.local_addr<uint32_t volatile>();
		for (unsigned i = 0; i < CHANNEL_RECORD_WORDS; i++)
			bucket[CHANNEL_HEADER_SIZE/4 + i] = record[i];
		bucket[1] = c->taken_seq;
		__atomic_thread_fence(__ATOMIC_RELEASE);
		bucket[0] = CHANNEL_RECORD_SIZE;

		c->taken = false;
		_channel_put++;
		sigh = c->client_sigh;
	}
	if (sigh.valid())
		Signal_transmitter(sigh).submit();
}

extern "C" void writ_mem_report(char const *tag)
{
	if (!_env) return;
	Pd_session::Stats const s = _pd->stats();
	unsigned live = 0, guards = 0;
	{
		Mutex::Guard guard(_mutex());
		for (Reservation const &r : _res)
			if (r.used) { live++; guards += r.num_guards; }
	}
	log("writ_mem: [", tag, "] ram used=", s.ram.used.value,
	    " limit=", s.ram.limit.value, " caps used=", s.caps.used.value,
	    " limit=", s.caps.limit.value, " reservations=", live,
	    " guards=", guards, " chunks populated (total)=", _chunks_populated,
	    " faults resolved=", _faults_resolved,
	    " benign retries=", _benign_retries,
	    " reserved at hint=", _reserved_at_hint,
	    " elsewhere=", _reserved_elsewhere, " released=", _released,
	    " timer short wakes=", _timer_short_wakes);
	/* a line of its own: the LOG session splits lines past its string limit */
	log("writ_mem: [", tag, "] rm upgrades sent=", _rm_upgrades_sent,
	    " declined=", _rm_upgrades_declined);
	if (_channel_root.constructed()) {
		Mutex::Guard guard(_channel_mutex());
		unsigned open = 0, closing = 0;
		for (unsigned i = 0; i < MAX_CHANNELS; i++) {
			if (_channels[i])        open++;
			if (_channel_closing[i]) closing++;
		}
		log("writ_mem: [", tag, "] channel signals=", _channel_signals,
		    " coalesced=", _channel_coalesced, " ring full=", _channel_ring_full,
		    " ring max=", _channel_ring_max,
		    " bad length=", _channel_bad_length, " stale=", _channel_stale,
		    " taken=", _channel_taken, " put=", _channel_put,
		    " put skipped=", _channel_put_skipped, " closed=", _channel_closed,
		    " open=", open, " closing=", closing);
		log("writ_mem: [", tag, "] channel take parked=", _channel_take_parked);
	}
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
	static Kept<Shared_object> libc;
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

/*
 * Opt-in exit report (diagnostics only): with WRIT_MEM_REPORT=1 in the
 * component's libc environment, one writ_mem_report line is logged from
 * libc's exit, so a run can record the RAM the component used. It reads no
 * other configuration and changes no behaviour. A runtime exit through
 * _exit (err_fail) skips it.
 */
static void _report_at_exit() { writ_mem_report("exit"); }

void Libc::Component::construct(Libc::Env &env)
{
	_heap.construct(env.ram(), env.rm());
	_pd.construct(env.pd_session_cap());

	_env = &env;   /* lookup helpers need it; entry points stay ENOSYS until resolved */
	if (!_resolve_libc()) {
		_libc_mmap = nullptr; _libc_munmap = nullptr; _libc_mprotect = nullptr;
		env.parent().exit(1);
		return;
	}

#if defined(WRIT_SHIM_FAULT_REGION_MAP)
	/* the "writ_fault" entrypoint (header, "Fault delivery", case 2) */
	_install_fault_handler();
#endif

	/* Writ channel service, only with a <writ_channel> config node */
	_channel_init(env);

	/* as repos/libports/src/lib/posix/construct.cc */
	Libc::with_libc([&] () {
		int argc = 0; char **argv = nullptr; char **envp = nullptr;
		populate_args_and_env(env, argc, argv, envp);
		environ = envp;
		if (char const *v = getenv("WRIT_MEM_REPORT"))
			if (v[0] == '1' && v[1] == 0) atexit(_report_at_exit);
		exit(main(argc, argv, envp));
	});
}
