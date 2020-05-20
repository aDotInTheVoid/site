---
title: "Metaregex: Python can be fast too"
date: 2020-05-20
draft: false
---

[![xkcd 1313](https://imgs.xkcd.com/comics/regex_golf.png)](https://xkcd.com/1313/)
[^xkcd_license]


## Problem Statement
I wanted to try to implement this in rust as something to do during
quarantine. Doing so lead me down a rabbit whole of profiling, optimization and
python performance, so I thought it was worth writing about.

Obviously, the first step was to see if someone had already done this someone
else has. It turns out [someone has](https://nbviewer.jupyter.org/url/norvig.com/ipython/xkcd1313.ipynb), 
and that when that person is [Peter Norvig](https://en.wikipedia.org/wiki/Peter_Norvig), 
you should probably read it.

I ended up basing my code around his algorithm. This means for this post to 
make sense, you should go read his solution. In addition, it's also a  
delightful piece of algorithm design and pythonic code


The challenge is to port Norvig's python solution to rust to increase
performance. Specificity:
1. No algorithm changes. This needs to be an apples to apples comparison.
2. No custom regex code. Norvig uses pythons regex implementation, so I will
   use the `regex` crate. This will become important later.


## Naïve Port

Now lets get into the first version code. The story I want to tell is not of the
initial code, but of the improvements made to it. This is just the first thing
that worked.
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

const START: u8 = b'^';
const DOT: u8 = b'.';
const END: u8 = b'$';
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
    // Iterate until we match all winners
    while winners.len() != 0 {
        // Select best candidate from pool
        let best = pool.iter().max_by_key(|pat| {
            4 * matches(pat, winners.iter().map(|&x| x)).count()
                as i64
                - pat.len() as i64
        });
        // Candidate may be none, so we need to handle that
        if let Some(best_part) = best {
            // Add to solutions
            solutions.push(best_part.clone());
            // Remove entries matched by new regex
            winners.retain(|entry| {
                !Regex::new(best_part).unwrap().is_match(entry)
            });
            // Remove regex's that no longer match anything
            pool.retain(|pattern| {
                matches(pattern, winners.iter().map(|&x| x))
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
This mainloop works fairly well. We keep adding the best solution, and then use
[`retain`](https://doc.rust-lang.org/stable/std/collections/hash_set/struct.HashSet.html#method.retain)
to remove matched winners and patterns that no longer match.

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
    losers: &'a Set<'a>
) -> impl Iterator<Item = String> + 'a {
    let whole = winners.iter().map(|x| format!("^{}$", x));
    let parts = whole
        .clone()
        .flat_map(subparts)
        .flat_map(dotify)
        .filter(move |part| {
            losers
                .iter()
                .all(|loser| !Regex::new(part).unwrap().is_match(loser))
        });
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

If your not sure what any of these these functions do, [the tests are here](https://play.rust-lang.org/?version=stable&mode=release&edition=2018&gist=e1f00ce619be19cb8da4b2b57268d9a5).

This code is not well optimized. Regexes are being compiled only to be used once
and theirs a lot of string allocation. However untuned rust code has
[been](https://youtu.be/HgtRAbE1nBM?t=2573)
[known](http://dtrace.org/blogs/bmc/2018/09/18/falling-in-love-with-rust/) to
beat c, so I should beat norvig's python, right?

```
$ time ./target/release/v1_naive
a.a|i..n|j|li|a.t|a..i|bu|oo|tr|ay.|n.e|r.e$|ls|po|lev

real 2.395320
user 2.388920
sys 0.000000
$ time python norvig.py 
53 a.a|a..i|j|oo|a.t|i..o|i..n|bu|n.e|ay.|r.e$|tr|po|v.l

real 1.181500
user 1.175260
sys 0.000000
```
[^bench notes]

[^bench notes]: These benchmarks were taken from the average of 500 runs. 
See [here](https://github.com/aDotInTheVoid/meta-regex-golf) for the full setup.
Python 3.7.7 and rustc 1.43.1 were used on Fedora 31 system running
linux 5.6.7-200 and glibc 2.30-11 with 8GB of RAM and an i7-2700K @ 3.50 GHz

How could this have happened. Well Norvig's code (probably) spends most of it's
time not in interpreting python but in regex and set operators. Both of these
are written in c. So the performance will actually be competitive.

## Cheep tricks
Going throught [the cheep tricks](https://deterministic.space/high-performance-rust.html), we add
```toml
[profile.release]
lto = "fat"
codegen-units = 1
```
and build with `RUSTFLAGS="-C target-cpu=native" cargo build --release`

```
$ time ./target/release/v3_cheep_tricks
a.a|i..n|j|li|a.t|a..i|ru|oo|bu|n.e|ay.|r.e$|ls|po|lev

real 2.289380
user 2.283400
sys 0.000000
```
[^missing nums]
Modest gains, but this isn't what we're looking for.

[^missing nums]: In case you're woundering where v2 is, it was trying to solve with 
[regex features](https://docs.rs/regex/1.3.7/regex/#crate-features). Every combination
other than the default seemed to slow it down. This is also what v5 was. v4 was to 
`#[inline(never)]`, and didn't need to show up in the benchmark. If you really want to see
them, you can dig through the history in the [repo](https://github.com/aDotInTheVoid/meta-regex-golf/)
## Profiling

Given none of the cheep tricks have worked, we need to actually know what we're
spending time on. Running [`cargo
flamegraph`](https://github.com/flamegraph-rs/flamegraph) we get: 

[![A flamegraph, most of the time is spent in`Regex::new`](/img/rust_regex_fg1.svg)](/img/rust_regex_fg1.svg)

(You can click on the image to view the full interactive SVG.)



Most of the time is going to building the regex (`Regex::new`), but with some time going to `is_match` and `drop_in_place`. 


Let's look at regex compilation. Regex strings are
["compiled"](https://github.com/rust-lang/regex/blob/master/HACKING.md#compilation)
to an internal representation that allows matching.  Givin this may be the only
application ([let me
know](https://github.com/aDotInTheVoid/meta-regex-golf/issues/new) if it isn't)
that depends on compiling regex's fast, the regex crate is designed (much like
rust itself) to do lots of work at compile time to avoid doing work at runtime.
In fact, in the performance guide, the first thing it tells you is [avoid
compiling
regexes](https://github.com/rust-lang/regex/blob/adb4aa3ce437ba1978af540071f85e302cced3ec/PERFORMANCE.md#thou-shalt-not-compile-regular-expressions-in-a-loop).

Therefor what needs to happen is when a `String` for a regex part is generated
in `regex_parts`, it is stored with the `regex::Regex` it represents instead of
creating that `regex::Regex` every time.

## Caching Regexes
Let's make a struct to represent a Part of a regex (eg `i..n`). 
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

Now to rewrite the rest of the code. First we add `.map(Part::new)` to
`regex_parts` to generate the regex their. Every regex gets run at least once
(in `max_by_key`) so we don't have to worry about lazily compiling them. Next we
change the function signatures and replace the calls with the regex parts. As
most of them will access the `string` field, but `Regex::new(...).unwrap()` can
become `reg`.

For example, `matches` becomes:
```rust
fn matches<'a>(
    r: &'a Part,
    strs: impl Iterator<Item = &'a str> + 'a,
) -> impl Iterator<Item = &'a str> + 'a {
    strs.filter(move |s| r.reg.is_match(s))
}
```

The only complication was that we had to add `#![type_length_limit="12373190"]`. This is because regex_parts returns a iterator so complex it's full type signature is:

```
core::iter::adapters::chain::Chain<core::iter::adapters::Map<core::iter::adapters::Map<std::collections::hash::set::Iter<&str>, playground::regex_parts::{{closure}}>, playground::Part::new>, core::iter::adapters::Filter<core::iter::adapters::Map<core::iter::adapters::flatten::FlatMap<core::iter::adapters::flatten::FlatMap<core::iter::adapters::Map<std::collections::hash::set::Iter<&str>, playground::regex_parts::{{closure}}>, core::iter::adapters::Map<core::iter::adapters::Filter<core::iter::adapters::Map<itertools::adaptors::Product<core::ops::range::RangeInclusive<usize>, core::ops::range::Range<usize>>, playground::subparts::{{closure}}>, playground::subparts::{{closure}}>, playground::subparts::{{closure}}>, playground::subparts>, core::iter::adapters::Map<core::iter::adapters::Map<core::ops::range::Range<usize>, playground::dotify::{{closure}}>, playground::dotify::{{closure}}>, playground::dotify>, playground::Part::new>, playground::regex_parts::{{closure}}>>
```

Has this worked.

```
$ time ./target/release/v5_cache_regex
a.a|i..n|j|oo|a.t|i..o|a..i|bu|tr|ay.|n.e|r.e$|po|vel

real 0.190600
user 0.180000
sys 0.007200
```
Yep, it has. That said [norvig did this
too](https://nbviewer.jupyter.org/url/norvig.com/ipython/xkcd1313-part2.ipynb#Speedup:--Faster-matches-by-Compiling-Regexes), in his follow up post
so we should benchmark that one, to be fair.

```
$ python norvig_cache.py
real 0.790220
user 0.784960
sys 0.000000
```

But can we go further? Let's do a flamegraph for this new version and see where we land

[![](/img/rust_regex_fg3.svg)](/img/rust_regex_fg3.svg)

Their's three main parts: 
- `core::ptr::drop_in_place`: We're using alot of strings, so /(de)?allocations/
  are inevitable. That said, useing an alternative allocator may speed this up.
- `regex::re_unicode::Regex::new` is still about 60% Of the time. However baring
  switching to an alternate regex implementation, I'm not sure what more can be
  done. Every regex needs to be compiled.
- `regex::re_unicode::Regex::new` now takes up 21% of the of the time. This is
  much better as it previously only took up 11% so much more of the time is
  actual regex matching.


## Alternative Allocations
Next we can replace the allocator. Rust makes it very easy to use an alternative
to the system allocator, such as Jemalloc [^mimalloc]:

```rust
#[global_allocator]
static GLOBAL: Jemalloc = Jemalloc;
```
```
time ./target/release/v7_jemalloc
real 0.163220
user 0.153220
sys 0.006380
```
That a roughly 15% speedup just by ditching the system allocator (glibc 2.30-11).

[^mimalloc]: I also tried mimalloc, but is was slower.

[![](/img/rust_regex_fg4.svg)](/img/rust_regex_fg4.svg)

After using jemalloc, the flamegraph looks like this, and their is very little
time spend allocating. Almost all the time is spend in `regex` itself, so I
think that's as far as we can go while keeping this a fair test.


## Conclusion
Rust is fast but python can be fast too. While it can be easy to assume that
with zero cost abstraction's and no garbage collector and no runtime, rust will
smoke interpreted languages like python and node. [This isn't the
case](https://youtu.be/GCsxYAxw3JQ?t=1605). Alot of work has gone into cpython
and v8 optimizations, and they both use c/c++ for things like regex and strings.

To quote [ashley williams (quoting someone else)](https://youtu.be/GCsxYAxw3JQ?t=1674)

> I just fully expected to rust my way into 50% perf over js. Sometimes you
> forget that v8 is pretty darn fast

This apples equally to python. Rust isn't a silver bullet for speed. Garbage
collection doesn't automatically mean performance will be bad.
[RIIR](https://transitiontech.ca/random/RIIR) can make things worse. Rust is
great, but so are other language

## Future work
Several things could still be done

### Use a common regex framework.
By using PCRE on both sides, we could eliminate one cause of performance difference.

### Use a custom regex engine
On the other end of the specrum, if the goal is juicing as much speed as
possible out of playing meta-regex golf, I suspect the way forward will be a
custom regex engine that is designed for fast compilation and only supports the
subset of regex used.

### Go over norvig's part 2
Norvig has written a
[followup](https://nbviewer.jupyter.org/url/norvig.com/ipython/xkcd1313-part2.ipynb#Speedup:--Faster-matches-by-Compiling-Regexes)
to the original post. I have just used it for the cached version, but their are
also some improvement to the algorithm, both in terms of speed and output
quality, it would be interesting to port over.

## Results Table
|  | Real | User | Sys |
|--|------|------|-----|
| python3 norvig_nocache.py | 1.177380 | 1.171280 | 0.000000 |
| python3 norvig_with_cache.py | 0.785040 | 0.779820 | 0.000000 |
| out/v1_naive | 2.407900 | 2.401880 | 0.000000 |
| out/v2_regex_feats | 2.428660 | 2.422040 | 0.000000 |
| out/v3_cheep_tricks | 2.288340 | 2.282500 | 0.000000 |
| out/v4_inline_never | 2.281600 | 2.275380 | 0.000020 |
| out/v5_cache_regex | 0.190940 | 0.181220 | 0.006680 |
| out/v6_regex_feats | 0.221020 | 0.213860 | 0.001540 |
| out/v7_jemalloc | 0.169620 | 0.155900 | 0.006220 |


[^xkcd_license]: Comic licensed under a [Creative Commons Attribution-NonCommercial 2.5 License](http://creativecommons.org/licenses/by-nc/2.5/)
