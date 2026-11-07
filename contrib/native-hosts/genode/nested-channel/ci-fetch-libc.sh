#!/usr/bin/env bash
# Fixed, public FreeBSD source input for the disposable Genode build only.
# Transport success alone never admits an archive; verify exact size and SHA.
set -euo pipefail
if [ "$#" -ne 2 ]; then exit 2; fi
writ_inputs="$(realpath -e -- "$1")"
writ_evidence="$(realpath -e -- "$2")"
writ_meta="$writ_evidence/libc-fetch.txt"
writ_target="$writ_inputs/libc.txz"
writ_hash=0da393ac2174168a71c1c527d1453e07372295187d05c288250800cb152a889b
writ_size=159564768
if [ ! -d "$writ_inputs" ] || [ ! -d "$writ_evidence" ] ||
   [ -e "$writ_target" ] || [ -L "$writ_target" ] ||
   [ -e "$writ_meta" ] || [ -L "$writ_meta" ]; then
  printf 'INCOMPLETE: invalid directory or existing output\n' >&2
  exit 1
fi
umask 077
(set -C; printf 'input=FreeBSD-12.0-src.txz\nexpected_bytes=%s\nexpected_sha256=%s\n' "$writ_size" "$writ_hash" > "$writ_meta")

writ_try_libc() {
  local label="$1" url="$2" partial="$writ_inputs/libc.$1.partial" status size observed
  printf 'attempt=%s\nurl=%s\n' "$label" "$url" >> "$writ_meta" || return 1
  if [ -e "$partial" ] || [ -L "$partial" ]; then
    printf 'result=not_verified\nreason=existing_partial\n' >> "$writ_meta" || return 1
    return 1
  fi
  status=0
  # The file-size limit applies only to curl and its own output, not the build.
  # The two fixed URLs and any redirects must use HTTPS with normal TLS checks.
  (ulimit -f 155825 || exit 1
   exec curl -q --proto '=https' --proto-redir '=https' --tlsv1.2 --max-redirs 5 \
     --retry 0 --connect-timeout 30 --max-time 600 --max-filesize "$writ_size" \
     --fail --silent --show-error --location --output "$partial" \
     --write-out 'http_code=%{http_code}\neffective_url=%{url_effective}\n' "$url") >> "$writ_meta" 2>&1 || status=$?
  printf 'transfer_exit=%s\n' "$status" >> "$writ_meta" || return 1
  if [ -f "$partial" ] && [ ! -L "$partial" ]; then
    size="$(wc -c < "$partial")" || return 1
    observed="$(sha256sum "$partial")" || return 1
    observed="${observed%% *}"
    printf 'received_bytes=%s\nreceived_sha256=%s\n' "$size" "$observed" >> "$writ_meta" || return 1
    if [ "$status" -eq 0 ] && [ "$size" = "$writ_size" ] && [ "$observed" = "$writ_hash" ]; then
      # Hard-link creation fails if the target already exists; do not replace it.
      ln -- "$partial" "$writ_target" || return 1
      rm -- "$partial" || return 1
      printf 'result=verified\nselected=%s\n' "$label" >> "$writ_meta" || return 1
      return 0
    fi
    rm -- "$partial" || return 1
  fi
  printf 'result=not_verified\n' >> "$writ_meta" || return 1
  return 1
}

writ_try_libc primary 'https://archive.freebsd.org/old-releases/amd64/12.0-RELEASE/src.txz' || \
  writ_try_libc fallback 'https://ftpmirror.your.org/pub/FreeBSD-Archive/old-releases/amd64/12.0-RELEASE/src.txz' || {
    printf 'overall=incomplete\n' >> "$writ_meta"
    exit 1
  }
