// Unikraft.take: JS twin (bend guide effects, "The JS side"). The JavaScript
// runner is not a Unikraft target: there is no host layer or Writ channel
// to call, so the effect stops the run instead of substituting a host
// transport.

function unikraft_take() {
  throw new Error("Unikraft.take: the JavaScript runner is not a Unikraft target; build with bend -o <name>.c and link hosts/unikraft/host.c into a Unikraft image (hosts/unikraft/scripts/build.sh)");
}

io_eff(CID(Unikraft.take), unikraft_take);
