(function_declaration
  name: (identifier) @name) @definition.function

(method_declaration
  name: (identifier) @name) @definition.method

(tree_declaration
  name: (type_identifier) @name) @definition.class

(trait_declaration
  name: (type_identifier) @name) @definition.interface

(kind_declaration
  name: (type_identifier) @name) @definition.type

(constant_declaration
  name: (identifier) @name) @definition.constant

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
