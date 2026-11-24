#!/usr/bin/env bash
# Check the grammar against Plumlang's shared highlighting sample
# (plumlang's tests/highlight/): its keyword list and sample.plum.
#
#   1. every keyword the lexer has is a token in the grammar (src/grammar.json);
#   2. sample.plum parses without an ERROR or MISSING node;
#   3. every keyword in the sample gets a capture from queries/highlights.scm
#      (@keyword.*, @boolean, @constant.builtin or @variable.builtin).
#
# usage: script/check-sample.sh [dir]
#   dir holds keywords.txt and sample.plum (e.g. ../plumlang/tests/highlight);
#   without it they are downloaded from plumlang's main branch.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
ts=${TREE_SITTER:-tree-sitter}
base=https://raw.githubusercontent.com/plumlang/plumlang/main/tests/highlight
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

if [[ $# -gt 0 ]]; then
  dir=$(cd "$1" && pwd)
else
  dir=$work
  curl -fsSL "$base/keywords.txt" -o "$dir/keywords.txt"
  curl -fsSL "$base/sample.plum" -o "$dir/sample.plum"
fi
sample=$dir/sample.plum
status=0

# 1. Every keyword is a string token somewhere in the grammar.
node -e '
  const fs = require("fs");
  const [grammar, list] = process.argv.slice(1);
  const strings = new Set();
  (function walk(n) {
    if (Array.isArray(n)) return n.forEach(walk);
    if (n && typeof n === "object") {
      if (n.type === "STRING") strings.add(n.value);
      Object.values(n).forEach(walk);
    }
  })(JSON.parse(fs.readFileSync(grammar, "utf8")));
  const words = fs.readFileSync(list, "utf8").split("\n").filter(Boolean);
  const missing = words.filter((w) => !strings.has(w));
  if (missing.length) {
    console.log("grammar.js does not know these keywords: " + missing.join(" "));
    process.exit(1);
  }
  console.log(`keywords: all ${words.length} are in the grammar`);
' "$root/src/grammar.json" "$dir/keywords.txt" || status=1

# 2. The sample parses cleanly.
out=$(cd "$root" && "$ts" parse "$sample" 2>&1 || true)
if grep -qE 'ERROR|MISSING' <<<"$out"; then
  echo "sample.plum has ERROR or MISSING nodes:"
  grep -E 'ERROR|MISSING' <<<"$out" | head -n 10 | sed 's/^/  /'
  status=1
else
  echo "sample.plum parses without errors"
fi

# 3. Each keyword is captured as a keyword (or boolean, none, self, super).
(cd "$root" && "$ts" query queries/highlights.scm "$sample") >"$work/captures"
while read -r word; do
  if ! grep -qE "capture: [0-9]+ - (keyword[a-z.]*|boolean|constant\.builtin|variable\.builtin), .*text: \`$word\`$" \
    "$work/captures"; then
    echo "queries/highlights.scm does not highlight the keyword '$word' in sample.plum"
    status=1
  fi
done <"$dir/keywords.txt"
[[ $status -eq 0 ]] && echo "highlights: every keyword in sample.plum is captured"
exit "$status"
