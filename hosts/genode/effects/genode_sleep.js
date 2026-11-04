// Genode.sleep: JS twin (bend guide effects, "The JS side"). The JavaScript
// runner is not a Genode target: there is no shim, LOG session, or Timer
// session to call, so the effect stops the run instead of substituting a
// host console or clock.

function genode_sleep() {
  throw new Error("Genode.sleep: the JavaScript runner is not a Genode target; build with bend -o <name>.c and link the Genode shim (hosts/genode/)");
}

io_eff(CID(Genode.sleep), genode_sleep);
