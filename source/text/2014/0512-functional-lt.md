---
title: 関数型LT大会で話したこと
description: 話したポエム
tags: haskell, scala, future
---

## 関数型LT大会

クックパッド社で行われていた[すごいHaskellたのしく学ぼう輪読会][sugoihaskell]
の完走を記念して[関数型LT大会という会が開催された][connpass]。
クックパッド関係なく関数型に興味ある人が集まってワイワイする感じっぽかったので、
ひとつなにか話して叩かれに行ってみるかと思って発表してきた。
そういえばクックパッド社に行くのは2回目であった。

## 自分の発表

<script async class="speakerdeck-embed" data-id="1701f420bb5a0131d135622ec9067e44" data-ratio="1.33333333333333" src="//speakerdeck.com/assets/embed.js"></script>

<br/>

Scala で初めて Future という概念を知ったのだけど、触り始めの頃はどういうコードを
書けばいいのかも全然良くわからなくて苦しんでいた。ふと「これって Haskell の IO
と同じじゃね？」と気づいてから急に視界が開けた気がしたので、そのへんのことを話し
てきた。ググっても「Future と IO 似ているよね」という説は全然見つからず、「いや
全然似てねえよバカ」とかマサカリが飛んでくることも覚悟していたけど概ね生暖かく迎
えられたようで安心した。

後で [\@eagletmt][eagletmt] 氏に「あれってモナドだって言ってるだけですよねえ」と
突っ込まれたのでそのへんの話を追記した。たしかにモナドの特徴を言っているだけだが
、重要なのは基本的に Future は一方向性のモナドであるということで、気軽にブロック
して中身を取り出すようなことをやってはいけないのである。 Twitter の
Effective Scala にも[そのへんことが書いてある][effective-scala-future]し、
Finagle について書かれたドキュメントを見るとブロックするなと書いてあるのが頻繁に
見つかる。
<s>そのへん理解してないんじゃないかなーと思うコードに以前苦しめられた過去が</s>

ある関数内で Future を呼んでいるのにその戻り値が `Future[A]` というシグネチャに
なっていない関数 (こういう関数を簡単に書けてしまう) というのは、
よほどのことがない限りアンチパターンである。具体的に許されるのは次の2パターン
くらいしかないんじゃないかなーと思っている。

1. 一番最後に IO 処理をして終わる場合
2. タイムアウトを設定し、それまでに戻って来なかったら切り捨てて計算を続ける場合

1 は Future 内で行われる IO 処理を「投げっぱなし」にすることで、その IO 処理内で
適切にエラーハンドリングされており自分でエラーハンドリングを書かなくていいと確信
できる場合である。その場合は途中で呼んだ Future を投げっぱなしにして、非同期で
IO 処理だけさせてメインスレッドは次に進むということをやって良い。

2 は必要な情報が全部は集まっていないけどとりあえずレスポンスを返さなきゃいけない
ような場面において、呼んだ Future がタイムアウト前に返ってこなければ見捨てるとい
うもの。ある意味同期処理なわけで、基本的にはやってはいけないがタイムアウトという
条件が付いているなら話は別だ。タイムアウト時間とそのイベントハンドラを登録し、
それが呼ばれた時点で対象の Future に対してそれが完了しているか否かを問い合わせ、
完了していれば中身の値を取得して同期的に次の計算に移ることになるので Future
の文脈は消える。戻ってこなかった場合はその Future をキャンセルしておく
(`com.twitter.util.Future` では `raise(new FutureCancelledException)` を呼ぶ)
のがたぶんマナー的に正しい。

twitter/util はこのへんうまく出来ていて、呼んでいる Future が戻ってきたら処理を
続けるとか、あるいは同時に呼んでいるどれかが戻ってきたら処理を続けるみたいな、
イベント駆動な設計になっている。 `select` とか `epoll` といった UNIX
システムコールに関連した話になってくるわけだが、 `com.twitter.util.Future` には
`select` と `poll` という名前そのままの API がある。
`scala.concurrent.Future` にはその手の話はないっぽい？
システムコールレベルではまだあまり使ったことがないので触ってみないと…

## 他人の発表

勉強会での発表というものは自分が勉強するためにあるものであって、自分が勉強したこ
とに比べれば話す内容は他人にとってもわかりやすくするものであると思っていた。だが
他の人達の発表を聞いていても意図的にレベルを落としたように感じられるものはなく、
むしろみんな全力で準備している感じがしてすごかった。
「それ知ってるよ〜」という類のものはほとんどなかったし、自分の到底理解の及ばない
型レベルガチ勢の方々の発表もわかりやすくて面白かった。 LLVM や TaPL, さらには
圏論が一般教養として扱われていた感もあり関数型界隈はレベル高いなあと思った。

## その他

[\@rejasupotaro][rejasupotaro] さんとは以前[第7回若手Webエンジニア交流会
][wakateweb]で少しだけ話したのだが、昨日はより突っ込んだ話をした。
Twitter のオープンソースのコードを読んでいると、 Scala の標準ライブラリに比べて
ケチくさい最適化を頑張っていないように見えるとか、 Twitter をしてもまだ Netty 4
に乗り換えられない感じなんだろうなあとか。結論としてはジャバこそが実用的な言語と
いうことになった。
<blockquote class="twitter-tweet" lang="en"><p>レジャスポ氏に「時代はジャバだ」と力説してしまった <a href="https://twitter.com/search?q=%23functionalLT&amp;src=hash">#functionalLT</a></p>&mdash; matsumoto (@daimatz) <a href="https://twitter.com/daimatz/statuses/465398393276088321">May 11, 2014</a></blockquote><script async src="//platform.twitter.com/widgets.js" charset="utf-8"></script>
帰りで少し一緒になった [\@taiki45][taiki45] さんともそんな話をした。もうちょっと
我々のアプローチがどの程度どうなのかという話とか、他のカイシャさんでそのへんどう
しているのとかいう話を聞きたい気もした。

あとは、今回も Twitter でしか見たことのなかった何人かの人達の存在を確認した。

twitter/util と twitter/finagle 読もうと言いつつ、いやそこそこ読んではいるんだけ
どどうしても finagle のタスクスケジューリング周りがつかめていなくて、困っている
。標準版の Future は FuturePool を直接触る設計になっていて直感的だが、 Twitter
版の Future は finagle を普通に触っている限り FuturePool
というかタスクスケジューラが一切表に出てこない。
裏で謎スケジューリングしていたり、かといえば普通に `ExecutorService`
を作っているところもあったりで、結局どこが実態なのかわかっていない。一人
finagle コードリーディングでも記録に残していくかなーと思っているところ。
関連して twitter/util と netty もある程度読むことになりそう。

[sugoihaskell]: http://sugoihaskell.github.io/
[connpass]: http://connpass.com/event/5795/
[eagletmt]: https://twitter.com/eagletmt
[rejasupotaro]: https://twitter.com/rejasupotaro
[wakateweb]: http://www.zusaar.com/event/3477003
[taiki45]: https://twitter.com/taiki45
[effective-scala-future]: http://twitter.github.io/effectivescala/#Concurrency-Futures
