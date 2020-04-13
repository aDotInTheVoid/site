---
title: "Metaregex: Idiomatic python to Idiomatic Rust"
date: 2020-04-08T10:42:42+01:00
draft: true
toc: true
---
[![xkcd 1313](https://imgs.xkcd.com/comics/regex_golf.png)](https://xkcd.com/1313/) [^xkcd_license]

## Problem Statement
Being bored in quarantine, I decided to try to implement this. But first, I
needed to check if someone else has. It turns out [someone
has](https://nbviewer.jupyter.org/url/norvig.com/ipython/xkcd1313.ipynb), and
that person it [Peter Norvig](https://en.wikipedia.org/wiki/Peter_Norvig).

You should go read his solution first because:
1. It's the basis for what I'm attempting to do
2. It's a delightful piece of algorithm design and pythonic code

The challenge is to port norvig's python solution to rust. Specificity:
1. No algorithm changes. This needs to be an apples to apples comparison.
2. No custom regex code. Norvig uses pythons regex implementation, so I will use
   the `regex` crate.

## Naive Port

Now lets get into my code. The story I want to tell is not of the initial code,
but of the imporvements made to it.
```rust
use itertools::Itertools;
use regex::Regex;
use std::collections::HashSet;

type Set<'a> = HashSet<&'a str>;

const WINNERS: &str =
    "washington adams jefferson jefferson madison madison monroe \
     monroe adams jackson jackson van-buren harrison polk taylor \
     pierce buchanan lincoln lincoln grant grapartnt hayes garfield \
     cleveland harrison cleveland mckinley mckinley roosevelt taft \
     wilson wilson harding coolidge hoover roosevelt roosevelt \
     roosevelt roosevelt truman eisenhower eisenhower kennedy \
     johnson nixon nixon carter reagan reagan bush clinton clinton \
     bush bush obama obama trump";

const LOSERS: &str =
    "clinton jefferson adams pinckney pinckney clinton king adams \
     jackson adams clay van-buren van-buren clay cass scott fremont \
     breckinridge mcclellan seymour greeley tilden hancock blaine \
     cleveland harrison bryan bryan parker bryan roosevelt hughes \
     cox davis smith hoover landon willkie dewey dewey stevenson \
     stevenson nixon goldwater humphrey mcgovern ford carter \
     mondale dukakis bush dole gore kerry mccain romney clinton";

const START: u8 = '^' as u8;
const DOT: u8 = '.' as u8;
const END: u8 = '$' as u8;
```
Things to note here:
1. I've added new winners and looser to reflect the election status at the time
   of writing
2. I've used the [`Itertools`](https://docs.rs/itertools/0.9.0/itertools/) crate
   for the
   [`cartesian_product`](https://docs.rs/itertools/0.9.0/itertools/trait.Itertools.html#method.cartesian_product)
   method


```rust
pub fn main() {
    let mut winners: HashSet<_> =
        WINNERS.split_whitespace().collect();
    let mut losers: HashSet<_> = LOSERS
        .split_whitespace()
        .collect::<Set>()
        .difference(&winners)
        .map(|x| *x)
        .collect::<HashSet<_>>();

    losers.insert("fillmore");
    losers.remove("fremont");

    println!("{}", find_regex(&mut winners, &losers));
}
```
The main function is quite unwieldy for what it needs to do. We need to use the
[`difference`](https://doc.rust-lang.org/stable/std/collections/hash_set/struct.HashSet.html#method.difference)
method as [`Sub<HashSet> for
&HashSet`](https://doc.rust-lang.org/stable/std/collections/hash_set/struct.HashSet.html#impl-Sub%3C%26%27_%20HashSet%3CT%2C%20S%3E%3E)
requires the elements to be `Clone`.

Additionally `difference` returns an iterator of references, but as the original
Set had `&str` the item is now `&&str` so we need to dereference it before we
collect to a Set.


```rust
fn find_regex(winners: &mut Set, losers: &Set) -> String {
    let mut pool: HashSet<_> =
        regex_parts(&winners, &losers).collect();
    let mut solutions: Vec<String> = vec![];
    while winners.len() != 0 {
        let best = pool.iter().max_by_key(|pat| {
            4 * matches(pat, winners.iter().map(|&x| x)).count()
                as i64
                - pat.len() as i64
        });
        if let Some(best_part) = best {
            solutions.push(best_part.clone());
            winners.retain(|entry| {
                !Regex::new(best_part).unwrap().is_match(entry)
            });
            pool.retain(|patern| {
                matches(patern, winners.iter().map(|&x| x))
                    .next()
                    .is_some()
            });
        } else {
            eprintln!("I don't think it can be done");
        }
    }
    solutions.join("|")
}
```
This mainloop works fairly well. We keep adding the best solution, and then use [`retain`](https://doc.rust-lang.org/stable/std/collections/hash_set/struct.HashSet.html#method.retain) to remove matched winners and patterns that no longer match.

One interesting thing is in the fitness function (the closure inside
`max_by_key`) we need to convert to a signed integer, otherwise the length will
underflow and we end up with
```
^taft$|^bush$|^polk$|^obama$|^hayes$|^trump$|^nixon$|^adams$|^grant$
|^truman$|^taylor$|^monroe$|^wilson$|^carter$|^hoover$|^pierce$
|^reagan$|^lincoln$|^harding$|^jackson$|^kennedy$|^madison$|^johnson$
|^clinton$|^coolidge$|^buchanan$|^harrison$|^garfield$|^mckinley$
|^cleveland$|^grapartnt$|^roosevelt$|^van-buren$|^jefferson$
|^eisenhower$|^washington$`
```

```rust
fn regex_parts<'a>(
    winners: &'a Set<'a>,
    losers: &'a Set<'a>,
) -> impl Iterator<Item = String> + 'a {
    let whole = winners.iter().map(|x| format!("^{}$", x));
    let parts =
        whole.clone().flat_map(subparts).flat_map(dotify).filter(
            move |part| {
                losers.iter().all(|loser| {
                    !Regex::new(part).unwrap().is_match(loser)
                })
            },
        );
    whole.chain(parts)
}
```
This is relay nice. We can use
[`flat_map`](https://doc.rust-lang.org/stable/std/iter/trait.Iterator.html#method.flat_map)
to first expand every winner into their subparts and then expand the subparts
into all the dotted versions. Then a filter to check that they don't match any
losers ensures all the parts will work.

```rust
fn dotify(word: String) -> impl Iterator<Item = String> {
    let has_front = (word.as_bytes()[0] == START) as usize;
    let has_end = (word.as_bytes()[word.len() - 1] == END) as usize;
    let len = word.len() - has_front - has_end;
    (0..2_usize.pow(len as u32))
        .map(move |x| x << has_front)
        .map(move |n| get_dots(&word, n))
}

fn get_dots(word: &str, n: usize) -> String {
    let mut tmp = word.to_string();
    set_dots(&mut tmp, n);
    tmp
}

fn set_dots(word: &mut str, n: usize) {
    assert!(word.is_ascii(), "Not ascii, cant do dots");
    for i in 0..word.len() {
        if ((n >> i) & 1) != 0 {
            // Safety: The thing is all ascii, so we
            //         will maintain utf-8 invariance
            unsafe {
                word.as_bytes_mut()[i] = DOT;
            }
        }
    }
}
```
The dotification is surprisingly complex. We use `set_dots` to use a number to
encode which characters are to be turned to dots. Changing them actually
requires `unsafe` as UTF-8 means if we tried to do it in the middle of an emoji
or other multi-byte character, we'd end up with invalid unicode, so we use an
assert to ensure this doesn't happen. 

`get_dots` is a simple wrapper around `set_dots` that deals with the string allocation.

`dotify` creates an iterator such that `^` and `$` are preserved and dotifys the rest

```rust
fn subparts(word: String) -> impl Iterator<Item = String> {
    let len = word.len();
    (0..=len)
        .cartesian_product(1..5)
        .map(|(start, offset)| (start, start + offset))
        .filter(move |(_, end)| *end <= len)
        .map(move |(start, end)| word[start..end].to_owned())
}

fn matches<'a>(
    r: &String,
    strs: impl Iterator<Item = &'a str> + 'a,
) -> impl Iterator<Item = &'a str> + 'a {
    let re = Regex::new(r).unwrap();
    strs.filter(move |s| re.is_match(s))
}
```
Finally a few helper methods.

If your not sure what any of these these functions do, [the tests are here](https://gist.github.com/aDotInTheVoid/e9bc7ef2e12f3140e44b8a7ab0b4a057).

This code is not well optimized. Regexes are being compiled only to be used once
and theirs a lot of string allocation. However untuned rust code has
[been](https://youtu.be/HgtRAbE1nBM?t=2573)
[known](http://dtrace.org/blogs/bmc/2018/09/18/falling-in-love-with-rust/) to
beat c, so I should beat norvig's python, right?

```
$ time ./target/release/v1 
a.a|i..n|j|li|a.t|a..i|bu|oo|tr|ay.|n.e|r.e$|ls|po|lev

real    0m4.815s
user    0m4.757s
sys     0m0.026s
$ time python norvig.py 
53 a.a|a..i|j|oo|a.t|i..o|i..n|bu|n.e|ay.|r.e$|tr|po|v.l

real    0m1.447s
user    0m1.357s
sys     0m0.047s
```
Oops.

## Cheep optimizations

Since we're not using unicode we can [disable that](https://github.com/rust-lang/regex/pull/613)
```toml
[dependencies.regex]
version = "1.3.0"
default-features = false
features = ["std", "perf"]
```
```
$ time ./target/release/meta-regex-golf 
a.a|a..i|j|oo|a.t|i..n|i..o|bu|n.e|ay.|r.e$|ru|po|l.v

real    0m4.489s
user    0m4.421s
sys     0m0.028s
```
Nope, not that.

Going throught [the cheep tricks](https://deterministic.space/high-performance-rust.html), we add
```toml
[profile.release]
lto = "fat"
codegen-units = 1
```
and build with `RUSTFLAGS="-C target-cpu=native" cargo build --release`

```
$ time ./target/release/v1 
a.a|i..n|j|li|a.t|a..i|ru|oo|bu|n.e|ay.|r.e$|ls|po|lev

real    0m4.715s
user    0m4.678s
sys     0m0.020s
```
What, has it goten worse
```
time ./target/release/v1 
a.a|i..n|j|oo|a.t|i..o|a..i|tr|bu|ay.|n.e|r.e$|po|nd$

real    0m4.540s
user    0m4.497s
sys     0m0.022s
$ time ./target/release/v1 
a.a|i..n|j|li|a.t|a..i|ru|oo|bu|n.e|ay.|r.e$|ls|po|e.a

real    0m4.747s
user    0m4.688s
sys     0m0.026s
$ time ./target/release/v1 
a.a|i..n|j|oo|a.t|i..o|a..i|ru|bu|n.e|ay.|r.e$|po|vel

real    0m4.619s
user    0m4.567s
sys     0m0.026s
$ time ./target/release/v1 
a.a|i..n|j|oo|a.t|i..o|a..i|ru|bu|ay.|n.e|r.e$|po|ela

real    0m4.492s
user    0m4.443s
sys     0m0.023s
$ time ./target/release/v1 
a.a|i..n|j|li|a.t|a..i|tr|bu|oo|ay.|n.e|r.e$|po|ls|lev

real    0m4.449s
user    0m4.402s
sys     0m0.021s
```
Nope, it's just unstable.

## Profiling

Given none of the cheep tricks have worked, we need to actually know what we're
spending time on. Running [`cargo flamegraph`](https://github.com/flamegraph-rs/flamegraph) we get:
[![](/img/rust_regex_fg1.svg)](/img/rust_regex_fg1.svg)

(You can click on the image to view the full interactive SVG.)

Wait, is that `regex::re_unicode::Regex::new`.
[Yep](https://github.com/rust-lang/regex/blob/3221cdb1e33064ed6648d0a5559711cea9c18067/src/lib.rs#L648-L652).
It's still called that, even with unicode turned off.

Anyway, it looks like most of the time is going to building the regex. Where
this takes place is unclear. Splattering a bunch of `#[inline(never)]` over the
code, we get this slightly better graph.

[![](/img/rust_regex_fg2.svg)](/img/rust_regex_fg2.svg)

Again we're looking at most of the time going to regex compilation. Givin this
may be the only application (let me know if it isn't) that depends on compiling
regex's fast, it's understandable that the regex crate doesn't care about it
much. In fact, in the performance guide, the first thing it tells you is [avoid
compiling
regexes]().

Therefor what needs to happen is when a `String` for a regex part is generated
in `regex_parts`, it is stored with the `regex::Regex` it represents instead of
creating that `regex::Regex` every time.

## Caching Regexes

```rust
#[derive(Clone)]
struct Part {
    string: String,
    reg: Regex,
}
```
Because `regex::Regex` doesn't implement `Hash` or `Eq` (why would it?), we need
to do that ourselves. Fortunately we can use the string to do that as every
string uniquely identifies a regex. 

```rust
impl Hash for Part {
    fn hash<H: Hasher>(&self, state: &mut H) {
        self.string.hash(state);
    }
}
impl PartialEq for Part {
    fn eq(&self, other: &Self) -> bool {
        self.string == other.string
    }
}
impl Eq for Part {}

impl Part {
    fn new(string: String) -> Self {
        let reg = Regex::new(&string).unwrap();
        Self { reg, string }
    }
}
```

Now to rewrite the rest of the code. `matches` becomes

```rust
fn matches<'a>(
    r: &'a Part,
    strs: impl Iterator<Item = &'a str> + 'a,
) -> impl Iterator<Item = &'a str> + 'a {
    strs.filter(move |s| r.reg.is_match(s))
}
```

The rest of the code is also easily ported, by replacing normal calls to calls
to the `string`, and calls to `Regex::new(...).unwrap()` to the `reg`.

The only complication was that we had to add `#![type_length_limit="12373190"]`. This is because regex_parts returns a iterator so complex it's full type signature is

```
core::iter::adapters::chain::Chain<core::iter::adapters::Map<core::iter::adapters::Map<std::collections::hash::set::Iter<&str>, playground::regex_parts::{{closure}}>, playground::Part::new>, core::iter::adapters::Filter<core::iter::adapters::Map<core::iter::adapters::flatten::FlatMap<core::iter::adapters::flatten::FlatMap<core::iter::adapters::Map<std::collections::hash::set::Iter<&str>, playground::regex_parts::{{closure}}>, core::iter::adapters::Map<core::iter::adapters::Filter<core::iter::adapters::Map<itertools::adaptors::Product<core::ops::range::RangeInclusive<usize>, core::ops::range::Range<usize>>, playground::subparts::{{closure}}>, playground::subparts::{{closure}}>, playground::subparts::{{closure}}>, playground::subparts>, core::iter::adapters::Map<core::iter::adapters::Map<core::ops::range::Range<usize>, playground::dotify::{{closure}}>, playground::dotify::{{closure}}>, playground::dotify>, playground::Part::new>, playground::regex_parts::{{closure}}>>
```

Has this worked.

```
$ time ./target/release/v2
a.a|i..n|j|oo|a.t|i..o|a..i|bu|tr|ay.|n.e|r.e$|po|vel

real    0m0.357s
user    0m0.322s
sys     0m0.030s
```
Yep, it has.

But can we go further. Let's do a flamegraph for this new version and see where we land

[![](/img/rust_regex_fg3.svg)](/img/rust_regex_fg3.svg)

Their's three main parts: 
- `core::ptr::drop_in_place`: We're using alot of strings, so /(de)?allocations/
  are inevitable. That said, useing an alternative allocator may speed this up.
- `regex::re_unicode::Regex::new` is still about 60% Of the time. However baring
  switching to an alternate regex implementation, I'm not sure what more can be
  done.
- `regex::re_unicode::Regex::new` now takes up 21% of the of the time. This is
  much better as it previously only took up 11% so much more of the time is
  actual regex work.

## Further Regex options

At this point I went and looked back at the [regex perf options](https://docs.rs/regex/1.3.6/regex/#performance-features) and found this

> * **perf** -
>   Enables all performance related features. This feature is enabled by default
>   and will always cover all features that improve performance, even if more
>   are added in the future.
> * **perf-cache** -
>   Enables the use of very fast thread safe caching for internal match state.
>   When this is disabled, caching is still used, but with a slower and simpler
>   implementation. Disabling this drops the `thread_local` and `lazy_static`
>   dependencies.
> * **perf-dfa** -
>   Enables the use of a lazy DFA for matching. The lazy DFA is used to compile
>   portions of a regex to a very fast DFA on an as-needed basis. This can
>   result in substantial speedups, usually by an order of magnitude on large
>   haystacks. The lazy DFA does not bring in any new dependencies, but it can
>   make compile times longer.
> * **perf-inline** -
>   Enables the use of aggressive inlining inside match routines. This reduces
>   the overhead of each match. The aggressive inlining, however, increases
>   compile times and binary size.
> * **perf-literal** -
>   Enables the use of literal optimizations for speeding up matches. In some
>   cases, literal optimizations can result in speedups of _several_ orders of
>   magnitude. Disabling this drops the `aho-corasick` and `memchr` dependencies.

From this it looks like `perf-inline` and `perf-dfa` are the ones that will take
up compile time. Trying with just `perf-cache` and `perf-literal` gives modest
gains

```
$ time ./target/release/v2
a.a|a..i|j|li|a.t|i..n|bu|tr|oo|ay.|n.e|r.e$|ls|po|e.a

real    0m0.338s
user    0m0.312s
sys     0m0.023s
```

## Alternative Allocations
Next we can replace the allocator. Rust makes it very easy to use an alternative to the system allocator, such as Jemalloc:
```rust
#[global_allocator]
static GLOBAL: Jemalloc = Jemalloc;
```
```
time ./target/release/v2
a.a|i..n|j|li|a.t|a..i|ru|bu|oo|ay.|n.e|r.e$|ls|po|v.l

real    0m0.250s
user    0m0.226s
sys     0m0.021s
```
That a roughly 25% speedup just by ditching the system allocator (macOS 10.14.6 (18G1012))

I also tried mimalloc, but is was slower.

[![](/img/rust_regex_fg4.svg)](/img/rust_regex_fg4.svg)

After using jemalloc, the flamegraph looks like this, and their is very little time spend allocating. Almost all the time is spend in `regex` itself, so I think that's it.


## Conclusion

[^xkcd_license]: Comic licensed under a [Creative Commons Attribution-NonCommercial 2.5 License](http://creativecommons.org/licenses/by-nc/2.5/)
