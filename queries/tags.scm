; A declaration's doc comment, its `##` lines, is its @doc.

(
  (doc_comment)* @doc
  .
  (function_declaration
    name: (identifier) @name) @definition.function
  (#strip! @doc "^##[ ]?")
  (#select-adjacent! @doc @definition.function)
)

(
  (doc_comment)* @doc
  .
  (method_declaration
    name: (identifier) @name) @definition.method
  (#strip! @doc "^##[ ]?")
  (#select-adjacent! @doc @definition.method)
)

(
  (doc_comment)* @doc
  .
  (tree_declaration
    name: (type_identifier) @name) @definition.class
  (#strip! @doc "^##[ ]?")
  (#select-adjacent! @doc @definition.class)
)

(
  (doc_comment)* @doc
  .
  (trait_declaration
    name: (type_identifier) @name) @definition.interface
  (#strip! @doc "^##[ ]?")
  (#select-adjacent! @doc @definition.interface)
)

(
  (doc_comment)* @doc
  .
  (kind_declaration
    name: (type_identifier) @name) @definition.type
  (#strip! @doc "^##[ ]?")
  (#select-adjacent! @doc @definition.type)
)

(
  (doc_comment)* @doc
  .
  (constant_declaration
    name: (identifier) @name) @definition.constant
  (#strip! @doc "^##[ ]?")
  (#select-adjacent! @doc @definition.constant)
)

(seed_statement
  path: (_) @name) @reference.module

(call_expression
  function: [
    (identifier) @name
    (member_expression
      field: (identifier) @name)
  ]) @reference.call

(supertypes
  [
    (type_identifier) @name
    (generic_type
      name: (type_identifier) @name)
  ]) @reference.implementation
