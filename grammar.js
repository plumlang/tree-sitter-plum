/**
 * @file Tree-sitter grammar for Plumlang
 * @author Elixpo and the Plumlang contributors <hello@elixpo.com>
 * @license MIT
 *
 * Mirrors the reference implementation in plumlang/plumlang: the lexer
 * (src/lexer/lexer.c) and the Pratt parser (src/parser/parser.c).
 *
 * Newlines end statements. The reference lexer drops a newline inside an
 * open `(`, `[` or string interpolation, and after a token that cannot end
 * a statement (a binary operator, `,`, `.`, `{`, `->`, `=>`, ...). Here the
 * external scanner (src/scanner.c) emits a `_newline` token only where the
 * grammar can end a statement, which gives the same result: inside brackets
 * and after an operator a newline is never valid, so it is skipped as
 * whitespace. `else`, `catch` and `finally` may start the line after a `}`,
 * so the scanner does not end the statement before them.
 */

/// <reference types="tree-sitter-cli/dsl" />
// @ts-check

// Binding powers, lowest first (spec 4.8, parser.c PREC_*).
const PREC = {
  lambda: -1,
  coalesce: 1, // ??
  or: 2, // or (and the operand of a `try` expression)
  and: 3, // and
  not: 4, // not (prefix)
  compare: 5, // == != < <= > >= is in
  range: 6, // .. ..=
  bit_or: 7, // |
  bit_xor: 8, // ^
  bit_and: 9, // &
  shift: 10, // << >>
  term: 11, // + -
  factor: 12, // * / // %
  unary: 13, // - ~ (prefix)
  power: 14, // ** (right to left)
  as: 15, // as
  postfix: 16, // calls, indexing, fields
};

const IDENT = /[A-Za-z_][A-Za-z0-9_]*/;

/**
 * Items separated by commas, with an optional trailing comma.
 * @param {RuleOrLiteral} rule
 */
function commaSep(rule) {
  return optional(commaSep1(rule));
}

/**
 * @param {RuleOrLiteral} rule
 */
function commaSep1(rule) {
  return seq(rule, repeat(seq(',', rule)), optional(','));
}

/**
 * A body of items, each ending at a newline (the last may end at the `}`).
 * @param {GrammarSymbols<string>} $
 * @param {RuleOrLiteral} item
 */
function lines($, item) {
  return seq(repeat(seq(item, $._newline)), optional(item));
}

export default grammar({
  name: 'plum',

  externals: $ => [
    $._newline,
    $._string_content,
    $._triple_string_content,
    $._error_sentinel,
  ],

  extras: $ => [$.comment, /\s/],

  word: $ => $.identifier,

  supertypes: $ => [$._statement, $._expression, $._type],

  inline: $ => [$._member, $._primary_expression],

  conflicts: $ => [
    // `(x)` may be a parenthesized name or the parameters of `(x) => ...`.
    [$._expression, $.lambda_parameter],
  ],

  rules: {
    source_file: $ => lines($, $._statement),

    // ------------------------------------------------------------------
    // Statements
    // ------------------------------------------------------------------

    _statement: $ => choice(
      $.seed_statement,
      $.variable_declaration,
      $.constant_declaration,
      $.function_declaration,
      $.tree_declaration,
      $.trait_declaration,
      $.kind_declaration,
      $.for_statement,
      $.while_statement,
      $.try_statement,
      $.return_statement,
      $.throw_statement,
      $.break_statement,
      $.continue_statement,
      $.assignment_statement,
      $.expression_statement,
    ),

    block: $ => seq('{', lines($, $._statement), '}'),

    expression_statement: $ => $._expression,

    assignment_statement: $ => seq(
      field('left', $._expression),
      field('operator', choice(
        '=', '+=', '-=', '*=', '/=', '//=', '%=', '**=',
        '&=', '|=', '^=', '<<=', '>>=',
      )),
      field('right', $._expression),
    ),

    // seed math | seed net.http as web | seed math { sqrt, PI } | seed ./models/user
    seed_statement: $ => seq(
      'seed',
      field('path', choice($.module_path, $.relative_path)),
      optional(seq('as', field('alias', $.identifier))),
      optional(field('names', $.import_list)),
    ),

    module_path: $ => seq($.identifier, repeat(seq('.', $.identifier))),

    // `./a/b` and `../lib/x`; a segment may be spelled like a keyword.
    relative_path: _ => token(seq(
      repeat1(choice('./', '../')),
      IDENT,
      repeat(seq('/', IDENT)),
    )),

    import_list: $ => seq('{', commaSep1($.identifier), '}'),

    variable_declaration: $ => seq(
      'plant',
      field('name', $.identifier),
      optional(seq(':', field('type', $._type))),
      '=',
      field('value', $._expression),
    ),

    constant_declaration: $ => seq(
      'root',
      field('name', $.identifier),
      optional(seq(':', field('type', $._type))),
      '=',
      field('value', $._expression),
    ),

    // branch name(params) -> Result { body } | => expression | (no body, in a trait)
    function_declaration: $ => seq(
      'branch',
      field('name', $.identifier),
      field('parameters', $.parameters),
      optional(seq('->', field('return_type', $._type))),
      optional(choice(
        field('body', $.block),
        seq('=>', field('body', $._expression)),
      )),
    ),

    parameters: $ => seq('(', commaSep($.parameter), ')'),

    parameter: $ => seq(
      field('name', $.identifier),
      ':',
      field('type', $._type),
      optional(seq('=', field('default', $._expression))),
    ),

    // tree Name : Parent, Trait { fields and methods }
    tree_declaration: $ => seq(
      'tree',
      field('name', alias($.identifier, $.type_identifier)),
      optional(field('supertypes', $.supertypes)),
      field('body', $.tree_body),
    ),

    trait_declaration: $ => seq(
      'trait',
      field('name', alias($.identifier, $.type_identifier)),
      optional(field('supertypes', $.supertypes)),
      field('body', $.tree_body),
    ),

    supertypes: $ => seq(':', $._type, repeat(seq(',', $._type))),

    tree_body: $ => seq('{', lines($, $._member), '}'),

    _member: $ => choice(
      $.field_declaration,
      alias($.function_declaration, $.method_declaration),
    ),

    field_declaration: $ => seq(
      field('name', $.identifier),
      ':',
      optional('weak'),
      field('type', $._type),
      optional(seq('=', field('default', $._expression))),
    ),

    // kind Name { Case, Case(name: type) } -- cases split by ',' or newlines
    kind_declaration: $ => seq(
      'kind',
      field('name', alias($.identifier, $.type_identifier)),
      field('body', $.kind_body),
    ),

    kind_body: $ => seq(
      '{',
      optional(seq(
        $.kind_case,
        repeat(seq(choice(',', $._newline), $.kind_case)),
        optional(choice(',', $._newline)),
      )),
      '}',
    ),

    kind_case: $ => seq(
      field('name', $.identifier),
      optional(field('parameters', $.parameters)),
    ),

    for_statement: $ => seq(
      'for',
      field('variable', choice($.identifier, $.wildcard)),
      optional(seq(',', field('variable', choice($.identifier, $.wildcard)))),
      'in',
      field('iterable', $._expression),
      field('body', $.block),
    ),

    while_statement: $ => seq(
      'while',
      field('condition', $._expression),
      field('body', $.block),
    ),

    try_statement: $ => seq(
      'try',
      field('body', $.block),
      repeat($.catch_clause),
      optional($.finally_clause),
    ),

    catch_clause: $ => seq(
      'catch',
      field('name', $.identifier),
      optional(seq(':', field('type', $._type))),
      field('body', $.block),
    ),

    finally_clause: $ => seq('finally', field('body', $.block)),

    return_statement: $ => prec.right(seq('return', optional($._expression))),

    throw_statement: $ => seq('throw', $._expression),

    break_statement: _ => 'break',

    continue_statement: _ => 'continue',

    // ------------------------------------------------------------------
    // Expressions
    // ------------------------------------------------------------------

    _expression: $ => choice(
      $._primary_expression,
      $.unary_expression,
      $.binary_expression,
      $.range_expression,
      $.cast_expression,
      $.type_test_expression,
      $.try_expression,
      $.spawn_expression,
      $.lambda,
    ),

    _primary_expression: $ => choice(
      $.identifier,
      $.self,
      $.super,
      $.integer,
      $.float,
      $.string,
      $.boolean,
      $.none,
      $.wildcard,
      $.list,
      $.map,
      $.parenthesized_expression,
      $.call_expression,
      $.index_expression,
      $.member_expression,
      $.if_expression,
      $.match_expression,
    ),

    parenthesized_expression: $ => seq('(', $._expression, ')'),

    unary_expression: $ => choice(
      prec(PREC.unary, seq(field('operator', choice('-', '~')), field('operand', $._expression))),
      prec(PREC.not, seq(field('operator', 'not'), field('operand', $._expression))),
    ),

    binary_expression: $ => {
      /** @type {[number, RuleOrLiteral][]} */
      const table = [
        [PREC.coalesce, '??'],
        [PREC.or, 'or'],
        [PREC.and, 'and'],
        [PREC.compare, choice('==', '!=', '<', '<=', '>', '>=', 'in')],
        [PREC.bit_or, '|'],
        [PREC.bit_xor, '^'],
        [PREC.bit_and, '&'],
        [PREC.shift, choice('<<', '>>')],
        [PREC.term, choice('+', '-')],
        [PREC.factor, choice('*', '/', '//', '%')],
      ];
      return choice(
        ...table.map(([p, op]) => prec.left(p, seq(
          field('left', $._expression),
          field('operator', op),
          field('right', $._expression),
        ))),
        prec.right(PREC.power, seq(
          field('left', $._expression),
          field('operator', '**'),
          field('right', $._expression),
        )),
      );
    },

    range_expression: $ => prec.left(PREC.range, seq(
      field('start', $._expression),
      field('operator', choice('..', '..=')),
      field('end', $._expression),
    )),

    cast_expression: $ => prec.left(PREC.as, seq(
      field('value', $._expression),
      'as',
      field('type', $._type),
    )),

    type_test_expression: $ => prec.left(PREC.compare, seq(
      field('value', $._expression),
      'is',
      field('type', $._type),
    )),

    // `try int(s) ?? 0` is `(try int(s)) ?? 0`.
    try_expression: $ => prec.right(PREC.or, seq('try', $._expression)),

    spawn_expression: $ => prec.right(PREC.postfix, seq('spawn', $._expression)),

    call_expression: $ => prec(PREC.postfix, seq(
      field('function', $._expression),
      field('arguments', $.arguments),
    )),

    arguments: $ => seq('(', commaSep(choice($._expression, $.keyword_argument)), ')'),

    keyword_argument: $ => seq(
      field('name', $.identifier),
      ':',
      field('value', $._expression),
    ),

    index_expression: $ => prec(PREC.postfix, seq(
      field('object', $._expression),
      '[',
      field('index', $._expression),
      ']',
    )),

    member_expression: $ => prec(PREC.postfix, seq(
      field('object', $._expression),
      field('operator', choice('.', '?.')),
      field('field', $.identifier),
    )),

    lambda: $ => prec.right(PREC.lambda, seq(
      field('parameters', $.lambda_parameters),
      '=>',
      field('body', choice($.block, $._expression)),
    )),

    lambda_parameters: $ => seq('(', commaSep($.lambda_parameter), ')'),

    lambda_parameter: $ => seq(
      field('name', $.identifier),
      optional(seq(':', field('type', $._type))),
    ),

    // At the start of a statement this is the if statement; elsewhere it is
    // an if expression, which needs an `else`.
    if_expression: $ => prec.right(seq(
      'if',
      field('condition', choice($._expression, $.plant_binding)),
      field('consequence', $.block),
      optional(seq(
        'else',
        field('alternative', choice($.block, $.if_expression)),
      )),
    )),

    // if plant name = optional { ... }
    plant_binding: $ => seq(
      'plant',
      field('name', $.identifier),
      '=',
      field('value', $._expression),
    ),

    match_expression: $ => seq(
      'match',
      field('value', $._expression),
      field('body', $.match_block),
    ),

    match_block: $ => seq(
      '{',
      repeat(seq($.match_arm, $._newline)),
      optional($.match_arm),
      // `else` may follow the last arm without a newline token: the scanner
      // never ends a line before `else`.
      optional(seq(alias($.else_arm, $.match_arm), optional($._newline))),
      '}',
    ),

    match_arm: $ => seq(
      field('pattern', $._expression),
      repeat(seq(',', field('pattern', $._expression))),
      '=>',
      field('body', choice($.block, $._statement)),
    ),

    else_arm: $ => seq(
      'else',
      '=>',
      field('body', choice($.block, $._statement)),
    ),

    list: $ => seq('[', commaSep($._expression), ']'),

    map: $ => seq(
      '{',
      choice(
        ':',
        seq($.pair, repeat(seq(optional($._newline), ',', $.pair))),
      ),
      // A newline after a ',' is never a token, so the trailing ',' is last.
      optional($._newline),
      optional(','),
      '}',
    ),

    pair: $ => seq(field('key', $._expression), ':', field('value', $._expression)),

    // ------------------------------------------------------------------
    // Types
    // ------------------------------------------------------------------

    _type: $ => choice(
      alias($.identifier, $.type_identifier),
      $.scoped_type,
      $.generic_type,
      $.optional_type,
      $.function_type,
      alias('none', $.none),
    ),

    // shapes.Circle: a type from an imported module
    scoped_type: $ => prec(PREC.postfix + 1, seq(
      field('module', $.identifier),
      '.',
      field('name', alias($.identifier, $.type_identifier)),
    )),

    generic_type: $ => prec(PREC.postfix + 1, seq(
      field('name', choice(alias($.identifier, $.type_identifier), $.scoped_type)),
      field('arguments', $.type_arguments),
    )),

    type_arguments: $ => seq('[', commaSep($._type), ']'),

    optional_type: $ => prec(PREC.postfix + 1, seq(
      choice(alias($.identifier, $.type_identifier), $.scoped_type, $.generic_type, alias('none', $.none)),
      '?',
    )),

    function_type: $ => prec.right(seq(
      field('parameters', $.parameter_types),
      '->',
      field('return_type', $._type),
    )),

    parameter_types: $ => seq('(', commaSep($._type), ')'),

    // ------------------------------------------------------------------
    // Literals and names
    // ------------------------------------------------------------------

    identifier: _ => IDENT,

    self: _ => 'self',

    super: _ => 'super',

    wildcard: _ => '_',

    boolean: _ => choice('good', 'bad', 'true', 'false'),

    none: _ => 'none',

    // 42, 1_000_000, 0xFF, 0o755, 0b1010_0101
    integer: _ => token(choice(
      /0[xX][0-9a-fA-F_]+/,
      /0[oO][0-7_]+/,
      /0[bB][01_]+/,
      /[0-9][0-9_]*/,
    )),

    // 3.14, 1e9, 6.022e23, 2.5e-3 -- digits on both sides of the point
    float: _ => token(choice(
      /[0-9][0-9_]*\.[0-9][0-9_]*([eE][+-]?[0-9_]+)?/,
      /[0-9][0-9_]*[eE][+-]?[0-9_]+/,
    )),

    string: $ => choice(
      seq(
        '"',
        repeat(choice(
          alias($._string_content, $.string_content),
          $.escape_sequence,
          $.interpolation,
        )),
        '"',
      ),
      seq(
        '"""',
        repeat(choice(
          alias($._triple_string_content, $.string_content),
          $.escape_sequence,
          $.interpolation,
        )),
        '"""',
      ),
    ),

    escape_sequence: _ => token.immediate(seq(
      '\\',
      choice(/[ntr0\\"{}]/, /u\{[0-9a-fA-F]{1,6}\}/),
    )),

    // "{x}", "{price:.2}", "{name:>6}"
    interpolation: $ => seq(
      '{',
      field('expression', $._expression),
      optional(field('format', $.format_specifier)),
      '}',
    ),

    format_specifier: _ => token(seq(':', /[^}"\n]+/)),

    comment: _ => token(seq('#', /[^\n]*/)),
  },
});
