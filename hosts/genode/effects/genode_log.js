// Genode.log: JS twin (bend guide effects, "The JS side"). The JavaScript
// runner is not a Genode target: there is no shim, LOG session, or Timer
// session to call, so the effect stops the run instead of substituting a
// host console or clock.

function genode_log() {
  throw new Error("Genode.log: the JavaScript runner is not a Genode target; build with bend -o <name>.c and link the Genode shim (hosts/genode/)");
}

io_eff(CID(Genode.log), genode_log);
