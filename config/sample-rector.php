<?php

declare(strict_types=1);

use Rector\CodeQuality\Rector\Empty_\SimplifyEmptyCheckOnEmptyArrayRector;
use Rector\CodeQuality\Rector\Identical\FlipTypeControlToUseExclusiveTypeRector;
use Rector\CodeQuality\Rector\If_\ExplicitBoolCompareRector;
use Rector\CodingStyle\Rector\ClassMethod\FuncGetArgsToVariadicParamRector;
use Rector\CodingStyle\Rector\ClassMethod\NewlineBeforeNewAssignSetRector;
use Rector\CodingStyle\Rector\FuncCall\CountArrayToEmptyArrayComparisonRector;
use Rector\CodingStyle\Rector\Stmt\NewlineAfterStatementRector;
use Rector\CodingStyle\Rector\String_\SymplifyQuoteEscapeRector;
use Rector\Config\RectorConfig;
use Rector\Core\Configuration\Option;
use Rector\Core\ValueObject\PhpVersion;
use Rector\DeadCode\Rector\Foreach_\RemoveUnusedForeachKeyRector;
use Rector\DeadCode\Rector\StaticCall\RemoveParentCallWithoutParentRector;
use Rector\Php71\Rector\FuncCall\CountOnNullRector;
use Rector\Php74\Rector\LNumber\AddLiteralSeparatorToNumberRector;
use Rector\Php80\Rector\Class_\StringableForToStringRector;
use Rector\Php80\Rector\FunctionLike\MixedTypeRector;
use Rector\Php81\Rector\ClassConst\FinalizePublicClassConstantRector;
use Rector\Php81\Rector\Property\ReadOnlyPropertyRector;
use Rector\Set\ValueObject\LevelSetList;
use Rector\Set\ValueObject\SetList;
use Rector\Strict\Rector\Empty_\DisallowedEmptyRuleFixerRector;
use Rector\Symfony\Set\SymfonySetList;

return static function (RectorConfig $rectorConfig): void {
    $rectorConfig->paths([
        __DIR__ . '/config',
        __DIR__ . '/public',
        __DIR__ . '/src',
        __DIR__ . '/tests',
    ]);

    $parameters = $rectorConfig->parameters();
    $parameters->set(Option::PHP_VERSION_FEATURES, PhpVersion::PHP_82);

    // register a single rule
    $rectorConfig->rules([
        NewlineBeforeNewAssignSetRector::class,
        RemoveParentCallWithoutParentRector::class,
        RemoveUnusedForeachKeyRector::class,
        SymplifyQuoteEscapeRector::class,
        NewlineAfterStatementRector::class,
    ]);

    // define sets of rules
    $rectorConfig->sets([
        SetList::PHP_82,
        SetList::CODE_QUALITY,
        //        SetList::CODING_STYLE,
        //        SetList::NAMING,
        SetList::TYPE_DECLARATION,
        LevelSetList::UP_TO_PHP_82,
        SymfonySetList::SYMFONY_63,
        SymfonySetList::SYMFONY_CODE_QUALITY,
        SymfonySetList::SYMFONY_CONSTRUCTOR_INJECTION,
        SymfonySetList::ANNOTATIONS_TO_ATTRIBUTES,
        SymfonySetList::CONFIGS,
    ]);

    $parameters->set(Option::SKIP, [
        __DIR__ . '/sys/Kernel.php',
        __DIR__ . '/public/index.php',
        __DIR__ . '/config/bootstrap.php',
        FuncGetArgsToVariadicParamRector::class,
        DisallowedEmptyRuleFixerRector::class,
        CountArrayToEmptyArrayComparisonRector::class,
        FlipTypeControlToUseExclusiveTypeRector::class,
        SimplifyEmptyCheckOnEmptyArrayRector::class,
        ExplicitBoolCompareRector::class,
        StringableForToStringRector::class,
        AddLiteralSeparatorToNumberRector::class,
        CountOnNullRector::class,
        MixedTypeRector::class,
        FinalizePublicClassConstantRector::class,
        ReadOnlyPropertyRector::class,
    ]);
};
