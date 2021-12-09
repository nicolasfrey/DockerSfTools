<?php
declare(strict_types=1);

/**
 * https://github.com/FriendsOfPHP/PHP-CS-Fixer
 * Sample: https://mlocati.github.io/php-cs-fixer-configurator/#version:2.16
 */
$finder = PhpCsFixer\Finder::create()
    ->in(__DIR__)
    ->exclude('var')
;

$config = new PhpCsFixer\Config();
$config
    ->setRules([
        '@PSR2' => true,
        '@PhpCsFixer' => true,
        '@PhpCsFixer:risky' => true,
        '@PHP70Migration' => true,
        '@PHP71Migration' => true,
        '@PHP71Migration:risky' => true,
        '@PHP73Migration' => true,
        '@Symfony' => true,
        '@Symfony:risky' => false,

        'native_function_invocation' => false,
        'strict_comparison' => false,
        'backtick_to_shell_exec' => true,
        'method_chaining_indentation' => false,
        'single_import_per_statement' => false,
        //'braces' => [ 'allow_single_line_closure' => true, 'position_after_control_structures' => 'next', 'position_after_functions_and_oop_constructs' => 'same' ],
        'concat_space' => [ 'spacing' => 'one'],
        'array_syntax' => ['syntax' => 'short'],

        'blank_line_after_opening_tag' => false,
        'linebreak_after_opening_tag' => false,
        //'no_blank_lines_after_class_opening' => true,

    ])
    ->setRiskyAllowed(true)
    ->setFinder($finder)
;

return $config;