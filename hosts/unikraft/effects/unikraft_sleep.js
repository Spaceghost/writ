// Unikraft.sleep: JS twin (bend guide effects, "The JS side"). The JavaScript
// runner is not a Unikraft target: there is no host layer, Unikraft console,
// or platform clock to call, so the effect stops the run instead of
// substituting a host console or clock.

function unikraft_sleep() {
  throw new Error("Unikraft.sleep: the JavaScript runner is not a Unikraft target; build with bend -o <name>.c and link hosts/unikraft/host.c into a Unikraft image (hosts/unikraft/scripts/build.sh)");
}

io_eff(CID(Unikraft.sleep), unikraft_sleep);
