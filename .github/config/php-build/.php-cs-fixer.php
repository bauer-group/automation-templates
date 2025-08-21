<?php

$finder = PhpCsFixer\Finder::create()
    ->in(__DIR__ . '/src')
    ->in(__DIR__ . '/app')
    ->in(__DIR__ . '/tests')
    ->exclude('vendor')
    ->exclude('storage')
    ->exclude('cache')
    ->exclude('bootstrap/cache')
    ->notPath('*.blade.php')
    ->notName('*.blade.php')
    ->notName('_ide_helper.php')
    ->ignoreDotFiles(true)
    ->ignoreVCS(true);

$config = new PhpCsFixer\Config();

return $config
    ->setRiskyAllowed(true)
    ->setRules([
        '@PSR12' => true,
        '@PHP82Migration' => true,
        '@PhpCsFixer' => true,
        '@PhpCsFixer:risky' => true,
        
        // Arrays
        'array_syntax' => ['syntax' => 'short'],
        'no_multiline_whitespace_around_double_arrow' => true,
        'no_trailing_comma_in_singleline_array' => true,
        'no_whitespace_before_comma_in_array' => true,
        'normalize_index_brace' => true,
        'trailing_comma_in_multiline' => ['elements' => ['arrays', 'arguments', 'parameters']],
        'whitespace_after_comma_in_array' => true,
        
        // Classes
        'class_attributes_separation' => [
            'elements' => [
                'const' => 'one',
                'method' => 'one',
                'property' => 'one',
            ],
        ],
        'no_blank_lines_after_class_opening' => true,
        'no_null_property_initialization' => true,
        'ordered_class_elements' => [
            'order' => [
                'use_trait',
                'constant_public',
                'constant_protected',
                'constant_private',
                'property_public',
                'property_protected',
                'property_private',
                'construct',
                'destruct',
                'magic',
                'phpunit',
                'method_public',
                'method_protected',
                'method_private',
            ],
        ],
        'single_class_element_per_statement' => true,
        'single_trait_insert_per_statement' => true,
        
        // Comments
        'no_empty_comment' => true,
        'no_superfluous_phpdoc_tags' => [
            'allow_mixed' => true,
            'allow_unused_params' => false,
        ],
        'phpdoc_add_missing_param_annotation' => true,
        'phpdoc_align' => [
            'align' => 'vertical',
        ],
        'phpdoc_annotation_without_dot' => true,
        'phpdoc_indent' => true,
        'phpdoc_no_access' => true,
        'phpdoc_no_empty_return' => true,
        'phpdoc_no_package' => true,
        'phpdoc_order' => true,
        'phpdoc_return_self_reference' => true,
        'phpdoc_scalar' => true,
        'phpdoc_separation' => true,
        'phpdoc_single_line_var_spacing' => true,
        'phpdoc_summary' => true,
        'phpdoc_to_comment' => true,
        'phpdoc_trim' => true,
        'phpdoc_types' => true,
        'phpdoc_types_order' => [
            'null_adjustment' => 'always_last',
            'sort_algorithm' => 'none',
        ],
        'phpdoc_var_annotation_correct_order' => true,
        'phpdoc_var_without_name' => true,
        
        // Control structures
        'elseif' => true,
        'include' => true,
        'no_alternative_syntax' => true,
        'no_superfluous_elseif' => true,
        'no_unneeded_control_parentheses' => true,
        'no_unneeded_curly_braces' => true,
        'no_useless_else' => true,
        'switch_case_semicolon_to_colon' => true,
        'switch_case_space' => true,
        
        // Functions
        'function_typehint_space' => true,
        'lambda_not_used_import' => true,
        'no_spaces_after_function_name' => true,
        'no_unreachable_default_argument_value' => true,
        'nullable_type_declaration_for_default_null_value' => true,
        'return_type_declaration' => true,
        'single_line_throw' => false,
        
        // Import
        'fully_qualified_strict_types' => true,
        'global_namespace_import' => [
            'import_classes' => true,
            'import_constants' => true,
            'import_functions' => true,
        ],
        'no_leading_import_slash' => true,
        'no_unused_imports' => true,
        'ordered_imports' => [
            'imports_order' => ['class', 'function', 'const'],
            'sort_algorithm' => 'alpha',
        ],
        'single_import_per_statement' => true,
        'single_line_after_imports' => true,
        
        // Namespaces
        'blank_line_after_namespace' => true,
        'no_blank_lines_before_namespace' => true,
        'no_leading_namespace_whitespace' => true,
        'single_blank_line_before_namespace' => true,
        
        // Operators
        'binary_operator_spaces' => [
            'default' => 'single_space',
        ],
        'concat_space' => ['spacing' => 'one'],
        'increment_style' => ['style' => 'pre'],
        'logical_operators' => true,
        'new_with_braces' => true,
        'not_operator_with_space' => false,
        'not_operator_with_successor_space' => false,
        'object_operator_without_whitespace' => true,
        'standardize_increment' => true,
        'standardize_not_equals' => true,
        'ternary_operator_spaces' => true,
        'ternary_to_null_coalescing' => true,
        'unary_operator_spaces' => true,
        
        // PHP tags
        'blank_line_after_opening_tag' => true,
        'echo_tag_syntax' => ['format' => 'long'],
        'full_opening_tag' => true,
        'linebreak_after_opening_tag' => true,
        'no_closing_tag' => true,
        
        // Strict
        'declare_strict_types' => true,
        'strict_comparison' => true,
        'strict_param' => true,
        
        // Strings
        'explicit_string_variable' => true,
        'heredoc_to_nowdoc' => true,
        'no_binary_string' => true,
        'simple_to_complex_string_variable' => true,
        'single_quote' => true,
        
        // Whitespace
        'array_indentation' => true,
        'blank_line_after_namespace' => true,
        'blank_line_after_opening_tag' => true,
        'blank_line_before_statement' => [
            'statements' => ['break', 'continue', 'declare', 'return', 'throw', 'try'],
        ],
        'compact_nullable_typehint' => true,
        'indentation_type' => true,
        'line_ending' => true,
        'method_chaining_indentation' => true,
        'no_extra_blank_lines' => [
            'tokens' => [
                'case',
                'continue',
                'curly_brace_block',
                'default',
                'extra',
                'parenthesis_brace_block',
                'square_brace_block',
                'switch',
                'throw',
                'use',
            ],
        ],
        'no_spaces_around_offset' => true,
        'no_spaces_inside_parenthesis' => true,
        'no_trailing_whitespace' => true,
        'no_trailing_whitespace_in_comment' => true,
        'no_whitespace_in_blank_line' => true,
        'single_blank_line_at_eof' => true,
        
        // Other
        'combine_consecutive_issets' => true,
        'combine_consecutive_unsets' => true,
        'explicit_indirect_variable' => true,
        'list_syntax' => ['syntax' => 'short'],
        'lowercase_cast' => true,
        'lowercase_static_reference' => true,
        'magic_constant_casing' => true,
        'magic_method_casing' => true,
        'native_function_casing' => true,
        'native_function_type_declaration_casing' => true,
        'no_empty_statement' => true,
        'no_mixed_echo_print' => ['use' => 'echo'],
        'no_short_bool_cast' => true,
        'no_singleline_whitespace_before_semicolons' => true,
        'no_spaces_around_offset' => true,
        'no_unneeded_final_method' => true,
        'no_unset_cast' => true,
        'no_unused_imports' => true,
        'no_useless_return' => true,
        'no_whitespace_before_comma_in_array' => true,
        'normalize_index_brace' => true,
        'php_unit_construct' => true,
        'php_unit_dedicate_assert' => true,
        'php_unit_dedicate_assert_internal_type' => true,
        'php_unit_expectation' => true,
        'php_unit_fqcn_annotation' => true,
        'php_unit_internal_class' => true,
        'php_unit_method_casing' => true,
        'php_unit_mock' => true,
        'php_unit_mock_short_will_return' => true,
        'php_unit_namespaced' => true,
        'php_unit_no_expectation_annotation' => true,
        'php_unit_set_up_tear_down_visibility' => true,
        'php_unit_strict' => true,
        'php_unit_test_annotation' => true,
        'php_unit_test_case_static_method_calls' => ['call_type' => 'self'],
        'php_unit_test_class_requires_covers' => false,
        'protected_to_private' => true,
        'self_accessor' => true,
        'semicolon_after_instruction' => true,
        'short_scalar_cast' => true,
        'simplified_null_return' => true,
        'single_blank_line_at_eof' => true,
        'single_line_comment_style' => ['comment_types' => ['hash']],
        'ternary_operator_spaces' => true,
        'visibility_required' => true,
        'void_return' => true,
        'yoda_style' => false,
    ])
    ->setFinder($finder)
    ->setCacheFile(__DIR__ . '/.php-cs-fixer.cache');