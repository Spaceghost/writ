// Genode.take: JS twin (bend guide effects, "The JS side"). The JavaScript
// runner is not a Genode target: there is no shim or Writ
// channel to call, so the effect stops the run instead of substituting a
// host transport.

function genode_take() {
  throw new Error("Genode.take: the JavaScript runner is not a Genode target; build with bend -o <name>.c and link the Genode shim (hosts/genode/)");
}

io_eff(CID(Genode.take), genode_take);
