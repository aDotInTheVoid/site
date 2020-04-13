---
title: UCSMun
draft: true
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
