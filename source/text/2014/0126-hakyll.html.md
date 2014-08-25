---
title: サイト作った
description: Hakyll と Mighttpd で静的サイトを作った話
tags: haskell, website
---

## 作ってみた

もう何番煎じかわからないレベルだけど [Hakyll](http://jaspervdj.be/hakyll/)
と [Mighttpd](http://mew.org/~kazu/proj/mighttpd/) で作ってみた。

Hakyll は Ruby 製の [Jekyll](http://jekyllrb.com/) の Haskell クローンで、
これらは
[静的サイトジェネレータ](https://www.google.co.jp/search?q=%E9%9D%99%E7%9A%84%E3%82%B5%E3%82%A4%E3%83%88%E3%82%B8%E3%82%A7%E3%83%8D%E3%83%AC%E3%83%BC%E3%82%BF&lr=lang_ja)
と呼ばれる類のソフトウェアである。
Hakyll はバックグラウンドに [Pandoc](http://johnmacfarlane.net/pandoc/)
を使っており Pandoc のサポートする書式ならなんでも使える (たぶん) 。
Ruby も好きなので Jekyll を使うのもアリだったが、遠い昔よくわからずに使ってみて
なんだかよくわからんなあという印象が先行してしまったため今回は Hakyll にした。

また Mighttpd (マイティー) は Haskell 製の HTTP サーバで、
[nginx](http://nginx.org/) より
パフォーマンスが出るらしい。ソースコードは1500行程度で非常にシンプル。
今回は使うだけで中身を全然触れていないのだけどそのうちこれも読む。

作成の際には [Hakyll 公式ページ](http://jaspervdj.be/hakyll/) はもちろん、
このネタの日本での第一人者と思われる
[@tanakhさんのページ](http://tanakh.jp/posts/2011-11-05-haskell-infra.html)
も大いに参考にした。

## 経緯など

これまでに何度か自分のブログを作ったことはあった。
最初は [はてなダイアリー](http://d.hatena.ne.jp/) 、次は
[GitHub Pages](http://pages.github.com/) を使ったもので、
最後に [はてなブログ](http://hatenablog.com/) である。
しかしそのどれもが半年〜1年ほどしか続かなかった。
気分を変えるために異なるサービスをいくつか使ってみたが、
結局長続きするものはなかった。

なぜ長続きしなかったのか。
生活環境の変化により文章を書くのが厳しくなったとか、
デザインがみんな同じで気に入らなかったとか、
とか、
そういう話はある。
しかし重要なのは本気度が足りないことだと思った。
エンジニアは常に学ばなければ死んでしまう生き物である。
学ぶ際にはインプットだけではあまり意味がなく、
アウトプットこそが重要であることはよく知られている。
これから自分のドメインを使って
きちんとアウトプットしていくという決意も込めて新しく作ることにした。
自分のお金でやるならきちんと書くだろう。たぶん。
この記事はその第一歩である。

最近大学の後輩たちの間で日記コンテンツを作るのが流行しており、
本サイトもその影響を受けたことは否めない。

## 技術的な話

### Hakyll

ルーティングの書き方など最初は見よう見まねであったが、
しばらくいじると感覚がつかめてくる。
そこで少し複雑な設定も行ったのでそれについて書くことにする。
例えば Hakyll では記事のメタデータを以下のようなフォーマットで
記事の先頭に記述する。

```markdown
----
title: タイトル
description: 概要
published: 2014-01-05
----
```

ここで横着な私は `published` を書くのが面倒くさいと思った。
そこで見てみると、世の Hakyll を使っているサイトには URL が `YYYY-mm-dd`
の形式になっているものが多い。
Hakyll のソースを見てみると確かに `Hakyll.Web.Template.Context.getItemUTC` で
`published` や `date` フィールドがない場合は
ファイル名から読むようになっている。これを使えばいい。
しかし気に入らないのはその形式で、 `YYYY-mm-dd-*` 固定となっているのだ。
すべてのファイルを `YYYY-mm-dd-*` のように配置するのか。これは嫌だ。
例えば年ごとにディレクトリを変えたい、しかし `YYYY/YYYY-mm-dd-*` は冗長だ。

そこでソースを読みつつ `YYYY/mmdd*` の形式にできるようにした。
まず `Hakyll.Web.Template.Context.field` 関数の型は

```haskell
field :: String -> (Item a -> Compiler String) -> Context a
```

となっており、

- 第1引数にテンプレートからアクセスするためのキー名
- 第2引数にその記事から文字列への変換関数

を指定する。
`toFilePath $ itemIdentifier item` でファイルパスが取得できるので、

```haskell
dateField :: String -> Context String
dateField key = field key $ item -> do
    let name = toFilePath $ itemIdentifier item
        dirname = takeDirectory name
        basename = takeBaseName name
        dateString = takeFileName dirname ++ take 4 basename
    ...
```

とすれば、 `*/YYYY/mmdd*` というファイルパスから
`YYYYmmdd` 形式の文字列が得られる。
これをよしなにフォーマットして `return` すればいい。
一応フォーマット文字列も引数に取るようにして、最終的には次のようになった。

```haskell
import Data.Time.Format (formatTime, parseTime)
import System.FilePath (takeBaseName, takeDirectory, takeFileName)
import System.Locale (defaultTimeLocale)

dateField :: String -> String -> Context String
dateField key format = field key $ \item -> do
    let name = toFilePath $ itemIdentifier item
        dirname = takeDirectory name
        basename = takeBaseName name
        dateString = takeFileName dirname ++ take 4 basename
        time :: UTCTime
        time = fromMaybe
            (error $ "file `" ++ name ++ "` doesn't match to format `%Y/%m%d*`")
            (parseTime defaultTimeLocale "%Y%m%d" dateString)
    return $ formatTime defaultTimeLocale format time
```

これを使うには次のように `Context` を指定すれば良い。

```haskell
import Data.Monoid (mconcat)

ctx :: Context String
ctx = mconcat [ dateField "published" "%Y-%m-%d", defaultContext ]
```

また、記事の一覧などのページで `Hakyll.Web.Template.List.recentFirst`
という関数を使いたかったのだがこれも `getItemUTC` を使っているため動かない。
そこで単純にその記事のファイルパスを降順にソートする関数を定義して
それを代わりに使うことにした。

```haskell
import Control.Arrow ((***))
import Control.Monad (join)
import Data.List (sortBy)

recentFirst :: (MonadMetadata m, Functor m) => [Item a] -> m [Item a]
recentFirst = return . sortBy (flip cmp)
  where
    cmp :: Item a -> Item a -> Ordering
    cmp = curry $ uncurry compare . map' (toFilePath . itemIdentifier)
    map' :: (a -> b) -> (a, a) -> (b, b)
    map' = join (***)
```

本当は `description` を書くのも面倒なので、
自動でその記事のタイトルと最初のパラグラフあたりをとってくるようにできないかと
思っている。これは後で試す。

### デザイン

デザインは悩みの種だったが、適当に CSS テンプレートを探して
気に入ったものを使うことにした。

- <http://www.coolwebwindow.com/>
    - 商用サイト向けCSSテンプレート No.16

商用サイト向けと書いてあるが個人でも問題ないようなのでありがたくいただいた。
横幅や文字サイズなど少しだけカスタマイズし、
またソースコードハイライト用の CSS も書いて使っている。

右上に表示しているアイコンはそれぞれ次の 32px のものを使った。
Feed Icons は適当に編集してある。

- [Feed Icons](http://feedicons.com/)
- [Image Resources](https://dev.twitter.com/docs/image-resources) (Twitter 公式)
- [GitHub Logos and Usage](https://github.com/logos) (GitHub 公式)

### サーバ

個人用途の VPS では [さくらの VPS](http://vps.sakura.ad.jp/) が一番安定なのだけ
ど、どうせ静的ファイルを置くだけなので安さをとって
[ServersMan@VPS](http://dream.jp/vps/) にした。安いだけあってなかなか厳しいスペ
ックだけどなんとかなるだろう。ちなみに Mighttpd で立てた HTTP サーバに ab でベン
チとったら 700 QPS くらいだった。まあこんなにアクセスが来ることはたぶんない。

ディストリビューションは CentOS に嫌気がさしていたので Ubuntu で。
ドメインはずっとお金を払いつつもほとんど使っていなかった daimatz.net を使う。

流行の言葉に [Infrastructure as
Code](https://www.google.co.jp/search?q=infrastructure+as+code&lr=lang_ja)
というものがある。
サーバ設定を完全にスクリプトに落としこんでしまい、手作業をなくすという考え方だ。
これまでの経験から自分個人が運用しているサーバは
頻繁にリプレースしたくなるものと思っていたが、
これは「もっとよい構築方法があるはず」とか「設定を整理しておこう」
という意識が働いているからだと思った。
流行に乗ってサーバ設定を完全にコードに落としこんでしまうことにすれば
新しいソフトウェアを使うときが来ても安心である。

サーバ設定ツールとして
[Chef](http://www.getchef.com/chef/),
[Ansible](http://www.ansibleworks.com/),
[Fabric](http://fabfile.org/) を試してきたが、
Fabric が一番手に馴染んだのでそれを使っている。
冪等性とか言われているけど実際完全に冪等性を担保するのは難しいと思っていて、
いっそ冪等性を完全に捨てても使いやすいものを使う方針である。
やっぱ冪等性ほしいわ〜となったときに
[cuisine](https://github.com/sebastien/cuisine) は使うかもしれない。

## まとめのような何か

Hakyll というか Haskell の良いところで型を見れば大体の処理がわかるというのが
あって、今回も大きな困難なく作ることができた。
Scala を最近書いているが Scala にはあまりその文化がないように感じていて、
どうしても実装を見なければいけないことが多いと思う。
というか Scaladoc を見るよりコードを見るほうが早いことが多い。
そのぶんコードを読む習慣がついたのはよかったのだけど、
やはり Haskell の文化が恋しいなあと思うわけです。
あと [ghc-mod](http://www.mew.org/~kazu/proj/ghc-mod/)
がとても使いやすい。 [Vim から使える](https://github.com/eagletmt/ghcmod-vim)
のもすばらしい。

環境作ったのできちんとアウトプットしていこうと思った。
