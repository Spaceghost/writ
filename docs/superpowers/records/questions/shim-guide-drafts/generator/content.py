C = "<code>%s</code>"

def L(s):
    return "<code>writ_mem.cc:%s</code>" % s

INV = "<code>INVENTORY.md:%s</code>"

files = []

# 1 ------------------------------------------------------------------
files.append(page(1, "overview-and-entry",
"Shim review 1 of 9: what the file claims to be, and how the component starts",
"""This first pass reads the file's own description of itself, its compile-time bounds, and the component entry. Some Genode vocabulary first. A <em>session</em> is a connection one component opens to a service another component (or the kernel-side <em>core</em>) provides; the <em>parent</em> (here, <code>init</code>) routes each session request according to its configuration. A <em>capability</em> is an unforgeable reference to an object in another component: holding it lets you call that object, nothing more. A <em>quota</em> is the RAM and capability count a component was given by its parent; opening a session donates part of it. The <em>Pd_session</em> (protection domain) is the component's own session to core for its address space, RAM, and caps. An <em>Entrypoint</em> is a thread that receives RPCs and signals for objects it manages. The shim is linked into each Bend program, replaces libc's <code>mmap</code>/<code>munmap</code>/<code>mprotect</code>, and supplies the C functions behind the <code>Genode.log/now/sleep/take/put</code> effects. Lines 1-239 are one long comment; read 1-74 now and keep the rest for later pages. Lines 438-486 hold the shim's state for the life of the process: <code>Kept&lt;T&gt;</code> never runs a destructor, so nothing is torn down under mapped memory at exit (<code>INVENTORY.md:360-367</code>).""",
[(1, 74), (241, 302), (438, 486), (1845, 1919)],
(1890, 1919),
"""The bounds at 286-297 (1 GiB threshold, 1 TiB cap, 32 reservations, 4 guards, 16 retries, 64 KiB/8 cap margins) are compile-time constants. Nothing reads them from config, the environment, or Bend, so they cannot vary by caller. Whether each one is merely mechanical is judged on the page that uses it. The front-end choice is made at build time on purpose (header 62-74) so an integrator cannot pick it in config.""",
[
"Exactly one fault front end is compiled: a build defining both or neither of <code>WRIT_SHIM_FAULT_LINUX_SIGSEGV</code> and <code>WRIT_SHIM_FAULT_REGION_MAP</code> fails at " + L("241-243") + "; no runtime attribute selects it (header " + L("62-74") + ").",
"Every bound in the static enum " + L("286-297") + " and the base-hw constants " + L("299-302") + " is an enum literal; none is derived from config, the environment, a caller's argument, or Bend.",
"<code>construct</code> " + L("1890-1919") + " does only this, in order: builds the Heap and a plain PD client (1892-1893), resolves libc's originals and exits 1 if that fails (1896-1900), on base-hw starts the fault entrypoint (1902-1905), starts the channel service only if config has <code>&lt;writ_channel&gt;</code> (1908, then 1653-1667), and runs <code>main</code>. The one environment variable it reads, <code>WRIT_MEM_REPORT</code> (1915-1916), only registers the diagnostic report at 1888.",
"<code>_resolve_libc</code> " + L("1858-1879") + " refuses to start if the lookup returns the shim's own functions (1869-1874), and until it succeeds the three entry points return <code>ENOSYS</code> (1044, 1055, 1075).",
]))

# 2 ------------------------------------------------------------------
files.append(page(2, "posix-entry-points",
"Shim review 2 of 9: the three libc replacements (mmap, munmap, mprotect)",
"""These are the public POSIX entry points the Bend runtime calls. The program binary's definitions shadow libc's by ordinary symbol interposition (<code>INVENTORY.md:50-55</code>, "How the entry points win"). The shim takes over only one shape of request: an anonymous, private, read-write mapping of at least 1 GiB. That is how the Bend runtime reserves its 8 GiB term heap and its 2 GiB per-lane stacks. Everything else goes to libc unchanged. The question for this page: does any refusal here depend on who is asking or what the memory is for, or only on whether the shim can carry the request out exactly? The inventory's "Exported symbols" table (<code>INVENTORY.md:73-88</code>) states the behaviour you are checking.""",
[(907, 914), (1031, 1137)],
(1041, 1071),
"""Each refusal here is "this unit cannot do that exactly": partial <code>munmap</code> (1063-1065), any protection other than RW or NONE, and lifting a guard (1108, 1112-1113) are unsupported operations, not judgments. <code>MAX_GUARDS</code> (1114) is a fixed table size. One place returns success without acting: RW on a guard-free range returns 0 (1105-1110), because a reservation is already RW. Decide whether you accept that as faithful.""",
[
"<code>_qualifies</code> " + L("907-914") + " tests only the request's shape (length, prot, flags, fd, offset); it reads no caller identity, label, or Bend state, and a non-qualifying call is forwarded unchanged to libc at 1046-1047.",
"<code>munmap</code> releases only a whole reservation: an overlapping range that is not exactly the reservation is <code>EINVAL</code> " + L("1063-1065") + "; a range overlapping no reservation goes to libc (1070).",
"<code>mprotect</code> on a reservation either records a <code>PROT_NONE</code> guard (1116-1121) or fails with <code>ENOTSUP</code>/<code>ENOMEM</code>/<code>EINVAL</code> " + L("1092-1114") + "; the single silent success is RW on a range with no guard (1105-1110).",
"If re-attaching the pieces around a new guard fails, the guard stays recorded and the call returns <code>ENOMEM</code> " + L("1124-1135") + "; the shim never drops the guard to save the data.",
]))

# 3 ------------------------------------------------------------------
files.append(page(3, "reservations",
"Shim review 3 of 9: making and releasing a reservation",
"""A qualifying <code>mmap</code> becomes a <em>reservation</em>: address space that is set aside but has no memory behind it yet. Genode terms: a <em>dataspace</em> is a piece of memory (or address space) that can be referenced by capability and attached into an address space. A <em>Region_map</em> is an address-space layout: a set of dataspaces attached at offsets. A region map can itself be exported as a dataspace (a "managed dataspace") and attached into another region map. An <em>Rm_connection</em> is a session to the RM service that creates such region maps. So <code>_reserve</code> asks the RM session for an empty region map of the requested size, attaches it into the component's own address space (<code>Env::rm()</code>), and records it in a fixed table of 32 slots. Nothing is populated, so no RAM is charged here. Read the table struct first (378-435), then <code>_reserve</code> and <code>_release</code>.""",
[(378, 435), (916, 1028)],
(969, 1001),
"""Two choices to judge. First, a hint that cannot be honoured is replaced by an address the local region map chooses (985-991). That is Linux's own <code>mmap</code> hint semantics, and the runtime compares the result with its hint and unmaps a misplaced one itself (969-973), so the caller still decides what to accept. Second, <code>MAX_RESERVATION</code> (930) also caps the runtime's <code>corpus_grow</code> at a 2 TiB corpus (919-929), and the 32 slots cap lanes at about 30 (<code>INVENTORY.md:379-383</code>). Both are fixed capacity bounds that surface as <code>ENOMEM</code>, which the runtime already handles as "cannot grow". No Writ fact enters either one.""",
[
"Every refusal in <code>_reserve</code> sets <code>errno = ENOMEM</code>, undoes what it already built, and returns <code>MAP_FAILED</code> (930, 935, 946, 951, 957-958, 963-966, 992-996).",
"A hint is tried only when it is page-aligned (985-986); otherwise, or on failure, the shim attaches wherever the local region map allows " + L("988-991") + " and counts which happened. It does not refuse the call or pick a reservation for any other reason.",
"Nothing in <code>_reserve</code> " + L("916-1002") + " reads anything except its arguments, the slot table, and the results of Genode calls.",
"<code>_release</code> " + L("1004-1028") + " detaches and frees every populated chunk, destroys the region map, frees the chunk table, and (base-linux) clears the retry entries for this reservation's pages (1016-1024), so a later reservation at the same address inherits no counts.",
]))

# 4 ------------------------------------------------------------------
files.append(page(4, "population-and-charging",
"Shim review 4 of 9: charging a chunk on first touch",
"""When the program first touches an untouched 2 MiB chunk of a reservation, the fault path (pages 5 and 6) calls <code>_populate</code>. It allocates a 2 MiB RAM dataspace from the component's own PD, which charges the component's RAM quota, and attaches it into the reservation's region map in "pieces" that skip any guard range. Two details matter for GB-006. Allocation goes through a plain <code>Pd_session_client</code> (557, built at 1893 on <code>pd_session_cap()</code>), not <code>Env::pd()</code>. The <code>Env::pd()</code> client turns an out-of-quota error into a blocking request to the parent for more resources. So a fault either succeeds from the quota the component already has, or is refused. On base-hw, attaching a piece costs metadata in core that is charged to the RM session's own small quota, so the shim may <em>upgrade</em> that session. An upgrade moves some of the component's own quota into the session; it is not a request for more. Header 153-189 explains this; <code>INVENTORY.md:92-120</code> (RM) and <code>:132-136</code> (PD) list it.""",
[(153, 189), (543, 673)],
(643, 673),
"""This page is "accounting" in the Genode sense, not the Writ sense. It checks the component's quota against fixed margins (649-652: chunk + 64 KiB RAM, 8 caps) and spends quota on at most four fixed-size RM upgrades per piece (570-572, 620). Those are bounded, mechanical rules, and every caller gets the same ones. No Writ budget, payment, or label is consulted. A reviewer could still call "keep 64 KiB back" or "spend own quota on an upgrade" a resource policy. If you do, note that it is host resource policy, decided at compile time. Also note the documented exception: under a parent that answers an upgrade with PENDING, the upgrade could block (171-173).""",
[
"<code>_populate</code> refuses with a named reason, before allocating, when the PD's available RAM is below the chunk plus <code>RAM_MARGIN</code> or caps are below <code>CAP_MARGIN</code> " + L("648-652") + "; it never calls the parent or <code>Env::pd()</code>.",
"If any piece fails to attach, <code>_populate</code> detaches the pieces, frees the RAM, and clears the chunk entry " + L("665-669") + "; no half-populated chunk remains.",
"<code>_upgrade_rm_session</code> " + L("575-594") + " acts only on <code>OUT_OF_RAM</code>/<code>OUT_OF_CAPS</code>, only if the PD keeps its margins after the transfer, with the fixed amounts at 570-571, and <code>_attach_pieces</code> stops after <code>RM_UPGRADE_ATTEMPTS</code> tries per piece (620); every upgrade sent or declined is counted.",
"Pieces never cover a guard range and are mapped non-executable and writeable: <code>for_each_piece</code> " + L("414-432") + " and <code>_piece_attr</code> " + L("547-551") + ".",
]))

# 5 ------------------------------------------------------------------
files.append(page(5, "fault-base-linux",
"Shim review 5 of 9: the fault decision and the base-linux SIGSEGV path",
"""On base-linux, Genode components are ordinary Linux processes, and an unpopulated part of a reservation is a <code>PROT_NONE</code> Linux mapping. Touching it raises the Linux signal <code>SIGSEGV</code>. A <em>signal handler</em> here means a Linux one: a function the kernel runs on the faulting thread. (Genode also has its own <code>Signal_handler</code>, an asynchronous notification dispatched by an entrypoint. That one appears on page 6.) Genode's own region-map fault notification is never delivered on base-linux (header 76-83). So the shim installs a raw SIGSEGV handler with the <code>rt_sigaction</code> system call, replacing base-linux's handler for the whole process (88-89). Both platforms share one decision function, <code>_resolve_fault</code> (688-696). Read it first. It is the only place that chooses between "populate" and "refuse". Then read the Linux front end. The base-linux row of <code>INVENTORY.md:274</code> ("Fault delivery" table) and the concurrency note at <code>:689-705</code> describe it.""",
[(76, 94), (213, 239), (305, 375), (487, 541), (680, 776)],
(711, 745),
"""<code>MAX_RETRIES</code> (293, used at 510-519 and 741-742) is the clearest "decides to kill" rule in the memory half. It is a bounded mechanical limit: it exists only so that a fault the shim cannot fix does not loop forever, and it reads nothing but a page address and a counter. Its stated flaws are both mechanical (494-501). A page that races harmlessly more than 16 times over a reservation's life is killed (a false positive). More than 16 stuck addresses at once can evict each other and livelock (a false negative). Neither is a Writ decision. Whether a false-positive kill is acceptable is an availability question, not a GB-006 one.""",
[
"<code>_resolve_fault</code> " + L("688-696") + " has exactly four outcomes (outside, guard, already populated, populated now or refused by <code>_populate</code>) and reads only the reservation's size, guard list, and chunk table.",
"A SIGSEGV not generated by the kernel (<code>si_code &lt;= 0</code>, from <code>kill</code>/<code>tgkill</code>) is not treated as a fault: the default action is restored and the signal re-raised on the thread " + L("717-726") + ".",
"The base-linux refusal " + L("702-709") + " prints one <code>raw</code> line, restores the default SIGSEGV action, and returns; the retried access then kills the process. Nothing on this path populates a guard or maps memory somewhere else.",
"An already-populated chunk is retried only while <code>_retry_allowed</code> " + L("510-519") + " allows (at most 16 per page in 16 round-robin slots), and refused after that (741-742).",
]))

# 6 ------------------------------------------------------------------
files.append(page(6, "fault-base-hw",
"Shim review 6 of 9: the base-hw region-map fault path and exit 139",
"""On base-hw (Genode's own kernel), core is the pager of every thread. When a thread touches part of a region map that has nothing attached, and a <em>fault handler</em> is registered on that region map, core halts the thread and sends a Genode signal instead of logging an error. A Genode <code>Signal_handler</code> is an object bound to an Entrypoint; when its signal arrives, the entrypoint's thread calls the handler method. Signals to one handler <em>coalesce</em>: several faults may arrive as one signal, which is why the handler drains every queued fault. The shim starts its own entrypoint, <code>writ_fault</code>, in <code>construct</code> before <code>main</code>. It registers one handler on every reservation's region map and on the PD's own address space, stack area, and linker area, so that faults outside every reservation (a null pointer, a thread's stack guard) also reach the shim and are refused. Unlike base-linux, a refusal here ends the component by asking the parent: <code>Parent::exit(139)</code>, where 139 = 128 + SIGSEGV. See <code>INVENTORY.md:275</code> (base-hw row) and the six limits at <code>:305-319</code>.""",
[(95, 151), (190, 211), (778, 900)],
(830, 853),
"""Two things here look like choices. "Refuse a reflected fault on a populated chunk" (849-850) is not a policy: on base-hw core resolves touches of attached ranges itself, so a reflected fault there is one the shim cannot resolve (143-151). Exit value 139 (300, 794) is a reporting convention. It changes no outcome, since the component ends either way. It matters for evidence, though: init records an exit value, not a fault, and only the shim's own line tells it apart from a voluntary exit 139 (207-211). That is a GB-003 evidence limit, not a GB-006 decision.""",
[
"A fault in the PD's address space, stack area, or linker area is refused before the shim mutex is taken and is never resolved " + L("830-834") + "; the areas are registered once at 884-889.",
"For each live reservation the handler drains <code>fault()</code> until <code>Type::NONE</code>, sends each fault through the shared <code>_resolve_fault</code>, and refuses (does not retry) a reflected fault on a populated chunk " + L("838-852") + "; the base-linux retry table is not compiled here (505-520).",
"<code>_refuse</code> " + L("788-796") + " logs the counters line and the reason through the LOG session, calls <code>Parent::exit(REFUSED_FAULT_EXIT)</code>, and sleeps; it never wakes the faulting thread.",
"No reservation can exist without the handler: <code>writ_fault</code> is started in <code>construct</code> (1902-1905, 863-891), each new region map registers the handler before <code>_reserve</code> returns (967, 895-898), and <code>_reserve</code> refuses if the handler was never installed (946).",
]))

# 7 ------------------------------------------------------------------
files.append(page(7, "console-and-time",
"Shim review 7 of 9: Genode.log, Genode.now, Genode.sleep",
"""These three C functions are what the Bend effects <code>Genode.log</code>, <code>Genode.now</code>, and <code>Genode.sleep</code> call (their C twins live in <code>hosts/genode/effects/</code>). Logging uses the component's existing LOG session. Time uses one <code>Timer::Connection</code>, a session to the timer service, opened on first use with the label <code>writ_shim</code> and kept for the component's life. Before opening it, the shim probes the route with <code>Env::try_session</code>, because a plain session request that the parent denies leaves the component hanging silently (header 1185-1190). The claim to check: the Bend program alone decides what is logged and when to wait (1146-1148), and the shim stops the component only when the clock itself cannot be trusted. <code>INVENTORY.md:233-259</code> ("Timer failure outcomes") and the Timer bullet at <code>:149-161</code> list this.""",
[(1140, 1287)],
(1265, 1287),
"""The exits here (1245, 1247, 1276, 1279, 1283, all through <code>_timer_fail</code> at 1211-1216) are fail-stop host-failure handling. A missing route, a clock that goes backwards or does not advance, or more than <code>MAX_SLEEP_ROUNDS</code> (16) <code>msleep</code> calls for one sleep ends the component with exit 1. The round cap is a bounded mechanical limit that stops a spin. None of these checks reads the request, the subject, or anything Bend computed. The only Writ-visible effect is availability: a bad clock stops every client. Note that the timer route itself is the integrator's choice.""",
[
"<code>writ_shim_log</code> " + L("1252-1256") + " passes the bytes unchanged to <code>Genode::log</code> (up to <code>len</code> or the first NUL); it filters, labels, or adds nothing, and a null pointer does nothing.",
"<code>writ_shim_sleep_ms</code> returns only once the session clock has advanced by at least <code>ms</code>, and otherwise ends the component with exit 1 on a backwards clock, a non-advancing clock, or the round cap " + L("1272-1286") + ".",
"The route probe treats only <code>DENIED</code> as no route; a quota answer counts as a route and is left to the Connection, and the probe session is closed again " + L("1223-1236") + ".",
"<code>writ_shim_now_ms</code> " + L("1259-1263") + " returns the timer's <code>elapsed_ms()</code>, or 0 before <code>construct</code>, and nothing else.",
]))

# 8 ------------------------------------------------------------------
files.append(page(8, "channel-sessions-and-identity",
"Shim review 8 of 9: the Writ channel service, sessions, and route identity",
"""When the component's config has a <code>&lt;writ_channel&gt;</code> node, the shim <em>announces</em> a service to its parent. Clients can then open <code>Writ_channel</code> sessions, which are routed by init. Each session gets two 4 KiB buckets (RAM dataspaces, one for requests, one for results) and a signal handler, all served on a dedicated entrypoint, <code>writ_channel</code>. The session interface (<code>writ_channel_session.h:72-75</code>) has four RPCs, and each only hands over a capability or registers one. The security-relevant step is at session creation. init prefixes every session label with the requesting child's name, so the client cannot forge that prefix. The shim looks the label up in the integrator's <code>&lt;policy&gt;</code> nodes and stores the matching <code>subject</code> number with the channel. Bend later maps that number to an identity (GB-007). Read the header 1289-1333 first. See <code>INVENTORY.md:177-200</code> and <code>:212-217</code>.""",
[(1289, 1333), (1402, 1476), (1521, 1667)],
(1532, 1553),
"""This is the section a reviewer is most likely to call policy. <code>_subject</code> encodes a security rule in C++: a <code>&lt;default-policy&gt;</code> or a suffix-only policy does not bind identity, because a label suffix is chosen by the client (1546-1549). <code>_create_session</code> then denies the session (1575-1579). The case for "binding": the shim decides no grant. It only looks up a word the integrator wrote, applies the same rule to every label, and leaves every request's accept or deny to Bend. The case for "policy": who may hold a channel, and under which subject, is an authority fact established here, outside Bend. <code>MAX_CHANNELS</code> (8) and the quota check are capacity bounds.""",
[
"The subject stored on a channel comes only from the integrator's config, matched against the parent-prefixed label: <code>_create_session</code> reads only the label and <code>ram_quota</code> from the client's arguments " + L("1557-1559") + " and takes the subject from <code>_subject</code> (1574).",
"A <code>&lt;default-policy&gt;</code>, a policy with only <code>label_suffix</code>, no match, or <code>subject=\"0\"</code> all give subject 0 " + L("1546-1551") + ", and subject 0 is <code>DENIED</code> " + L("1575-1579") + ".",
"Apart from claim 2, a session is refused only for capacity: <code>ram_quota</code> below <code>CHANNEL_SESSION_RAM</code> (1559-1564), or no free slot, where a closing slot stays taken until Bend has taken its close event " + L("1581-1593") + ".",
"The four RPC methods " + L("1467-1475") + " return the two bucket capabilities and the request signal, or store the client's result signal; none reads a bucket or decides anything.",
]))

# 9 ------------------------------------------------------------------
files.append(page(9, "channel-take-put-refusal",
"Shim review 9 of 9: queue, take, put, and the transport refusal",
"""This is the data path. A client writes a 64-byte record (16 words) after a 16-byte header into its request bucket, then signals. The <code>writ_channel</code> entrypoint queues one entry per channel in an 8-slot ring (1503-1519) and wakes a semaphore. <code>writ_shim_take</code> runs on a Bend runtime helper thread. It blocks on that semaphore, pops one entry, copies the record out once, and returns the record, the channel id, and the route subject stored at session creation. <code>writ_shim_put</code> copies Bend's reply into the result bucket without reading it and signals the client. One result is written by the shim itself: if the header length is not exactly 64, a fixed refusal record. GB-006's own scenario requires that ("dropped, counted, and answered with a fixed transport refusal before any Bend parsing"). See <code>INVENTORY.md:87-88</code>, <code>:201-211</code>, and the channel bounds at <code>:409-455</code>.""",
[(1334, 1400), (1478, 1519), (1669, 1842)],
(1742, 1767),
"""The length gate (1751-1756) is the one place the shim answers a client without Bend, so ask whether it is an alternate release decision. It is a fixed transport check. It depends only on the length word, and the record it writes (1674-1686) is the same for every channel and subject. Its kind, decision, and reason words (3, 3, 256; 1412-1416) are outside the monitor's (kind 2, decisions 1 and 2, reasons 0 to 8), so it cannot be read as a Writ outcome. Signal coalescing (1510) drops no data, because the bucket is read at take time. The close event (1727-1735) translates a native fact, a session closing, into subject 0, which no open channel can have.""",
[
"<code>take</code> copies exactly 16 words, once, after an acquire fence, and only when the length is exactly 64 " + L("1742-1759") + "; Bend sees only that copy.",
"The subject returned to Bend is the one stored at session creation (1513, 1765), never a word from the bucket; a close event returns subject 0 and an all-zero record " + L("1727-1735") + ".",
"A wrong length is counted, warned, and answered with the fixed record from <code>_channel_refuse</code> " + L("1674-1686") + ", which depends on nothing but the request's sequence number, and never reaches Bend.",
"<code>put</code> " + L("1775-1796") + " copies Bend's record without inspecting it, writes the sequence number and then the length after a release fence, and is skipped (counted) for a closed channel or one with no taken request; <code>writ_mem_report</code> (1798-1842) only reads counters and logs.",
]))

# 10 verdict ----------------------------------------------------------
def row(*cells):
    return "<tr>" + "".join("<td>%s</td>" % c for c in cells) + "</tr>"

V = []
V.append('<p class="note">You read <code>hosts/genode/shim/writ_mem.cc</code> at sha256 <code>9d9d32d2402bd947c96a4632ae945c6825d1291a3ce97e5ac45b7d0349f71b5d</code> (the hash recorded at <code>INVENTORY.md:643</code>). The Reviewer field (<code>INVENTORY.md:725-728</code>) still says "Not reviewed under GB-006". Your answer here is what task 2.2 needs before your name and that hash go into it.</p>')
V.append('<p><strong>Exported symbols</strong> (<code>INVENTORY.md:73-88</code>):</p>')
V.append('<table><tr><th>Symbol</th><th>Line</th><th>What it may do</th></tr>' + "".join([
 row(C % "mmap", L("1041"), "make a reservation for one request shape; otherwise forward to libc"),
 row(C % "munmap", L("1053"), "release a whole reservation; otherwise forward"),
 row(C % "mprotect", L("1073"), "record a PROT_NONE guard, or fail; otherwise forward"),
 row(C % "Libc::Component::construct", L("1890"), "component entry: resolve libc, start entrypoints, run main"),
 row(C % "writ_shim_log / now_ms / sleep_ms", L("1252") + ", 1259, 1265", "write bytes to LOG; read or wait on the Timer clock"),
 row(C % "writ_shim_take / put", L("1705") + ", 1775", "copy one request record to Bend; copy Bend's reply to the client"),
 row(C % "writ_mem_report", L("1798"), "log counters (diagnostics)"),
 row(C % "writ_mem_restore_rt", L("342-350"), "local asm symbol, base-linux only: rt_sigreturn"),
]) + '</table>')
V.append('<p><strong>Sessions and kernel interfaces opened</strong> (<code>INVENTORY.md:90-231</code>):</p>')
V.append('<table><tr><th>What</th><th>Where opened or used</th><th>Admitted when</th></tr>' + "".join([
 row("PD, plain client (RAM for chunks, stats)", L("1893") + "; 656, 648", "a fault on an unpopulated chunk passes <code>_resolve_fault</code> (688-696) and the margins (649-652)"),
 row("RM session (one region map per reservation; upgrades)", L("961-962") + "; 582, 589", "a qualifying <code>mmap</code> (907-914); an upgrade only on a quota attach error within margins (575-594)"),
 row("Local region map <code>Env::rm()</code>", L("976") + ", 1012", "reservation attach and release"),
 row("Region-map fault handlers, <code>writ_fault</code> entrypoint (base-hw)", L("866") + ", 884-889, 897", "always, at construct and per reservation"),
 row("Raw Linux <code>rt_sigaction</code>, <code>getpid</code>, <code>gettid</code>, <code>tgkill</code> (base-linux)", L("363-373") + ", 708, 723", "first qualifying <code>mmap</code> (939); refusal; a non-kernel SIGSEGV"),
 row("Parent <code>exit</code>", L("794") + " (139, base-hw fault refusal), 1214 (1, timer), 1898 (1, libc lookup)", "only on a refusal or failure"),
 row("Timer session <code>writ_shim</code>, plus one probe session", L("1231") + ", 1246", "first <code>Genode.now</code> or <code>Genode.sleep</code>"),
 row("LOG (existing session)", L("1255") + " and diagnostic lines", "each <code>Genode.log</code>"),
 row("ROM via <code>Shared_object</code> (<code>libc.lib.so</code>)", L("1862"), "once at construct"),
 row("Config, libc's attached view (no own ROM)", L("1542") + ", 1656", "construct; each channel session creation"),
 row("Writ_channel service, <code>writ_channel</code> entrypoint, <code>Sliced_heap</code>, two RAM buckets per session", L("1658-1662") + ", 1462-1463", "only with <code>&lt;writ_channel&gt;</code>; a session needs a matching label/label_prefix policy with nonzero subject (1539-1553)"),
 row("<code>Signal_transmitter</code> to the client", L("1771") + ", 1795", "after a transport refusal or a Bend <code>put</code>"),
]) + '</table>')
V.append('<p><strong>Where you were asked to judge "limit or policy":</strong> retry cap (510-519, 741-742); quota margins and RM upgrades (575-594, 648-652); 1 TiB and 32-slot bounds (930, 933-935); hint fallback (985-991); exit 139 (300, 794); timer fail-stop (1211-1216, 1272-1286); channel admission and identity rule (1539-1553, 1574-1593); transport refusal record (1674-1686, 1751-1756). GB-006 says the shim may translate native facts and perform admitted effects, but must not implement policy, grants, label decisions, accounting, replay rules, or alternate release decisions.</p>')

files.append(page(10, "verdict",
"Shim review: GB-006 verdict",
"""This page asks for your verdict on the whole file. You have now read every line range in <code>writ_mem.cc</code>. The tables below collect what the shim exports, what it opens, and the condition under which each effect happens. Use them to check that nothing is missing from <code>INVENTORY.md</code> and that each effect is admitted by a native fact (a call's shape, a fault, a session request) rather than by a Writ decision made in C++. If you choose "policy found", name the lines. If one of the judgement calls is acceptable only with a change to the inventory's wording, or with a note in the GB-006 rationale, say which.""",
[], None, None, [], verdict=V))

print("\n".join(files))
