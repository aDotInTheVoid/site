---
title: Rustdoc JSON in 2022 and beyond
draft: true
date: 2022-12-27
---


It's that time of year again, when everyone
[is](https://predr.ag/blog/cargo-semver-checks-today-and-in-2023/)
[writing](https://bytecodealliance.org/articles/cranelift-progress-2022)
[excellent](https://tweedegolf.nl/en/blog/81/our-year-in-rust)
[summary](https://llogiq.github.io/2022/12/11/catch22.html)
[articles](https://www.npopov.com/2022/12/20/This-year-in-LLVM-2022.html)
[about](https://blog.yoshuawuyts.com/rust-2023/#footnote-reference-0)
[what](https://www.youtube.com/watch?v=OuSiuySr6_Q)
[happened](https://cohost.org/lcnr/post/690887-rust-in-2023)
[this](https://slint-ui.com/blog/2022-in-review.html)
year, and goals for the next one. I figured I should do the same for rustdoc-json.

## What is rustdoc-json?

If you haven't heard of it yet, rustdoc-json is an unstable feature for rustdoc
that allows rustdoc to output a JSON description of a crates API, as opposed to
the stable HTML output.

This allows tools to be written that reason about an API without them having to interface directly
with the (even more unstable) rustc APIs, and that benefit from all the processing and cleanup that
rustdoc does.

## Format Changes

The biggest user-facing change has been the number of changes to the JSON Format itself.
Version [^version] 11 to 23 were released this year [^nye].

[^version]: At the root level of the output, theirs a field called
    `format_version`, that gets increased by 1 every time we change the
    definition of the types that get serialized.

[^nye]: Assuming nothing gets released on New Years Eve.

11. [#94137](https://github.com/rust-lang/rust/pull/94137/): Clean up the `Header` struct by:
    - Making `ABI` an enum, instead of being stringly typed.
    - Replace `HashSet<Qualifiers>` with 3 bools (`const_`, `unsafe_`, and `async_`).
    - Merge `ABI` field into `Header`, as they always occur together.
12. [#94009](https://github.com/rust-lang/rust/pull/94009/): Support GATs.
13. [#94150](https://github.com/rust-lang/rust/pull/94150/): Report whether a generic type bound is `synthetic` (generated from `impl Trait` in argument position).
14. [#94921](https://github.com/rust-lang/rust/pull/94921/): Make names more consistent:
    - Consistently use `type_` over `ty`.
    - Have `Trait` call it `implementations`, (not `implementors`), because the
      Id's are the `impl` blocks, not the types that impl the trait.
15. [#96647](https://github.com/rust-lang/rust/pull/96647/): Report HRTBs on
    where predicates.
16. [#99287](https://github.com/rust-lang/rust/pull/99287/): This is a larger
    structural change, that will be discussed next. It's also a format change
    because it added the `is_stripped` field to `Module`.
17. [#99787](https://github.com/rust-lang/rust/pull/99787/): Add `dyn Trait` as
    a separate variant to the `Type` enum. This allows HRTBs to be reported, and
    is also more principled as it doesn't use `Type::ResolvedPath` for both
    concrete types (struct, enum, union) and dyn traits.
18. [#100335](https://github.com/rust-lang/rust/pull/100335/): Refer to traits
    directly with a `Path` struct, instead of using `Type::ResolvedPath`.
19. [#101386](https://github.com/rust-lang/rust/pull/101386/): Report the
    `discriminant` of enum variants. [^discr_unit]
20. [#101462](https://github.com/rust-lang/rust/pull/101462/): Change how fields
    in enum variants are stored, to better support ordering and
    `#[doc(hidden)]`.
21. [#101521](https://github.com/rust-lang/rust/pull/101521/): Store a `Struct`'s
    `fields` inside the `StructKind` enum, to better support ordering and
    `#[doc(hidden)]`.
22. [#102321](https://github.com/rust-lang/rust/pull/102321/): Add `impls` to
    `Primitive`s.
23. [#104499](https://github.com/rust-lang/rust/pull/104499/): Use Function
    everywhere and remove Method

[^discr_unit]: It turns out this support isn't great. While writing this post, I
    realised that we only support discriminants on unit variants. This
    restruction has [been
    lifted](https://blog.rust-lang.org/2022/12/15/Rust-1.66.0.html#explicit-discriminants-on-enums-with-fields),
    and I've filled [an issue](https://github.com/rust-lang/rust/issues/106299)
    and intend to fix it in the new year.


While doing this many changes (on average about 2 a month), may seem disruptive,
there are many things that make it less of a burden for users:

1. Version numbering: Because each version increase changes a constant. This
   makes error reporting much friendlier. [For
   example](https://github.com/awslabs/cargo-check-external-types/blob/04ee5b72026bcd73292099904744184590f4e86d/src/cargo.rs#L73-L77)
   `cargo-check-external-types` first attempts to deserialize just the format
   version, and bails if that doesn't match. This means the user receives an
   error about the version of nightly being wrong, which is much more useful and
   actionable than an error about a missing or unknown JSON field.
2. JSON's inherent flexibility: Because of how `serde_json` works, adding a
   field won't break old code, nor will removing an enum variant. This means
   that many of the smaller changes may not actually require users to update.
3. Automatically notifying users: Maintainers of tools that consume rustdoc-json
   can be automatically notified when a change to the format is proposed. In some
   cases, this has led to fixes to tools being written before the PR to rust has
   landed (eg
   [Enselic/cargo-public-api#95](https://github.com/Enselic/cargo-public-api/pull/95)
   and [#100335](https://github.com/rust-lang/rust/pull/100335)). If you want to
   get an early warning for changes, add yourself to [this
   list](https://github.com/rust-lang/rust/blob/7c991868c60a4afc1ee6334b912ea96061a2c98d/triagebot.toml#L404-L415),
   and the magic of rust's bots will keep you up to date.


## Big Change: Don't inline

Format version 16, introduced in [#99287](https://github.com/rust-lang/rust/pull/99287/) merits its own discussion, as it was a much deeper change to how the format represents rust code, and fixed a lot more bugs.

The root of the problem is that each new file in rust is its own module
[^include]. This means that if each type went in its own file (which was a `pub
mod`), then the type name is duplicated with the module name.

[^include]: Barring the [`include!`](https://doc.rust-lang.org/stable/std/macro.include.html) macro, which isn't relevent here.

Eg if theirs a library called `collections` that's laid out like

```
collections/
├── Cargo.lock
├── Cargo.toml
└── src
    ├── lib.rs
    ├── list.rs
    ├── map.rs
    └── set.rs
```

And written like

```rust
// collections/src/lib.rs
pub mod list;
pub mod set;
pub mod map;
// collections/src/list.rs
pub struct List;
// collections/src/set.rs
pub struct Set;
// collections/src/map.rs
pub struct Map;
```

Then users of the module see the paths like `collections::list::List`, which
needlessly duplicates "list". To avoid this, code like this tends to get
written as

```rust
// collections/src/lib.rs
mod list;
mod set;
mod map;
pub use list::List;
pub use set::Set;
pub use map::Map;
// collections/src/list.rs
pub struct List;
// collections/src/set.rs
pub struct Set;
// collections/src/map.rs
pub struct Map;
```

And the user now sees `List` as  `collections::List`, which is much nicer. It is as if the library author instead just wrote

```rust
// collections/src/lib.rs
pub struct List;
pub struct Set;
pub struct Map;
```

But also allows the separate types to be in their own files, which is much nicer for the library author.

Rustdoc goes to a lot of effort to make the code with private `mod`s and `pub
use`s look like it was all written in one file. In particular it sometimes
"inline"s items into the locations that they are `use`d, by replacing a 
`pub use` of an item with the item being used.

While this is great for the HTML output, it caused boundless problems for JSON. The most
canonical example is

```rust
mod style {
    pub struct Color;
}

pub use style::Color;
pub use style::Color as Colour;
```

[In HTML Output](https://docs.rs/ansi_term/0.12.1/ansi_term/index.html#enums),
both `Color` and `Colour` are created as separate pages, with no indication that
they are the same item. In fact, it is the same result as if

```rust
pub struct Color;
pub struct Colour;
```

was written.

In JSON this would crash, as two different items were created with the same ID, triggering  an assertion failure.

The fix for this in JSON is to not inline, and instead report the root module as
having two items, both of which are imports of the same struct item. The struct
item isn't a member of any module, and is only accessible via the imports. While
this would be an unacceptable UI issue for HTML, in JSON it's better to report
the true nature of the code than to try to clean it up with inlines.

Changing this fixed a major source of issues for rustdoc-json, and make the
output far less likely to ICE.

## Package std docs

Another nice user-facing change this year was including the docs for `std` (and
friends) as a rustup component. Because `std` is special in that it isn't built
like normal dependencies, but is magically made available by cargo and rustc, its
json [^html] docs can't be produced by cargo like they can for normal
dependencies. Therefore they need to be shipped  by rustup.

[^html]: Or HTML for that matter. Rustup has long distributed html docs for `std` as a component.


- [#101799](https://github.com/rust-lang/rust/pull/101799/): Add `rust-json-docs` to `bootstrap`
- [#102042](https://github.com/rust-lang/rust/pull/102042/): Rename to `rust-docs-json` and try to add to rustup build-manifest
- [#102241](https://github.com/rust-lang/rust/pull/102241/): Fix build-manifest.
- [#102807](https://github.com/rust-lang/rust/pull/102807/): Add documentation to the Unstable Features section of the rustdoc book.
- [#104887](https://github.com/rust-lang/rust/pull/104887/): Fix `./x doc library/core/ --json` panicking if HTML docs weren't built.

Making this work took several attempts, but now that this is all done, anyone
can run `rustup component add --toolchain nightly rust-docs-json` to get the
docs for `std`, `alloc`, `core`, `test`, and `proc_macro` in the
`share/doc/rust/json/` directory of the rustup toolchain directory, and
automatically kept up to date with the nightly toolchain by rustup.

## Test tool improvements

While these were the big user-facing improvements, there were also many internal
improvements, particularly around the test tooling.

Rustdoc JSON is currently tested with two tools. The first, `jsondocck` reads
comments from the files which contain assertions about the JSON output, and
checks that the output matches the assertions. The assertions are written in
[JsonPath](https://github.com/json-path/JsonPath), and let you check that the
output has (and doesn't have) the values that you expect.

Eg [`src/test/rustdoc-json/reexport/reexport_method_from_private_module.rs`](https://github.com/rust-lang/rust/blob/bbdca4c28fd9b57212cb3316ff4ffb1529affcbe/src/test/rustdoc-json/reexport/reexport_method_from_private_module.rs) 
currently looks like

```rust
// @set impl_S = "$.index[*][?(@.docs=='impl S')].id"
// @has "$.index[*][?(@.name=='S')].inner.impls[*]" $impl_S
// @set is_present = "$.index[*][?(@.name=='is_present')].id"
// @is "$.index[*][?(@.docs=='impl S')].inner.items[*]" $is_present
// @!has "$.index[*][?(@.name=='hidden_impl')]"
// @!has "$.index[*][?(@.name=='hidden_fn')]"


mod private_mod {
    pub struct S;

    /// impl S
    impl S {
        pub fn is_present() {}
        #[doc(hidden)]
        pub fn hidden_fn() {}
    }

    #[doc(hidden)]
    impl S {
        pub fn hidden_impl() {}
    }
}

pub use private_mod::*;
```

It checks that the struct `S` has an impl block whose only method is
`is_present`, and that `hidden_impl` and `hidden_fn` aren't mentioned.

Over this year, two major changes were landed to `jsondocck` that make writing these tests much nicer.

1. [#99474](https://github.com/rust-lang/rust/pull/99474/): Add `@ismany` to `jsondocck` to do a setwise comparison.
2. [#100678](https://github.com/rust-lang/rust/pull/100678/): Don't require specifying file in `jsondocck`.

Between them, they mean a test like:

```rust
struct S
/// the impl
impl S {
    pub fn foo() {}
    pub fn bar() {}
}
// @set foo = name_of_test.rs "$.index[*][?(@.name=='foo')].id"
// @set bar = - "$.index[*][?(@.name=='foo')].id"
// @count - "$.index[*][?(@.docs=='the impl')].inner.items[*]" 2
// @has   - "$.index[*][?(@.docs=='the impl')].inner.items[*]" $foo
// @has   - "$.index[*][?(@.docs=='the impl')].inner.items[*]" $bar
```

can be rewritten to be

```rust
// @set foo = "$.index[*][?(@.name=='foo')].id"
// @set bar = "$.index[*][?(@.name=='foo')].id"
// @ismany "$.index[*][?(@.docs=='the impl')].inner.items[*]" $foo $bar
```

which is much nicer.

The other tool that's used is one that checks that all `Id`s mentioned are
present in the index (or paths). Originally this was a python script called
`check_missing_items.py`, but in
[#101809](https://github.com/rust-lang/rust/pull/101809/), it was replaced with
`jsondoclint`, a rust rewrite. This had many advantages, such as being able to
use `rustdoc-json-types` to keep up with format changes, and exhaustively matching
on kinds, leading to more bugs being caught.

Interestingly, these bugs all had to be fixed before the tool could be landed,
and in doing so, `check_missing_items.py` was fixed so it could catch them if
they regressed before `jsondoclint` landed. Despite this, it was still great to
get rid of it, and replace it with a much more maintainable tool.

However, with any big rewrite, there were bound to be bugs, and this was no
exception. In particular, a number of false positives were introduced for code
patterns not covered by the test suite. They were only unearthed when
`jsondoclint` was run on `core.json`, which isn't currently done in CI, but
should be. [^2023]. These were fixed, and tests were added.

[^2023]: Hopefully I'll talk more about this in an upcoming post about my goals for rustdoc-json next year.

- [#104879](https://github.com/rust-lang/rust/pull/104879/): Recognise `Typedef` as valid kind for `Type::ResolvedPath`
- [#104924](https://github.com/rust-lang/rust/pull/104924/): Accept trait alias in places where trait expected.
- [#104943](https://github.com/rust-lang/rust/pull/104943/): Accept `use`ing enum variants and glob `use`ing enums.

## More Tests

Another longstanding issue that was partially addressed this year is the
relative lack of tests. This year the `rustdoc-json` suite has grown from 26 to
98 tests [^test_count]. For what it's worth, in the same time period, the main
rustdoc suite [^other_suites] went from 484 to 586 tests.

[^test_count]: Measured on `bbdca4c28fd9b57212cb3316ff4ffb1529affcbe` (most
    recent commit as of the time of writing) and
    `1e6ced353215419f9e838bfbc3d61fe9eb0c004d` (last change to
    `src/test/rustdoc-json` in 2021). Number of tests measured with `fd -e rs |
    rg -v "auxiliary" | wc -l`.

[^other_suites]: This is only for the `src/test/rustdoc/` suite, and doesn't
    include ui, gui and std-json. But these are much smaller, and I'm trying to
    make a point about the rate of growth and the size of a mature test suite,
    not provide exact numbers. 

This was addressed in part with dedicated test adding PRs [^test_pr], but mainly
due to good habits of always adding tests when changing behaviour that we were
lucky to inherit from the wider rust project.

[^test_pr]:
    [#93660](https://github.com/rust-lang/rust/pull/93660/)
    , [#94861](https://github.com/rust-lang/rust/pull/94861/)
    , [#98166](https://github.com/rust-lang/rust/pull/98166/)
    , [#98548](https://github.com/rust-lang/rust/pull/98548/)
    , [#99479](https://github.com/rust-lang/rust/pull/99479/)
    , [#101634](https://github.com/rust-lang/rust/pull/101634/)
    , [#101701](https://github.com/rust-lang/rust/pull/101701/)
    , [#103065](https://github.com/rust-lang/rust/pull/103065/)
    , [#105027](https://github.com/rust-lang/rust/pull/105027/)
    , [#105063](https://github.com/rust-lang/rust/pull/105063/)


## Correctness Fixes

The final change for 2022 was the vast, vast number of bug fixes [^fix_pr]. The
fact that we were able to make so many fixes is a testament to how many users
are reporting issues. This is mainly driven by tools that make use rustdoc-json,
and in paticular cargo-public-api and cargo-semver-checks have driven a lot more
eyes towards the code.

The other major source of bug reports was running with
[crater](https://github.com/rust-lang/rust/issues/99919), which while it can
only find assertion failures, makes up for this with sheer volume. One thing I
want to look into next year is running the `jsondoclint` tool in crater, so it
can catch missing IDs, instead of just internal assertions failing.

[^fix_pr]:
    [#92860](https://github.com/rust-lang/rust/pull/92860/)
    , [#93132](https://github.com/rust-lang/rust/pull/93132/)
    , [#93954](https://github.com/rust-lang/rust/pull/93954/)
    , [#97599](https://github.com/rust-lang/rust/pull/97599/)
    , [#98053](https://github.com/rust-lang/rust/pull/98053/)
    , [#98195](https://github.com/rust-lang/rust/pull/98195/)
    , [#98390](https://github.com/rust-lang/rust/pull/98390/)
    , [#98577](https://github.com/rust-lang/rust/pull/98577/)
    , [#98611](https://github.com/rust-lang/rust/pull/98611/)
    , [#98681](https://github.com/rust-lang/rust/pull/98681/)
    , [#100299](https://github.com/rust-lang/rust/pull/100299/)
    , [#100325](https://github.com/rust-lang/rust/pull/100325/)
    , [#100582](https://github.com/rust-lang/rust/pull/100582/)
    , [#100630](https://github.com/rust-lang/rust/pull/100630/)
    , [#101106](https://github.com/rust-lang/rust/pull/101106/)
    , [#101204](https://github.com/rust-lang/rust/pull/101204/)
    , [#101633](https://github.com/rust-lang/rust/pull/101633/)
    , [#101722](https://github.com/rust-lang/rust/pull/101722/)
    , [#101770](https://github.com/rust-lang/rust/pull/101770/)
    , [#101914](https://github.com/rust-lang/rust/pull/101914/)
    , [#103653](https://github.com/rust-lang/rust/pull/103653/)
    , [#105182](https://github.com/rust-lang/rust/pull/105182/)

## Conclusion

2022 was a good year for rustdoc-json. The format is better; The code is more
reliable; The tests are more numerous and easier to write; Their are more users
depending on it. All this was made possible by many people working on and around
the format. In particular, I'd like to thank Alex Kladov, Didrik Nordström,
Guillaume Gomez, Jacob Hoffman-Andrews, Joseph Ryan, Joshua Nelson, León Orell
Valerian Liehr, Luca Palmieri, Martin Nordholts, Matthias Krüger , Michael
Goulet, Michael Howell, Noah Lev, Predrag Gruevski, QuietMisdreavus, Rune Tynan,
Tyler Mandry, and Urgau for their invaluable contributions.

Hopefully next year we can continue to improve at this solid pace. My main goal
is to impove the way cross-crate ID lookup works, but theirs also more work to
be done to fix more bugs, further flesh out the test suite, and increase
performance. I'll write more about these in a future post.

If you want to hear about that when it comes out, or just generally want to be notified the next time I have something to share online, you can find me in the Fediverse [@nixon@treehouse.systems](https://social.treehouse.systems/@nixon). If you have questions or comments on this post, I'd love to hear them on [github](https://github.com/aDotInTheVoid/site/issues/1).
