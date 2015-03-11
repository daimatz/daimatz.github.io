---
title: Some good revs are not ancestor of the bad rev.
description: と言われたときにどうするか
tags: git
---

```sh
git bisect start
git bisect good 98765432
git bisect bad 12345678
```

すると

```
Some good revs are not ancestor of the bad rev.
git bisect cannot work properly in this case.
Maybe you mistake good and bad revs?
```

と言われることがあります。本人は至ってまじめなんですが。
これ、実は**過去にあったバグがいつ直ったか**を探そうとしています。
本来 `git bisect` は**正常に動いていたものがいつバグったか**を探すものです。
意味が逆になっているのですが、 `git bisect` を「要は二分探索するんだろー」
と思っているとハマります。ハマりました。

workaround としては、 `good` と `bad` の意味を逆にすることです。つまり

```sh
git bisect start
git bisect good 12345678 # バグっているコミット
git bisect bad 98765432  # バグがいつの間にか直っていたコミット
```

として、 bisect 中もバグが再現したら `git bisect good`, 直ったら
`git bisect bad` としましょう。

混乱しそう。
