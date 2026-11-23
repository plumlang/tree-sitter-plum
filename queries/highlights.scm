; Plumlang highlights. More specific patterns come first: tree-sitter
; highlight, Helix and Zed give a node the first capture that matches.

; Comments

(comment) @comment @spell

; Literals

(string) @string

(escape_sequence) @string.escape

(format_specifier) @string.special

(interpolation
  "{" @punctuation.special
  "}" @punctuation.special) @none

(integer) @number

(float) @number.float

(boolean) @boolean

(none) @constant.builtin

(wildcard) @character.special

; Modules

(seed_statement
  path: (module_path
    (identifier) @module))

(seed_statement
  path: (relative_path) @string.special.path)

(seed_statement
  alias: (identifier) @module)

(import_list
  (identifier) @variable)

; Types

(scoped_type
  module: (identifier) @module)

((type_identifier) @type.builtin
  (#any-of? @type.builtin
    "int" "float" "bool" "str" "byte" "list" "map" "set" "Channel" "Json"))

(tree_declaration
  name: (type_identifier) @type.definition)

(trait_declaration
  name: (type_identifier) @type.definition)

(kind_declaration
  name: (type_identifier) @type.definition)

(type_identifier) @type

(kind_case
  name: (identifier) @constant)

; Functions

(function_declaration
  name: (identifier) @function)

(method_declaration
  name: (identifier) @function.method)

(call_expression
  function: (member_expression
    field: (identifier) @function.method.call))

((call_expression
  function: (identifier) @function.builtin)
  (#any-of? @function.builtin
    "drop" "ask" "len" "int" "float" "str" "byte" "type_of" "assert" "exit" "set"))

((call_expression
  function: (identifier) @constructor)
  (#match? @constructor "^[A-Z]"))

(call_expression
  function: (identifier) @function.call)

; Parameters

(parameter
  name: (identifier) @variable.parameter)

(lambda_parameter
  name: (identifier) @variable.parameter)

(keyword_argument
  name: (identifier) @variable.parameter)

(catch_clause
  name: (identifier) @variable)

; Fields

(field_declaration
  name: (identifier) @variable.member)

(member_expression
  field: (identifier) @variable.member)

; Variables

(self) @variable.builtin

(super) @variable.builtin

(constant_declaration
  name: (identifier) @constant)

((identifier) @constant
  (#match? @constant "^_*[A-Z][A-Z0-9_]*$"))

((identifier) @type
  (#match? @type "^[A-Z]"))

(identifier) @variable

; Keywords

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

(match_arm
  "else" @keyword.conditional)

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

[
  "and"
  "or"
  "not"
  "in"
  "is"
  "as"
] @keyword.operator

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

[
  "\""
  "\"\"\""
] @string
