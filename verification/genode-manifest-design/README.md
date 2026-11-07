# Header comment token check

The [manifest design](../../openspec/changes/add-genode-host/public-synthetic-manifest-design.md)
corrects only the `observe.h` comment that incorrectly said exact config
comparison was absent. The [recorded output](header-token-check.txt) shows the
old and new preprocessed header bytes had the same SHA-256 and `cmp` exited 0.
The old header came from exact source `dff934fbbeef88dcd1059dfab76db14a335433b0`;
that commit and the separately merged `b8708a1` have identical `observe.h` and
`layout.h` bytes. GCC and the host headers are part of this token comparison's
trusted environment. It is not a proof of program behavior or a native host
qualification.

The commands used on this worktree were:

```sh
writ_token_dir=$(mktemp -d /tmp/writ-header-compare.XXXXXXXX)
git show dff934fbbeef88dcd1059dfab76db14a335433b0:contrib/native-hosts/genode/boot-inventory/observe.h > "$writ_token_dir/old.h"
cc -E -P -x c -Icontrib/native-hosts/genode/boot-inventory "$writ_token_dir/old.h" > "$writ_token_dir/old.tokens"
cc -E -P -x c -Icontrib/native-hosts/genode/boot-inventory contrib/native-hosts/genode/boot-inventory/observe.h > "$writ_token_dir/new.tokens"
sha256sum "$writ_token_dir/old.tokens" "$writ_token_dir/new.tokens"
cmp "$writ_token_dir/old.tokens" "$writ_token_dir/new.tokens"
```

The preprocessed outputs were external `/tmp` files and are not part of the
source package. OpenSpec 1.16.0 strict validation passed 44/44; the source
manifest and diff check also passed. No implementation, workflow, Genode/QEMU,
host probe or GPU test was changed or run for this design.
