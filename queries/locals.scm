; Scopes

[
  (source_file)
  (block)
  (function_declaration)
  (method_declaration)
  (lambda)
  (tree_body)
  (for_statement)
  (catch_clause)
  (match_arm)
] @local.scope

; Definitions

(variable_declaration
  name: (identifier) @local.definition.var)

(constant_declaration
  name: (identifier) @local.definition.constant)

(plant_binding
  name: (identifier) @local.definition.var)

(function_declaration
  name: (identifier) @local.definition.function)

(method_declaration
  name: (identifier) @local.definition.method)

(parameter
  name: (identifier) @local.definition.parameter)

(lambda_parameter
  name: (identifier) @local.definition.parameter)

(for_statement
  variable: (identifier) @local.definition.var)

(catch_clause
  name: (identifier) @local.definition.var)

(field_declaration
  name: (identifier) @local.definition.field)

(tree_declaration
  name: (type_identifier) @local.definition.type)

(trait_declaration
  name: (type_identifier) @local.definition.type)

(kind_declaration
  name: (type_identifier) @local.definition.type)

(seed_statement
  path: (module_path
    (identifier) @local.definition.import .))

(seed_statement
  alias: (identifier) @local.definition.import)

(import_list
  (identifier) @local.definition.import)

; References

(identifier) @local.reference

(type_identifier) @local.reference
