<?php

declare(strict_types=1);

use Rector\CodeQuality\Rector\Class_\InlineConstructorDefaultToPropertyRector;
use Rector\CodingStyle\Rector\ClassMethod\NewlineBeforeNewAssignSetRector;
use Rector\Config\RectorConfig;
use Rector\Doctrine\Set\DoctrineSetList;
use Rector\Nette\Set\NetteSetList;
use Rector\Set\ValueObject\LevelSetList;
use Rector\Symfony\Set\SensiolabsSetList;
use Rector\Symfony\Set\SymfonySetList;

return static function (RectorConfig $rectorConfig): void {
    $rectorConfig->paths([
        __DIR__ . '/src',
    ]);

    $rectorConfig->rule(NewlineBeforeNewAssignSetRector::class);
    $rectorConfig->rule(InlineConstructorDefaultToPropertyRector::class);

    $rectorConfig->import(SymfonySetList::SYMFONY_60);
    $rectorConfig->import(SensiolabsSetList::FRAMEWORK_EXTRA_61);
    $rectorConfig->import(LevelSetList::UP_TO_PHP_81);
    $rectorConfig->import(SymfonySetList::SYMFONY_CONSTRUCTOR_INJECTION);

//    $rectorConfig->sets([
//        DoctrineSetList::ANNOTATIONS_TO_ATTRIBUTES,
//        SymfonySetList::ANNOTATIONS_TO_ATTRIBUTES,
//        NetteSetList::ANNOTATIONS_TO_ATTRIBUTES,
//    ]);
};
