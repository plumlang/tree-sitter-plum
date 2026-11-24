; Plumlang highlights.
;
; General patterns come first and more specific ones later: tree-sitter
; highlight and nvim-treesitter give a node the last capture that matches.
; (Helix gives it the first, so its copy lists the sections in reverse.)

; Punctuation

[
  "("
  ")"
  "["
  "]"
  "{"
  "}"
] @punctuation.bracket

[
  ","
  "."
  ":"
] @punctuation.delimiter

; Operators

[
  "+"
  "-"
  "*"
  "/"
  "//"
  "%"
  "**"
  "&"
  "|"
  "^"
  "~"
  "<<"
  ">>"
  "=="
  "!="
  "<"
  "<="
  ">"
  ">="
  "="
  "+="
  "-="
  "*="
  "/="
  "//="
  "%="
  "**="
  "&="
  "|="
  "^="
  "<<="
  ">>="
  "??"
  "?."
  "?"
  ".."
  "..="
  "->"
  "=>"
] @operator

; Keywords

[
  "and"
  "or"
  "not"
  "in"
  "is"
  "as"
] @keyword.operator

[
  "plant"
  "root"
] @keyword

[
  "tree"
  "trait"
  "kind"
] @keyword.type

"branch" @keyword.function

"weak" @keyword.modifier

"seed" @keyword.import

(seed_statement
  "as" @keyword.import)

[
  "if"
  "else"
  "match"
] @keyword.conditional

[
  "for"
  "while"
  (break_statement)
  (continue_statement)
] @keyword.repeat

(for_statement
  "in" @keyword.repeat)

"return" @keyword.return

[
  "try"
  "catch"
  "finally"
  "throw"
] @keyword.exception

"spawn" @keyword.coroutine

; Variables

(identifier) @variable

((identifier) @type
  (#match? @type "^[A-Z]"))

((identifier) @constant
  (#match? @constant "^_*[A-Z][A-Z0-9_]*$"))

(constant_declaration
  name: (identifier) @constant)

(self) @variable.builtin

(super) @variable.builtin

; Fields

(field_declaration
  name: (identifier) @variable.member)

(member_expression
  field: (identifier) @variable.member)

; Parameters

(parameter
  name: (identifier) @variable.parameter)

(lambda_parameter
  name: (identifier) @variable.parameter)

(keyword_argument
  name: (identifier) @variable.parameter)

; Functions

(call_expression
  function: (identifier) @function.call)

((call_expression
  function: (identifier) @constructor)
  (#match? @constructor "^[A-Z]"))

((call_expression
  function: (identifier) @function.builtin)
  (#any-of? @function.builtin
    "drop" "ask" "len" "int" "float" "str" "byte" "type_of" "assert" "exit" "set"))

(call_expression
  function: (member_expression
    field: (identifier) @function.method.call))

(function_declaration
  name: (identifier) @function)

(method_declaration
  name: (identifier) @function.method)

; Types

(type_identifier) @type

((type_identifier) @type.builtin
  (#any-of? @type.builtin
    "int" "float" "bool" "str" "byte" "list" "map" "set" "Channel" "Json"))

(tree_declaration
  name: (type_identifier) @type.definition)

(trait_declaration
  name: (type_identifier) @type.definition)

(kind_declaration
  name: (type_identifier) @type.definition)

(kind_case
  name: (identifier) @constant)

(scoped_type
  module: (identifier) @module)

; Modules

(seed_statement
  path: (module_path
    (identifier) @module))

(seed_statement
  alias: (identifier) @module)

(seed_statement
  path: (relative_path) @string.special.path)

; Literals

(integer) @number

(float) @number.float

(boolean) @boolean

(none) @constant.builtin

(wildcard) @character.special

(string) @string

(escape_sequence) @string.escape

(format_specifier) @string.special

(interpolation
  "{" @punctuation.special
  "}" @punctuation.special)

; Comments

[
  (comment)
  (block_comment)
] @comment @spell

(doc_comment) @comment.documentation @spell
