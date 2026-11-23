package tree_sitter_plum_test

import (
	"testing"

	tree_sitter "github.com/tree-sitter/go-tree-sitter"
	tree_sitter_plum "github.com/plumlang/tree-sitter-plum/bindings/go"
)

func TestCanLoadGrammar(t *testing.T) {
	language := tree_sitter.NewLanguage(tree_sitter_plum.Language())
	if language == nil {
		t.Errorf("Error loading Plumlang grammar")
	}
}
