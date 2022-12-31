---
title: "An Introduction To Rustdoc JSON"
date: 2022-11-10
draft: true
---


*This is a loose adaption of a talk I gave at the Rust LDN Talks Community Showcase on 
[October 26, 2022](https://www.meetup.com/rust-london-user-group/events/289023932/). It wasn't recorded, but the slides are availible [online](https://adotinthevoid.github.io/talks/rustdoc-json.pdf).*


`rustdoc_json` is a unstable rustdoc feature that allows users to get a JSON decription of a crates API. I've been working on it for the past couple of years.

![](/img/rdj/overview.png)

[^pipeline]


# Thanks

Alex Kladov,
Didrik Nordström,
Guillaume Gomez,
Jacob Hoffman-Andrews,
Joseph Ryan,
Joshua Nelson,
León Orell Valerian Liehr,
Luca Palmieri,
Martin Nordholts,
Michael Goulet,
Michael Howell,
Noah Lev,
QuietMisdreavus,
Rune Tynan,
Tyler Mandry,
Urgau

# Further Reading

- [The RFC Text](https://rust-lang.github.io/rfcs/2963-rustdoc-json.html)
- [RFC PR](https://github.com/rust-lang/rfcs/pull/2963)
- [The current format docs](https://doc.rust-lang.org/nightly/nightly-rustc/rustdoc_json_types/)
- [Documentation in rustdoc book](https://doc.rust-lang.org/nightly/rustdoc/unstable-features.html#-w--output-format-output-format)
- [Tracking issue](https://github.com/rust-lang/rust/issues/76578)
- [All issues labeled `A-rustdoc-json`](https://github.com/rust-lang/rust/issues?q=is%3Aopen+is%3Aissue+label%3AA-rustdoc-json)




![](/img/rustdoc-json-talk/slide-01.png)

Hi, I'm Nixon, and tonight I'm going to be talking about the work I've been doing on Rustdoc JSON.

![](/img/rustdoc-json-talk/slide-02.png)

Rustdoc, fundamentaly, is a pipeline that takes in your rust code,
and spits out a pile of HTML telling you about it's API.

![](/img/rustdoc-json-talk/slide-03.png)

Rustdoc JSON, then is a similar pipeline that takes in your rust code, but instrad spits out a pile of JSON. My aim for this talk is to describe why you would want such a thing, why Rustdoc JSON is the best way to do it, and why the JSON Schema is the way it is.  

![](/img/rustdoc-json-talk/slide-04.png)

But the first thing to point out is that Rustdoc JSON is standing on the shoulders of giants. Specific Rustdoc JSON Logic only forms the very end of the pipeline.

![](/img/rustdoc-json-talk/slide-05.png)

The first user we're going to look at is [roogle](https://github.com/roogle-rs/roogle).

![](/img/rustdoc-json-talk/slide-06.png)

The next one is [cargo-check-external-types](https://github.com/awslabs/cargo-check-external-types)

![](/img/rustdoc-json-talk/slide-07.png)

The final one is [cargo-semver-checks](https://github.com/obi1kenobi/cargo-semver-check/)

![](/img/rustdoc-json-talk/slide-08.png)

The next question is "Why do you need rustdoc for this?". This is a good question. Rust has allowed you to call rustc API's for ages, but I don't think thats a good way to build tools like these.

![](/img/rustdoc-json-talk/slide-09.png)

The first reason is that the compiller API's are **extreamly** unstable. While Rustdoc-JSON is currently unstable, it has a [path to stability](https://rust-lang.zulipchat.com/#narrow/stream/266220-rustdoc/topic/Long.20Term.20Rustdoc.20JSON.20Stability). `#![feature(rustc_private)]`, on the other hand, will never be stabilized. Another reason is that the compiller API's break alot faster. `rustc` is about half a million lines of code, and exposes an enourmous and rapidly shifting API surface via `rustc_private`. It changes so often that `clippy`, `miri` and `rustfmt` had to move from being submodules to subtrees to avoid being frequenly broken. On the other hand, Rustdoc-JSON's schema is about 700 lines, and has changes 22 times in it's rougly 2 years of existance.

![](/img/rustdoc-json-talk/slide-10.png)

Once we've got all access to the `rustc_*` crates, the next thing to do is obtain a sysroot. This has many things, but most importantly for us, it has a precopilled version of `std`.

![](/img/rustdoc-json-talk/slide-11.png)

With that, we can finaly create a `Config`, which tells
`rustc` things about what it's compilling. In a non slideware version,
this would have things about external crates, the `cfg`s being compilled with, the target, the editon, etc. An advantage of using rustdoc is it can do all this, and can also get info on deps from cargo.

![](/img/rustdoc-json-talk/slide-12.png)

Theirs more config, but it's irrelevent to us here.

![](/img/rustdoc-json-talk/slide-13.png)
![](/img/rustdoc-json-talk/slide-14.png)
![](/img/rustdoc-json-talk/slide-15.png)
![](/img/rustdoc-json-talk/slide-16.png)
![](/img/rustdoc-json-talk/slide-17.png)
![](/img/rustdoc-json-talk/slide-18.png)
![](/img/rustdoc-json-talk/slide-19.png)
![](/img/rustdoc-json-talk/slide-20.png)
![](/img/rustdoc-json-talk/slide-21.png)
![](/img/rustdoc-json-talk/slide-22.png)
![](/img/rustdoc-json-talk/slide-23.png)
![](/img/rustdoc-json-talk/slide-24.png)
![](/img/rustdoc-json-talk/slide-25.png)
![](/img/rustdoc-json-talk/slide-26.png)
![](/img/rustdoc-json-talk/slide-27.png)
![](/img/rustdoc-json-talk/slide-28.png)
![](/img/rustdoc-json-talk/slide-29.png)
![](/img/rustdoc-json-talk/slide-30.png)
![](/img/rustdoc-json-talk/slide-31.png)
![](/img/rustdoc-json-talk/slide-32.png)
![](/img/rustdoc-json-talk/slide-33.png)
![](/img/rustdoc-json-talk/slide-34.png)
![](/img/rustdoc-json-talk/slide-35.png)
![](/img/rustdoc-json-talk/slide-36.png)

---

[^pipeline]: This diagram isn't fully accutate, as in practice rustdoc HTML and rustdoc JSON share alot of code, and both use even more code from rustc, so the following is alot closter to the truth. ![](/img/rdj/pipeline.png)