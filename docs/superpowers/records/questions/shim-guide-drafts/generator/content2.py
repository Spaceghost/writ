# Reuse the orientation paragraphs, titles, range lists, and verdict tables
# from content.py (first structure) by running it with a capturing page().
_HERE = os.path.dirname(os.path.abspath(__file__))
PREV = {}
def _capture(n, slug, title, orient, ranges, ex, why, claims, verdict=None):
    PREV[n] = dict(slug=slug, title=title, orient=orient, ranges=ranges, verdict=verdict)
    return slug
_ns = dict(page=_capture, print=lambda *a, **k: None)
exec(open(os.path.join(_HERE, "content.py")).read(), _ns)

C = "<code>%s</code>"
files = []
def L(s):
    return "<code>writ_mem.cc:%s</code>" % s

CL = {}

CL[1] = [
("Exactly one fault front end is compiled. A build that defines both or neither of <code>WRIT_SHIM_FAULT_LINUX_SIGSEGV</code> and <code>WRIT_SHIM_FAULT_REGION_MAP</code> fails, and no runtime attribute selects it.",
 [(241, 243), (62, 74)],
 "Line 241 compares whether each macro is defined, and the <code>#error</code> fires unless exactly one is. The header gives the reason it is a build-time choice: the base-linux path issues raw Linux system calls that are an unresolvable exception on base-hw, and a config attribute would hand the choice to the integrator. This constrains what goes into the binary; it decides nothing about any request.",
 "confirmed", "the guard and the stated reason match"),
("Every bound in the static enum and the base-hw constants is a literal; none is derived from config, the environment, a caller's argument, or Bend.",
 [(286, 302)],
 "All values are enum constants fixed at compile time, so no caller, label, or Bend value can move them. They are capacity bounds (table sizes, a size threshold, a 2 MiB granularity, quota margins, a retry cap) and an exit-code convention. Whether each one's effect is mechanical is judged where it is used (pages 3 to 6); at this point they are plainly not inputs anyone controls at run time.",
 "confirmed", "they are literals and nothing assigns them"),
("<code>construct</code> builds the Heap and a plain PD client, resolves libc's originals (exit 1 on failure), starts the fault entrypoint on base-hw, starts the channel service only if config has <code>&lt;writ_channel&gt;</code>, and runs <code>main</code>. The only environment variable it reads, <code>WRIT_MEM_REPORT</code>, only registers a diagnostic report.",
 [(1890, 1908), (1909, 1919)],
 "The sequence is exactly as stated, and the exit at 1898 is the only early stop. <code>WRIT_MEM_REPORT</code> is compared with the literal string <code>\"1\"</code> and only registers <code>_report_at_exit</code> (1888), which logs counters. Everything opened here (PD client, the libc ROM through <code>Shared_object</code>, <code>writ_fault</code>, the channel service) is listed under Sessions in <code>INVENTORY.md:90-231</code>.",
 "confirmed", "the order, the single env read, and the sessions match the inventory"),
("<code>_resolve_libc</code> refuses to start if the lookup returns the shim's own functions, and until it succeeds the entry points return <code>ENOSYS</code>.",
 [(1858, 1879), (1041, 1044)],
 "The self-check at 1869-1874 prevents forwarding from recursing into the shim. On failure <code>construct</code> clears the three pointers (1897), so the <code>ENOSYS</code> guard at 1044 (and 1055, 1075) still applies. This is a start-up integrity check with a fixed outcome, not a choice.",
 "confirmed", "the check and the ENOSYS guards are both present"),
]

CL[2] = [
("<code>_qualifies</code> tests only the request's shape (length, prot, flags, fd, offset); a non-qualifying call is forwarded unchanged to libc.",
 [(907, 914), (1041, 1051)],
 "The predicate reads its five arguments and nothing else: no caller identity, label, or Bend state is available to it. A non-qualifying call reaches <code>_libc_mmap</code> with the same arguments (1047). The 1 GiB threshold is a fixed shape test that separates the runtime's heap and stack reservations from ordinary allocations.",
 "confirmed", "the filter reads only its arguments"),
("<code>munmap</code> releases only a whole reservation: an overlapping range that is not exactly the reservation is <code>EINVAL</code>, and a range overlapping no reservation goes to libc.",
 [(1053, 1071)],
 "The loop finds the first reservation the range overlaps; anything other than its exact base and page-rounded size is <code>EINVAL</code>. The refusal is \"cannot do a partial unmap\", since the shim has no way to split a region map, not a judgement about the caller.",
 "confirmed", "the whole-reservation rule and the libc fallthrough are both visible"),
("<code>mprotect</code> on a reservation either records a <code>PROT_NONE</code> guard or fails (<code>EINVAL</code>, <code>ENOTSUP</code>, <code>ENOMEM</code>); the one silent success is read-write on a range with no guard.",
 [(1087, 1097), (1105, 1121)],
 "Validation comes before any arithmetic that could wrap. Read-write returns 0 only when no guard overlaps (1105-1110), because a reservation is already read-write; lifting a guard and any other protection are <code>ENOTSUP</code>, and a fifth guard is <code>ENOMEM</code> (the fixed table of 4). These are \"cannot do this exactly\" refusals, the same for every caller.",
 "confirmed", "every branch either acts as asked or fails"),
("If re-attaching the pieces around a new guard fails, the guard stays recorded and the call returns <code>ENOMEM</code>; the shim never drops the guard to save the data.",
 [(1123, 1137)],
 "The guard was already added at 1121 and is not removed on the failure path. The trade-off is fail-closed: data outside the guard may become unreachable, but the guard range never carries a mapping. That is a fixed safety rule, not a choice made per request.",
 "confirmed", "the failure path keeps the guard"),
]

CL[3] = [
("Every refusal in <code>_reserve</code> sets <code>errno = ENOMEM</code>, undoes what it already built, and returns <code>MAP_FAILED</code>.",
 [(930, 935), (946, 966), (992, 996)],
 "Each refusal (too large, no slot, no fault handler, zero size, chunk table, region map, attach) returns <code>MAP_FAILED</code> with <code>ENOMEM</code>. Cleanup matches what was built: the chunk table is freed at 964 and 994, and the region map destroyed at 993. <code>ENOMEM</code> is how Linux reports exhausted address space, which the runtime already handles.",
 "confirmed", "each exit is a refusal with matching cleanup"),
("A hint is tried only when it is page-aligned; otherwise, or on failure, the shim attaches wherever the local region map allows. It does not refuse the call or pick an address for any other reason.",
 [(969, 991)],
 "This is the one place the shim picks something the caller did not ask for: an address other than the hint (988-991). It is Linux <code>mmap</code> semantics without <code>MAP_FIXED</code>, and the comment at 969-973 says the runtime checks the result against its hint and unmaps a misplaced reservation itself, so the caller still decides. Mechanical, not policy.",
 "confirmed", "the fallback is Linux's hint rule and the caller keeps the decision"),
("A qualifying request above <code>MAX_RESERVATION</code> (1 TiB), or with all 32 slots used, fails with <code>ENOMEM</code> before anything is created. The comment records that the 1 TiB bound also caps the runtime's <code>corpus_grow</code>.",
 [(916, 935)],
 "Both checks run before any allocation. The 1 TiB bound also prevents a length that would round to zero, and it stops <code>corpus_grow</code> at a 2 TiB corpus. The 32 slots cap lanes at about 30 (<code>INVENTORY.md:379-383</code>). These are fixed capacity bounds that read no Writ fact; they affect how far the runtime can grow, not who may do what.",
 "confirmed", "the bounds sit before any allocation and are constants"),
("<code>_release</code> detaches and frees every populated chunk, destroys the region map, frees the chunk table, and on base-linux clears the retry entries for this reservation's pages.",
 [(1004, 1028)],
 "All four steps are present, in that order, and the slot is reset at 1026. Clearing the retry entries (1016-1024) means a later reservation at the same addresses starts with no retry history. Pure resource release.",
 "confirmed", "every resource built in <code>_reserve</code> is returned"),
]

CL[4] = [
("<code>_populate</code> refuses with a named reason, before allocating, when the PD's available RAM is below the chunk plus <code>RAM_MARGIN</code> or its caps are below <code>CAP_MARGIN</code>. The allocation goes through the plain <code>_pd</code> client, not <code>Env::pd()</code>.",
 [(553, 557), (643, 662)],
 "The margin checks (648-652) come before <code>alloc_ram</code> (656), and every error is named. <code>_pd</code> is a plain <code>Pd_session_client</code> (557, built on <code>pd_session_cap()</code> at 1893), so an out-of-quota allocation returns an error and never becomes a blocking resource request. The margins are fixed Genode quota bookkeeping (keep 64 KiB and 8 caps free for the rest of the component), not Writ budget accounting. A reviewer could still call \"keep 64 KiB back\" a host resource rule; it is compile-time and the same for every fault.",
 "confirmed", "the checks precede the allocation and use the plain client"),
("If any piece fails to attach, <code>_populate</code> detaches the pieces, frees the RAM, and clears the chunk entry; no half-populated chunk remains.",
 [(664, 673)],
 "The chunk is marked populated before attaching (664) so the pieces can be computed, and the failure path undoes all three steps. <code>_detach_pieces</code> also detaches pieces that never attached, which I take to be a no-op on an empty range; I did not check whether core logs a warning for it. The refusal reason from the attach is returned unchanged.",
 "confirmed", "the failure path undoes every step"),
("<code>_upgrade_rm_session</code> acts only on <code>OUT_OF_RAM</code>/<code>OUT_OF_CAPS</code>, only if the PD keeps its margins after the transfer, with fixed amounts; <code>_attach_pieces</code> allows at most <code>RM_UPGRADE_ATTEMPTS</code> (4) upgrades per piece, and every upgrade sent or declined is counted.",
 [(570, 594), (613, 621)],
 "As stated: fixed amounts (8 KiB or 2 caps), the margin test, and the counters. With <code>attempt &lt; 4</code> a piece gets at most 4 upgrades, so 5 attach tries. The upgrade is a session upgrade sent to the parent (<code>Env::upgrade</code>, header 166-174) and paid from the component's own quota, so it does not ask for more resources. It is a bounded mechanical retry, with one documented exposure: a parent that answers PENDING could block it (171-173).",
 "confirmed", "the bound, the margins, and the counters are all in these lines"),
("Pieces never cover a guard range and are mapped non-executable and writeable.",
 [(414, 432), (547, 551)],
 "<code>for_each_piece</code> skips any position inside a guard and stops each piece at the next guard's start, so no piece overlaps a guard. <code>_piece_attr</code> fixes <code>executable = false</code>, <code>writeable = true</code> for every piece. No caller influences either.",
 "confirmed", "the loop skips guards and the attributes are fixed"),
]

CL[5] = [
("<code>_resolve_fault</code> has exactly four outcomes (outside, guard, already populated, populate or <code>_populate</code>'s refusal) and reads only the reservation's size, guards, and chunk table.",
 [(680, 696)],
 "This is the one place either platform chooses between \"populate\" and \"refuse\", and its inputs are an offset and the shim's own tables. No identity, label, or Bend state is reachable from here. Refusing a guard touch is the guard's purpose, not a choice.",
 "confirmed", "four outcomes, no outside input"),
("A SIGSEGV not generated by the kernel (<code>si_code &lt;= 0</code>, from <code>kill</code>/<code>tgkill</code>/<code>sigqueue</code>) is not treated as a fault: the default action is restored and the signal re-raised on the thread.",
 [(711, 726)],
 "The check comes before any lookup, so a signal sent by another process cannot make the shim map memory. The response is fixed: restore the default action, re-raise, and the process dies as Linux would have killed it.",
 "confirmed", "the early branch is unconditional on anything but si_code"),
("The base-linux refusal prints one <code>raw</code> line, restores the default SIGSEGV action, and returns; the retried access then kills the process. Nothing on this path populates a guard or maps memory elsewhere.",
 [(702, 709), (728, 737)],
 "<code>_refuse</code> touches no reservation state. Returning from the handler retries the faulting instruction, which faults again with the default action in place, and Linux terminates the process. There is no alternative outcome on this path. The documented limits (handler on the faulting stack, so a stack overflow dies without the line; deadlock if the faulter holds the mutex) are recorded in the header (213-238) and in <code>INVENTORY.md:689-705</code>.",
 "confirmed", "the refusal ends the process and does nothing else"),
("A fault on an already-populated chunk is retried only while <code>_retry_allowed</code> allows (at most 16 per page in 16 round-robin slots), and refused after that.",
 [(505, 519), (739, 745)],
 "This is the memory half's clearest \"decides to kill\" rule, and I read it as a bounded mechanical limit. It exists only so that a fault the shim cannot fix does not loop forever, and it reads nothing but a page address and a counter. Its known flaws are mechanical too: a page that races harmlessly more than 16 times over a reservation's life is killed, and more than 16 stuck addresses can evict each other and livelock (494-501). Neither involves a Writ fact; both are availability limits.",
 "confirmed", "the cap and its stated limits match the code"),
]

CL[6] = [
("A fault in the PD's address space, stack area, or linker area is refused before the shim mutex is taken and is never resolved.",
 [(830, 836), (884, 890)],
 "The loop over <code>_pd_areas</code> runs before the <code>Mutex::Guard</code> at 836, and every non-NONE fault there goes straight to <code>_refuse</code>. The areas are registered once in construct (884-889). Taking the refusal before the mutex means a thread that faults while holding the mutex still gets a recorded exit. Mechanical: no fault in those areas can be resolved by this unit.",
 "confirmed", "the area loop precedes the mutex and only refuses"),
("For each live reservation the handler drains <code>fault()</code> until <code>Type::NONE</code>, sends each fault through <code>_resolve_fault</code>, and refuses (does not retry) a reflected fault on a populated chunk.",
 [(836, 853), (143, 151)],
 "The drain is needed because signals coalesce. Refusing a populated-chunk fault (849-850) looks like a choice but is not: on base-hw core resolves touches of attached ranges itself, so a fault that is still reflected cannot be fixed here (143-151). The base-linux retry table is not compiled on this path (505-520).",
 "confirmed", "the loop and the refusal match the header's reasoning"),
("<code>_refuse</code> logs the counters and the reason through the LOG session, calls <code>Parent::exit(139)</code>, and sleeps; it never wakes the faulting thread.",
 [(786, 796), (299, 300)],
 "The function is as stated and <code>[[noreturn]]</code>. Exit value 139 is a reporting convention (128 + SIGSEGV) and changes no outcome, since the component ends either way. Its weakness is evidential: init records an exit value, not a fault, so only the shim's own line distinguishes it from a voluntary exit 139 (header 207-211, <code>INVENTORY.md:305-319</code>). That is a GB-003 evidence limit, not a GB-006 decision; on base-linux there is no exit value at all, since Linux kills the process and init logs nothing.",
 "confirmed", "the refusal ends the component and wakes nothing"),
("No reservation can exist without the handler: it is registered on each new region map before <code>_reserve</code> returns, <code>writ_fault</code> is started in construct, and <code>_reserve</code> refuses if the handler was never installed.",
 [(893, 898), (941, 946), (1902, 1905)],
 "<code>_watch_faults</code> is called at 967, after the region map is created and before it is attached or returned. On base-hw <code>_fault_handler_installed</code> is set only by <code>_install_fault_handler</code> (890), which construct calls before <code>main</code>. The ENOMEM at 946 is a fail-closed precondition, not a choice.",
 "confirmed", "registration precedes first use on every path"),
]

CL[7] = [
("<code>writ_shim_log</code> passes the bytes to <code>Genode::log</code> unchanged (up to <code>len</code> or the first NUL); it filters, labels, and adds nothing, and a null pointer does nothing.",
 [(1252, 1256), (1150, 1158)],
 "One call, no inspection of the text. The label prefix comes from the LOG service, not the shim, and splitting a line longer than 232 bytes is the LOG session's behaviour. What the LOG service does to unusual bytes is outside this file.",
 "confirmed", "the function only forwards"),
("<code>writ_shim_sleep_ms</code> returns only once the session clock has advanced by at least <code>ms</code>, and otherwise ends the component with exit 1 on a backwards clock, a clock that did not advance, or the round cap.",
 [(1265, 1287), (1210, 1216)],
 "The loop is as described. The three stops are fail-stop host-failure handling: they read only the timer's own readings and a round counter. <code>MAX_SLEEP_ROUNDS</code> (16) is a bounded mechanical limit that keeps a broken connection from spinning. The only Writ-visible effect is availability: a bad clock stops every client of the component.",
 "confirmed", "the deadline loop and the three stops are all here"),
("The route probe treats only <code>DENIED</code> as no route; a quota answer counts as a route and is left to the Connection, and the probe session is closed again on success.",
 [(1218, 1236)],
 "This exists because a plain session request that the parent denies hangs the component silently (header 1185-1190). On a quota error there is nothing to close. Whether a route exists is the integrator's and init's decision; the shim only turns a silent hang into a recorded exit 1.",
 "confirmed", "only DENIED stops, and success closes the probe"),
("<code>writ_shim_now_ms</code> returns the timer's <code>elapsed_ms()</code>, or 0 before <code>construct</code>, and nothing else.",
 [(1258, 1263)],
 "One RPC and a null check. The 32-bit truncation happens in the Bend twin, not here (<code>INVENTORY.md:85</code>).",
 "confirmed", "nothing else happens"),
]

CL[8] = [
("The subject stored on a channel comes only from the integrator's config, matched against the parent-prefixed label: <code>_create_session</code> reads only the label and <code>ram_quota</code> from the client's arguments, and takes the subject from <code>_subject</code>.",
 [(1555, 1579)],
 "The client controls the label suffix and the quota it donates, nothing else that reaches this code. The cap check happens earlier, in <code>Root_component</code> (comment 1566-1572). The subject is computed by <code>_subject</code> from libc's read-only config view, and the session is denied when it is 0.",
 "confirmed", "only the label and ram_quota are read from the arguments"),
("A <code>&lt;default-policy&gt;</code>, a policy with only <code>label_suffix</code>, no match, or <code>subject=\"0\"</code> all give subject 0, and subject 0 is <code>DENIED</code>.",
 [(1539, 1553)],
 "The code does exactly this. It is also the file's strongest candidate for \"policy\": a security rule written in C++ decides which kinds of policy node may bind identity, and so who may hold a channel. My argument that it is admitted binding: it applies one fixed rule to every label, the integrator writes the subject, and it grants nothing, because every request on the channel is still accepted or denied by Bend. GB-007 requires the route identity to be one the client cannot choose, and excluding the client-chosen suffix is what makes that true.",
 "confirmed", "the code matches; whether it is acceptable binding is your judgement, and I think it is"),
("Apart from claim 2, a session is refused only for capacity: <code>ram_quota</code> below <code>CHANNEL_SESSION_RAM</code>, or no free slot, where a closing slot stays taken until Bend has taken its close event.",
 [(1581, 1593), (1610, 1619)],
 "The quota check is at 1559-1564 (shown under claim 1). The slot search skips closing slots, and <code>_destroy_session</code> marks a slot closing rather than freeing it. <code>MAX_CHANNELS</code> (8) is a fixed capacity bound that keeps the ring from overflowing (static assert at 1430), so a ninth session is refused for capacity, not for who it is.",
 "confirmed", "the only other refusals are capacity bounds"),
("The four RPC methods return the two bucket capabilities and the request signal, or store the client's result signal; none reads a bucket or decides anything.",
 [(1467, 1475)],
 "Each method is one line, a capability handover or a store under the mutex. This matches the interface in <code>writ_channel_session.h:72-75</code> and GB-011.",
 "confirmed", "the four methods only hand over capabilities"),
]

CL[9] = [
("<code>take</code> copies exactly 16 words, once, after an acquire fence, and only when the length is exactly 64; Bend sees only that copy.",
 [(1738, 1759)],
 "The length is read, then the fence, then the sequence and the words. The copy goes into the caller's <code>record</code> buffer, so a client rewriting its bucket afterwards cannot change what Bend decides on. Clearing <code>queued</code> before the copy allows the next signal to queue a fresh entry.",
 "confirmed", "one copy, gated on the length, after the fence"),
("The subject returned to Bend is the one stored at session creation, never a word from the bucket; a close event returns subject 0 and an all-zero record.",
 [(1503, 1516), (1727, 1735), (1760, 1766)],
 "The ring entry carries <code>c-&gt;subject</code>, set at <code>_create_session</code> (1513), and take returns <code>e.subject</code> (1765). The close event translates a native fact (a session closed) into subject 0, which no open channel can have, since subject 0 is refused at creation. That entry triggers Bend's own unbinding; the shim decides nothing about it.",
 "confirmed", "the subject flows only from the session record"),
("A wrong length is counted, warned, and answered with the fixed record from <code>_channel_refuse</code>, which depends on nothing but the request's sequence number, and never reaches Bend.",
 [(1751, 1756), (1674, 1686), (1412, 1416)],
 "This is the one result the shim writes without Bend, so ask whether it is an alternate release decision. I read it as a fixed transport check: it depends only on the length word, it is the same record for every channel and subject, and its kind, decision and reason words (3, 3, 256) are outside the monitor's (kind 2, decisions 1 and 2, reasons 0 to 8). GB-006's own scenario requires exactly this answer before any Bend parsing.",
 "confirmed", "the record is fixed and the gate is the length alone"),
("<code>put</code> copies Bend's record without inspecting it, writes the sequence number and then the length after a release fence, and is skipped (counted) for a closed channel or one with no taken request.",
 [(1775, 1796)],
 "No branch depends on the record's contents. The skip is a transport fact (nothing to answer), counted. The signal is submitted after the mutex is released and not acknowledged, so the loop never waits on the client in the cases run; the open GB-008 gap on a blocked submit is in <code>INVENTORY.md:409-455</code>.",
 "confirmed", "the reply is copied unread"),
]

for n in range(1, 10):
    p = PREV[n]
    files.append(page(n, p["slug"], p["title"], p["orient"], p["ranges"], CL[n]))

# 10 verdict ------------------------------------------------------------
pv = PREV[10]
body = [x for x in pv["verdict"] if "Where you were asked to judge" not in x]

EV = []
EV.append("<p>GB-006 lets the shim translate native facts and perform admitted effects. It forbids policy, grants, label decisions, accounting, replay rules, and alternate release decisions. Reading the whole file against that list: the memory half (pages 2 to 6) decides only populate-or-refuse, from an offset and its own tables. The console and time half (page 7) forwards bytes and reads a clock. The channel half (pages 8 and 9) moves records by copy. It never parses a request or a reply, and it writes only one result of its own. Every exit and refusal is fixed at compile time and the same for every caller. Six places could still be argued; my reading of each:</p>")
EV.append("<ol>")
for item in [
 "<strong>Channel admission and identity binding</strong> (" + L("1539-1553") + ", " + L("1574-1579") + "). This is the strongest candidate: C++ decides which policy forms bind identity, and denies the rest. For the shim: one fixed rule, an integrator-written subject, no grant, and every request still decided by Bend. GB-007 needs a route identity the client cannot choose, and excluding the suffix is what delivers that. Against: who may hold a channel, and as which subject, is an authority fact set outside Bend. I come down on admitted binding, but would ask that the GB-006 rationale name this rule explicitly.",
 "<strong>Transport refusal record</strong> (" + L("1751-1756") + ", " + L("1674-1686") + "). This is a result written without Bend. But it is fixed and keyed on the length word alone, its words lie outside the monitor's decision space, and GB-006's own scenario requires it. Not an alternate release decision.",
 "<strong>Close event</strong> (" + L("1610-1642") + ", " + L("1727-1735") + "). The shim turns a session close into subject 0 and drops a queued request (counted stale). It translates a native fact; Bend does the unbinding.",
 "<strong>Quota margins and RM-session upgrades</strong> (" + L("575-594") + ", " + L("620") + ", " + L("648-652") + "). This is \"accounting\" only in Genode's sense: fixed margins and at most 4 fixed-size upgrades per piece, paid from the component's own quota, with no Writ budget consulted. A host resource rule. Note the PENDING-parent blocking exposure (171-173).",
 "<strong>Rules that end the component</strong>: the retry cap (" + L("510-519") + ", " + L("741-742") + "), the timer fail-stops (" + L("1272-1286") + "), and the base-hw populated-chunk refusal (" + L("849-850") + "). All are bounded mechanical limits that read no Writ fact. They affect availability, not authority, and the retry cap has documented false positives and a livelock case.",
 "<strong>Smaller items</strong>. Exit 139 (" + L("300") + ", " + L("794") + ") is a reporting convention with a GB-003 evidence weakness. The hint fallback (" + L("985-991") + ") follows Linux semantics, and the runtime decides whether to keep the result. The 1 TiB and 32-slot bounds (" + L("930-935") + ") limit growth and lane count. Read-write <code>mprotect</code> on a guard-free range returns 0 without acting (" + L("1105-1110") + ").",
]:
    EV.append("<li>%s</li>" % item)
EV.append("</ol>")
EV.append("<p>None of these consults a label, grant, budget, epoch, or replay state, and none can release a result other than Bend's or the fixed transport refusal. The limits that remain are availability and evidence limits already recorded in the inventory. They are not policy, but they should stay listed as limits rather than be read as qualification.</p>")

files.append(verdict_page(10, "verdict", pv["title"], pv["orient"], body, EV,
    "no-policy-confirmed",
    "No policy found (<code>no-policy-confirmed</code>), provided you accept item 1 as the admitted route-identity binding GB-007 requires. If you hold that the label-to-subject rule belongs in Bend, choose \"Policy found\" and cite lines 1539-1553."))

print("\n".join(files))
