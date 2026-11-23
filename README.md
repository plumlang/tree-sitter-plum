# tree-sitter-plum

[Tree-sitter](https://tree-sitter.github.io/) grammar for
[Plumlang](https://plum.elixpo.com), a small language with its own words:
`plant` for variables, `root` for constants, `branch` for functions, `tree`
for classes, `seed` for imports, `drop` to print, `good` / `bad` for booleans.

It gives editors syntax highlighting, code folding, indentation, symbol
outlines (tags) and scope-aware navigation for `.plum` files. The language
itself is documented at **<https://plum.elixpo.com/docs/>**.

```plum
seed math

tree Planet {
    name: str
    radius_km: float

    branch area() -> float => 4.0 * math.PI * self.radius_km ** 2
}

for p in [Planet("Earth", 6371.0)] {
    drop("{p.name}: {p.area():.0} km²")
}
```

## What it covers

The whole language as the reference implementation parses it: comments,
integers in every base, floats, strings with escapes, `{interpolation}` and
`{value:format}`, `"""` multi-line strings, every operator at the reference
parser's precedence, declarations (`plant`, `root`, `branch`, `tree`,
`trait`, `kind`), inheritance and traits, fields with defaults and `weak`,
lambdas, `if` / `match` as statements and expressions, `if plant`
unwrapping, `for` / `while`, `try` / `catch` / `finally` and `try`
expressions, `seed` imports (modules, aliases, name lists, relative paths),
type annotations (optionals, generics, function types, module types),
optional chaining (`?.`, `??`) and `spawn`.

A statement ends at the end of its line. A small external scanner
(`src/scanner.c`) emits a newline token only where a statement can end, so
lines continue inside `(`, `[` and after an operator, as in the reference
lexer, and `else`, `catch` and `finally` may start the line after a `}`.

Every valid `.plum` file in the Plumlang repository's `examples/` and
`tests/lang/` parses without an `ERROR` or `MISSING` node; CI checks this on
every push.

## Editor setup

The queries in `queries/` use the capture names shared by nvim-treesitter,
Zed and the `tree-sitter` CLI: `highlights.scm`, `locals.scm`, `tags.scm`,
`folds.scm`, `indents.scm` and `injections.scm`.

### Neovim

Until Plumlang is in nvim-treesitter, register the parser yourself.

With the nvim-treesitter `main` branch:

```lua
vim.filetype.add({ extension = { plum = 'plum' } })

vim.api.nvim_create_autocmd('User', {
  pattern = 'TSUpdate',
  callback = function()
    require('nvim-treesitter.parsers').plum = {
      install_info = {
        url = 'https://github.com/plumlang/tree-sitter-plum',
        branch = 'main',
        queries = 'queries', -- install the queries from this repository
      },
    }
  end,
})

vim.api.nvim_create_autocmd('FileType', {
  pattern = 'plum',
  callback = function() vim.treesitter.start() end,
})
```

Then run `:TSInstall plum`.

With the older `master` branch:

```lua
vim.filetype.add({ extension = { plum = 'plum' } })

local parsers = require('nvim-treesitter.parsers').get_parser_configs()
parsers.plum = {
  install_info = {
    url = 'https://github.com/plumlang/tree-sitter-plum',
    files = { 'src/parser.c', 'src/scanner.c' },
    branch = 'main',
  },
  filetype = 'plum',
}
```

Run `:TSInstall plum`, and copy this repository's `queries/*.scm` into
`~/.config/nvim/queries/plum/`.

The language server is `plum lsp`; with `nvim-lspconfig` or
`vim.lsp.config`, run it for the `plum` filetype with `plum.toml` as a root
marker.

### Helix

Add the language and the grammar to `~/.config/helix/languages.toml`:

```toml
[[language]]
name = "plum"
scope = "source.plum"
file-types = ["plum"]
roots = ["plum.toml"]
comment-token = "#"
indent = { tab-width = 4, unit = "    " }
language-servers = ["plum"]

[language-server.plum]
command = "plum"
args = ["lsp"]

[[grammar]]
name = "plum"
source = { git = "https://github.com/plumlang/tree-sitter-plum", rev = "main" }
```

Build the grammar and install the queries:

```sh
hx --grammar fetch
hx --grammar build
mkdir -p ~/.config/helix/runtime/queries/plum
cp queries/*.scm ~/.config/helix/runtime/queries/plum/
```

Pin `rev` to a commit hash for a reproducible build. Helix names some
captures differently (`keyword.control.conditional`, `function.method`), and
it gives a node the *first* capture that matches, where these queries are
written for the last. Highlighting works with the files as they are; a copy
tuned for Helix belongs in its runtime once Plumlang is upstreamed there.

### Zed

A Plumlang extension for Zed, built on this grammar and the `plum lsp`
language server, is coming.

### Node.js

The grammar is on npm as
[`@plumlang/tree-sitter-plum`](https://www.npmjs.com/package/@plumlang/tree-sitter-plum),
for [node-tree-sitter](https://github.com/tree-sitter/node-tree-sitter). It
is the source package: installing it compiles the parser with
`node-gyp`, so it needs a C compiler. The queries come with it.

```sh
npm install tree-sitter @plumlang/tree-sitter-plum
```

```js
import Parser from "tree-sitter";
import Plum from "@plumlang/tree-sitter-plum";

const parser = new Parser();
parser.setLanguage(Plum);
const tree = parser.parse('drop("Hello, {name}!")\n');
console.log(tree.rootNode.toString());
// Plum.HIGHLIGHTS_QUERY holds queries/highlights.scm
```

### Other tools

`tree-sitter.json` declares the file type (`plum`), the scope
(`source.plum`) and the injection regex (`^plum$`), so Markdown and other
grammars can inject Plumlang into code blocks tagged `plum`.

## Development

You need Node.js and a C compiler.

```sh
npm install                       # or: npm install -g tree-sitter-cli
npx tree-sitter generate          # grammar.js -> src/parser.c
npx tree-sitter test              # the corpus in test/corpus/
npx tree-sitter parse file.plum   # print a tree
npx tree-sitter highlight file.plum
script/parse-examples.sh ../plumlang   # every example and test file
```

The generated `src/` is committed; regenerate it after changing
`grammar.js`, and CI checks that it matches.

Each GitHub release publishes the npm package
(`.github/workflows/publish.yml`, with provenance): bump the version in
`package.json` and `tree-sitter.json` (and the other manifests), merge, then
create a release tagged `v` and that version. The workflow stops if the tag
and `package.json` disagree.

The grammar follows the reference lexer (`src/lexer/lexer.c`) and Pratt
parser (`src/parser/parser.c`) of
[plumlang/plumlang](https://github.com/plumlang/plumlang). Where the
reference parser reports an error that is about meaning rather than shape
(chained comparisons, an `if` expression without `else`, a `seed` after
other code, a keyword used as a field name), this grammar accepts the code,
so editors keep a useful tree while you type; `plum check` reports those
errors.

## Licence

Code (the grammar, scanner, generated parser, queries, bindings and tests)
is under `MIT WITH Plumlang-trademarks`, and this documentation under
`CC-BY-4.0 WITH Plumlang-trademarks`; see [LICENSE](LICENSE),
[NOTICE](NOTICE) and [LICENSES/](LICENSES/). The package manifests declare
`MIT`. "Plumlang" and the plum marks are reserved; saying your editor
supports Plumlang is welcome.
