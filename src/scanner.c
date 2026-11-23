/*
 * External scanner for Plumlang.
 *
 * NEWLINE: a statement ends at the end of its line. The scanner emits a
 * newline token only where the grammar can end a statement, so a newline
 * inside `(`, `[`, an interpolation, or after an operator is skipped as
 * whitespace, as the reference lexer does (plumlang src/lexer/lexer.c).
 * Blank lines and comment lines after it are left to the extras. When the
 * next word after the line break is `else`, `catch` or `finally`, no newline
 * is emitted, so those may start the line after a `}` (parser.c match_else).
 *
 * STRING_CONTENT / TRIPLE_STRING_CONTENT: text in "..." and """...""" up to
 * a quote, a backslash escape, or a `{` interpolation.
 */

#include "tree_sitter/parser.h"

#include <stdbool.h>
#include <string.h>

enum TokenType {
    NEWLINE,
    STRING_CONTENT,
    TRIPLE_STRING_CONTENT,
    ERROR_SENTINEL,
};

void *tree_sitter_plum_external_scanner_create(void) {
    return NULL;
}

void tree_sitter_plum_external_scanner_destroy(void *payload) {
    (void)payload;
}

unsigned tree_sitter_plum_external_scanner_serialize(void *payload, char *buffer) {
    (void)payload;
    (void)buffer;
    return 0;
}

void tree_sitter_plum_external_scanner_deserialize(void *payload, const char *buffer,
                                                   unsigned length) {
    (void)payload;
    (void)buffer;
    (void)length;
}

static inline void advance(TSLexer *lexer) {
    lexer->advance(lexer, false);
}

static inline void skip(TSLexer *lexer) {
    lexer->advance(lexer, true);
}

static inline bool is_word_char(int32_t c) {
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') ||
           c == '_';
}

/* Is the next word one that continues the statement before the newline? */
static bool at_continuation_word(TSLexer *lexer) {
    static const char *const words[] = {"else", "catch", "finally"};
    char word[8];
    unsigned len = 0;
    while (is_word_char(lexer->lookahead) && len < sizeof word - 1) {
        word[len++] = (char)lexer->lookahead;
        advance(lexer);
    }
    word[len] = '\0';
    if (is_word_char(lexer->lookahead) || len == 0) {
        return false;
    }
    for (size_t i = 0; i < sizeof words / sizeof words[0]; i++) {
        if (strcmp(word, words[i]) == 0) {
            return true;
        }
    }
    return false;
}

static bool scan_newline(TSLexer *lexer) {
    while (lexer->lookahead == ' ' || lexer->lookahead == '\t' || lexer->lookahead == '\r') {
        skip(lexer);
    }
    if (lexer->lookahead != '\n') {
        /* Another token on this line, a comment (scanned as an extra first;
         * the newline after it comes back here), `}` or the end of file. */
        return false;
    }
    advance(lexer);
    lexer->mark_end(lexer);
    lexer->result_symbol = NEWLINE;

    /* Look past blank lines and comment lines for `else`, `catch`, `finally`. */
    for (;;) {
        int32_t c = lexer->lookahead;
        if (c == ' ' || c == '\t' || c == '\r' || c == '\n') {
            advance(lexer);
        } else if (c == '#') {
            while (lexer->lookahead != '\n' && !lexer->eof(lexer)) {
                advance(lexer);
            }
        } else {
            break;
        }
        if (lexer->eof(lexer)) {
            return true;
        }
    }
    return !at_continuation_word(lexer);
}

static bool scan_string_content(TSLexer *lexer, bool triple) {
    bool has_content = false;
    for (;;) {
        if (lexer->eof(lexer)) {
            break;
        }
        int32_t c = lexer->lookahead;
        if (c == '\\' || c == '{' || c == '}') {
            break;
        }
        if (c == '"') {
            if (!triple) {
                break;
            }
            /* In a """ string, only """ ends it. */
            lexer->mark_end(lexer);
            advance(lexer);
            if (lexer->lookahead == '"') {
                advance(lexer);
                if (lexer->lookahead == '"') {
                    lexer->result_symbol = TRIPLE_STRING_CONTENT;
                    return has_content;
                }
            }
            has_content = true;
            continue;
        }
        if (c == '\n' && !triple) {
            break; /* an unclosed string */
        }
        advance(lexer);
        has_content = true;
    }
    lexer->mark_end(lexer);
    lexer->result_symbol = triple ? TRIPLE_STRING_CONTENT : STRING_CONTENT;
    return has_content;
}

bool tree_sitter_plum_external_scanner_scan(void *payload, TSLexer *lexer,
                                            const bool *valid_symbols) {
    (void)payload;
    if (valid_symbols[ERROR_SENTINEL]) {
        return false; /* error recovery: let the internal lexer decide */
    }
    if (valid_symbols[STRING_CONTENT]) {
        return scan_string_content(lexer, false);
    }
    if (valid_symbols[TRIPLE_STRING_CONTENT]) {
        return scan_string_content(lexer, true);
    }
    if (valid_symbols[NEWLINE]) {
        return scan_newline(lexer);
    }
    return false;
}
