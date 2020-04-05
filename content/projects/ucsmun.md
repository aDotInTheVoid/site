---
title: UCSMun
subtitle: A manager for a MUN conference
layout: single
date: 2015-01-15
---

```php
<?php

use Faker\Generator as Faker;

$factory->define(App\School::class, function (Faker $faker) {
    return [
        'name' => $faker->company
    ];
});
```
