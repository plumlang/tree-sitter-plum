#!/usr/bin/env bash
# Parse every .plum file in a Plumlang checkout and report the files whose
# tree has an ERROR or MISSING node.
#
# Skipped: files whose expected diagnostics (.err) hold a lexer or parser
# error (E01xx, E0201-E0214, E0216, E0217), which are invalid on purpose,
# and the lexer's token-stream tests (`# command: tokens`).
#
# The newline token is hidden in the tree, so a newline the parser inserts
# while recovering would not show. The files are parsed with a temporary
# copy of the grammar in which it is visible, so every MISSING node counts.
#
# usage: script/parse-examples.sh [path/to/plumlang]
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
plumlang=$(cd "${1:-$root/../plumlang}" && pwd)
ts=${TREE_SITTER:-tree-sitter}

skip() {
  local err="${1%.plum}.err"
  head -n 1 "$1" | grep -q '^# command: tokens' && return 0
  [[ -f "$err" ]] && grep -qE 'E01[0-9]{2}|E020[1-9]|E021[0-46-7]' "$err"
}

# A copy of the grammar named plum_check, with the newline token visible.
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/src"
cp "$root/grammar.js" "$root/tree-sitter.json" "$work/"
cp "$root/src/scanner.c" "$work/src/"
sed -i.bak -e 's/\$\._newline/$.newline/g' -e "s/name: 'plum'/name: 'plum_check'/" "$work/grammar.js"
sed -i.bak -e 's/"name": "plum"/"name": "plum_check"/' -e 's/"source\.plum"/"source.plum_check"/' \
  -e 's/"plum"$/"plum_check"/' "$work/tree-sitter.json"
sed -i.bak 's/tree_sitter_plum_/tree_sitter_plum_check_/g' "$work/src/scanner.c"
(cd "$work" && "$ts" generate >/dev/null)

total=0 failed=0 skipped=0
while IFS= read -r -d '' file; do
  if skip "$file"; then
    skipped=$((skipped + 1))
    continue
  fi
  total=$((total + 1))
  out=$(cd "$work" && "$ts" parse "$file" 2>&1 || true)
  if grep -qE 'ERROR|MISSING' <<<"$out"; then
    failed=$((failed + 1))
    echo "FAIL ${file#"$plumlang"/}"
    grep -E 'ERROR|MISSING' <<<"$out" | head -n 3 | sed 's/^/  /'
  fi
done < <(find "$plumlang/examples" "$plumlang/tests/lang" -name '*.plum' -print0 | sort -z)

echo "parsed $((total - failed))/$total files cleanly ($skipped invalid or token-stream files skipped)"
[[ $failed -eq 0 ]]
