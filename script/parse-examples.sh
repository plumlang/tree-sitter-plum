#!/usr/bin/env bash
# Parse every .plum file in a Plumlang checkout and report the files that
# produce ERROR or MISSING nodes. Files whose expected diagnostics (.err)
# hold a lexer or parser error (E01xx, E0201-E0214, E0216, E0217) are
# intentionally invalid and are skipped, as are the lexer's token-stream
# tests (`# command: tokens`).
#
# usage: script/parse-examples.sh [path/to/plumlang]
set -euo pipefail

plumlang=${1:-../plumlang}
ts=${TREE_SITTER:-tree-sitter}

invalid() {
  local err="${1%.plum}.err"
  # `# command: tokens` files are token streams for the lexer tests.
  head -n 1 "$1" | grep -q '^# command: tokens' && return 0
  [[ -f "$err" ]] && grep -qE 'E01[0-9]{2}|E020[1-9]|E021[0-46-7]' "$err"
}

total=0 failed=0 skipped=0
failures=()
while IFS= read -r -d '' file; do
  if invalid "$file"; then
    skipped=$((skipped + 1))
    continue
  fi
  total=$((total + 1))
  if ! "$ts" parse --quiet "$file" >/dev/null 2>&1; then
    failed=$((failed + 1))
    failures+=("$file")
  fi
done < <(find "$plumlang/examples" "$plumlang/tests/lang" -name '*.plum' -print0 | sort -z)

for f in "${failures[@]}"; do
  echo "FAIL $f"
done
echo "parsed $((total - failed))/$total valid files cleanly ($skipped intentionally invalid or token-stream files skipped)"
[[ $failed -eq 0 ]]
