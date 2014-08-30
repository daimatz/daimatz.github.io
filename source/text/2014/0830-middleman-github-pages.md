---
title: Middleman と GitHub Pages でブログを作った話
description: 静的サイトジェネレータは Middleman が流行っぽかったのでつかうことにした。GitHub に push したら Travis が勝手にデプロイしてくれるようにした。
tags: ruby, github, travis
---

## tl;dr

- [Middleman][middleman]
- [GitHub Pages][github-pages] のユーザーサイト
- 独自ドメイン使用
- ソースを push すると [Travis CI][travis-ci] がデプロイ

## Middleman

[Middleman][middleman] は最近よく使われている気がする静的サイトジェネレータ。
少し前から静的サイトジェネレータは Middleman 一強感あったので流行に乗り遅れまい
と使ってみることにした。
この種のソフトウェアで Ruby 製のものは古くから [Jekyll][jekyll] が有名でしたが、
Middleman だと Asset Pipeline の概念だったりテンプレートに erb, haml, slim が使
えたりといったところで Rails に近いっぽいところが受けているのだとか。

[公式のチュートリアル][middleman-tutorial]と
、[その日本語版][middleman-tutorial-ja]が充実しているので一通り読めばだいたいの
ことはできる気がします。以下、ハマったところやちょっとしたカスタマイズだけ。

### 後からブログ仕様にする

`middleman init` するときに `--template=blog` を付けずに実行してしまい
(というかこんなオプションがあるのを知らなかった) 、ある程度サイトを作ってからブ
ログ機能をつけることになってしまった。するとブログテンプレートを使った場合の
`config.rb` や他のファイルの中身がわからないので、解説サイトを見ても何のことだか
わからない、ということがあった。

[middleman-blog/lib/middleman-blog/template][middleman-blog-template] にテンプレ
ートファイルが一通り置いてあるので、これをコピーすれば良い。

### VM 内で livereload

[middleman-livereload][middleman-livereload] という拡張があり、これは記事を書い
ている途中に保存すると勝手にブラウザがリロードしてくれるものです。
使っている [rack-livereload][rack-livereload] がファイルの変更を検知して
WebSocket でブラウザ側に伝えて、 JavaScript でリロードとかやっているっぽい。
以前似たようなものを書いたことがあるのであーあんな感じだろうなと想像しつつ。

最近は [Vagrant][vagrant] で全部 VM の中でやるようにしているのですが、
ネットワーク共有をポートフォワードでやっている場合は rack-livereload
のデフォルトである 35729 番をフォワードしておく必要があります。
あと、 middleman のプレビューのデフォルトである 4567 番もフォワードしておきます
。

```ruby
config.vm.network "forwarded_port", guest: 4567, host: 4567 # middleman
config.vm.network "forwarded_port", guest: 35729, host: 35729 # livereload
```

そして `config.rb` に `activate :livereload` を書いておく。すると

```sh
$ middleman
```

と打つと `localhost:4567` でプレビューでき、 livereload もできる。

### 日本語で80行で改行するのを無視する

エディタで書くときは80文字で折り返したいのだけど、日本語の場合それを普通にレンダ
リングさせてブラウザで見ると改行位置で半角スペースが開いてしまう。それが嫌だった
ので、 Markdown レンダリングエンジンをいじって改行を取り除く処理をつけている。
[Redcarpet][redcarpet] での処理。

```ruby
class Redcarpet::Render::HTML
  def preprocess(text)
    text.gsub(/([^\x01-\x7E])\n([^\x01-\x7E])/, '\1\2')
  end
end
```

これを `config.rb` に書いておけば良い。

### シンタックスハイライト

シンタックスハイライトは [Rouge][rouge] を Gemfile に書いておくだけ。
少し使ってみている限りは特に問題なさそう。

## GitHub Pages のユーザーサイト

[GitHub Pages][github-pages] は github.io ドメインで静的なファイルをホスティング
できるサービス。
[User や Organization のページと Project ごとのページの2種類][github-pages-user]
あるが、ここでは個人ページを作ることを想定しているので User & Organization のほ
うを使う。

この場合、 User もしくは Organization に `[user or organization].github.io` とい
うリポジトリを作り、その master ブランチに静的ファイルを push することで
`https://[user or organization].github.io` にアクセスできるようになる。
自分の場合は [daimatz.github.io][daimatz.github.io-repo] とする。

## 独自ドメイン使用

GitHub Pages で独自ドメインを使う場合やることは以下のとおり：

1. DNS レコードの設定
2. `CNAME` ファイルを置く

### DNS レコードの設定

CNAME を設定する方法と A レコードを設定する方法がある。
自分の場合は `daimatz.net` を使いたかったので、
「[apex domain の場合は A レコードを設定せよ][custom-domain-official]」との指示
通り A レコードを設定する。

ググると `204.232.175.78` を使うといい、という情報が見つかるのだが、一度それで
push すると
「その IP アドレスは deprecated なので[公式ページ][custom-domain-official]に書い
てある正しいものを使ってね」というメールが来た。そこから
[A レコードの設定][custom-domain-a-record]ページに飛ぶと、現時点では

- 192.30.252.153
- 192.30.252.154

の2つを使えと書いてある。

自分は VALUE DOMAIN を使っているので DNS 設定ページで次のように記入した。

```
a @ 192.30.252.153
a @ 192.30.252.154
```

### CNAME ファイルを置く

GitHub Pages リポジトリの master ブランチ直下に `CNAME` というファイルを置き、
その中に独自ドメインを書く。
すると、 `http://[user or organization].github.io` にアクセスされたときに
そのドメインにリダイレクトしてくれる。

middleman を使う場合、 `source/` 直下に置いて次のようにするのが良いと思う。

```ruby
page 'CNAME', layout: false
```

## ソースを push すると Travis CI がデプロイ

Travis CI は言わずと知れたクラウド CI サービスですが、これをデプロイに使おうとす
ると少し面倒な設定が必要になる。ビルドログがダダ漏れなので認証情報をそのまま書く
わけにはいかない。

### 認証情報の持ち方

まず Travis が GitHub リポジトリに push できるようにする方法だが、これはアプリケ
ーション登録して Access Token を設定すれば良い。
[自分の設定の Applications ページ][github-settings-application]に行き、 Personal
access tokens の Generate new token からトークンを生成する。

さて、そのトークンを Travis に教える方法だが、このために [Travis CI に暗号化の仕
組みがある][travis-encrypt]。 travis コマンドを使って次のようにする。

```sh
$ gem install travis
$ travis encrypt -r daimatz/daimatz.github.io "GH_TOKEN=<token>"
```

そして `.travis.yml` に次のように書く。

```yml
env:
  global:
    - secure: ".............."
```

すると、ビルド時に復号化した `GH_TOKEN=<token>` が展開される。もちろんビルドログ
には表示されない。

### Travis が master ブランチを push

`[user or organization].github.io` ではデプロイするファイルは master ブランチに
置かなければならない。そこで、ソースはすべて source ブランチに置いておき、
source ブランチを push すると Travis が master ブランチに成果物を commit して
push という手順をとることになる。 master に push する用のリポジトリを build とい
うディレクトリで clone してきて、 `middleman build` したときに build ディレクト
リに入るようにする。具体的には次のような感じ。

```yml
before_script:
    - git clone --quiet https://github.com/daimatz/daimatz.github.io build
script:
    - bundle exec middleman build
after_success:
    - cd build
    - git add -A .
    - git commit -m "Update [ci skip]"
    - '[ "$TRAVIS_BRANCH" == "source" ] && git push --quiet https://$GH_TOKEN@github.com/daimatz/daimatz.github.io master 2> /dev/null'
```

`git push` 時に `--quiet` を付けないとトークンが表示されてしまうので注意。

Travis では[コミットメッセージに
`[ci skip]` という文字列を入れておくと、そのコミットについてはビルドしな
い][travis-ci-skip]。こうしないと Travis が master ブランチに push したコミット
についてまた CI が走ってしまい、 `.travis.yml` がないためビルドが失敗してエラー
メールが飛んでくることになる。

## まとめ

[ソースを見てもらう][daimatz.github.io-source]のが一番わかりやすい気がする。

[github-pages]: https://pages.github.com/
[github-pages-user]: https://help.github.com/articles/user-organization-and-project-pages
[travis-ci]: https://travis-ci.org/
[middleman-blog-template]: https://github.com/middleman/middleman-blog/tree/master/lib/middleman-blog/template
[middleman-livereload]: https://github.com/middleman/middleman-livereload
[rack-livereload]: https://github.com/johnbintz/rack-livereload
[vagrant]: http://vagrantup.com/
[daimatz.github.io-repo]: https://github.com/daimatz/daimatz.github.io
[custom-domain-official]: https://help.github.com/articles/setting-up-a-custom-domain-with-github-pages
[custom-domain-a-record]: https://help.github.com/articles/tips-for-configuring-an-a-record-with-your-dns-provider
[middleman]: http://middlemanapp.com/
[middleman-tutorial]: http://middlemanapp.com/basics/getting-started/
[middleman-tutorial-ja]: http://middlemanapp.com/jp/basics/getting-started/
[jekyll]: http://jekyllrb.com/
[redcarpet]: https://github.com/vmg/redcarpet
[rouge]: https://github.com/jneen/rouge
[github-settings-application]: https://github.com/settings/applications
[travis-encrypt]: http://docs.travis-ci.com/user/encryption-keys/
[daimatz.github.io-source]: https://github.com/daimatz/daimatz.github.io/tree/source
[travis-ci-skip]: http://docs.travis-ci.com/user/how-to-skip-a-build/
