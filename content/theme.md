---
title: Theme
---
This site runs a [modified version](https://github.com/aDotInTheVoid/hyde)
of [spf13](https://spf13.com/)’s 
[hugo](https://gohugo.io/) [port](https://github.com/spf13/hyde) of [@mdo](https://twitter.com/mdo)'s
[hyde](https://hyde.getpoole.com/) theme for 
[jekyll](http://jekyllrb.com/)

Modifications made:
- [Use
  \\(\KaTeX\\)](https://github.com/aDotInTheVoid/hyde/commit/24244cd0a5ed76a787b0396cac56bb16076a90ca)
- [Better date
  format](https://github.com/aDotInTheVoid/hyde/commit/5e03b8231a92d217c949bcd0c050372b3190a636)
  (`Mon, Jan 2, 2006` to `January 2, 2006`)
- [Have a blog and non blog
  section](https://github.com/aDotInTheVoid/hyde/commit/5e03b8231a92d217c949bcd0c050372b3190a636)
    - Blog sections have dates, non-blog doesn't
    - Blog uses short list, non-blog doesn't
    - Home page has content, not blog list
- [No home link in
    sidebar](https://github.com/aDotInTheVoid/hyde/commit/532a9d455439e1abd18d913e4b0ac2d138c03033):
    The site name above does that
- [Improved Copyright
  handling](https://github.com/aDotInTheVoid/hyde/commit/90f46fe0c00a8ff394e300c7b78675d34574916d):
  Allow customization of copyright text
- [Add table of contents
  option](https://github.com/aDotInTheVoid/hyde/commit/bcab0e3ad77a2790e2e81d7b38441eedfb706fe8)
- [Add `not_a_list`
  type](https://github.com/aDotInTheVoid/hyde/commit/d88b6c98164bea424214ef0f5bf79e2236695a79):
  This is a list type where the list is actualy a single. If you want `.../foo/`
  and `.../foo/bar` to both look like a single, `.../foo/_index.md` should have
  `type: not_a_list`
- [Add image lazy
  loading](https://github.com/aDotInTheVoid/hyde/commit/cf63c6571696094c26926548ac9b5c8e552edcfa):
  Based on [this
  gist](https://gist.github.com/bgadrian/68ec61ed90d7ebe879bd7f0ce4a2a701)


