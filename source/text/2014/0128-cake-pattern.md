---
title: Cake Pattern を理解する
description: Scala で有名な Dependency Injection のデザインパターンである Cake Pattern を理解する
tags: scala, oop
---

## オブジェクト指向とテストについて

私はオブジェクト指向や特に自動テスト周りの実務経験に乏しいわけですが、最近になっ
てようやくテストをきちんと書いたりテストファーストによって良い設計になるみたいな
実感を得たりしています。長らくテストを書かない文化にいたので、注意しないとすぐに
モノリシックな設計になってしまい、後から「テスト書くのどうすんだこれ」みたいにな
ってしまうことも多い。

で、最近 Dependency Injection という依存性をうまいこと抽象化しておく仕組みについ
て学んだので、その Scala における代表的なデザインパターンである Cake Pattern で
実装した話です。

## Dependency Injection

依存性の注入とか訳される、依存しているオブジェクトを直接クラスの中に持っておくの
ではなくコンストラクタとかで受け取れるようにして依存性を分離しておく仕組みです。
例えば Twitter のボットアプリケーションを想定した次のようなコード

```scala
object TwitterService {
  def tweet(text: String, inReplyTo: Option[Int]): Int = { ... }
  def getTimeline(count: Int): Seq[Status] = { ... }
}
object TwitterBot {
  def eventLoop() { ... }
}
```

において、 `TwitterBot` オブジェクトは `TwitterService` オブジェクトに依存してい
ます。ここで

- `TwitterService.tweet(text, inReplyTo)` はツイートした結果発言 ID を返す
- `TwitterService.getTimeline(count)` はタイムラインの最新 `count` 件を取得する

ものとします。例が適当なため登場していないが実際他にもいろんなオブジェクトに依存
していることでしょう。

ここで `TwitterService` はシングルトンとして定義されており、例えば次のように
`TwitterBot` で利用されています。

```scala
object TwitterBot {
  def eventLoop() {
    val statusIds = action(10)
    ...
    Thread.sleep(60 * 1000)
  }
  def action(count: Int): Seq[Int] = {
    val tl = TwitterService.getTimeline(count)
    tl.map { status: Status =>
      TwitterService.tweet("@" + status.userId + " おやすみ〜", Some(status.id))
    }
  }
}
```

さてこの実装には問題があります。この場合、 `TwitterService` が直接
`TwitterBot` に出てきているため、これをモックして一時的に振る舞いを変えるという
ことができないのです。すると `TwitterBot` を単体テストしようとしても必然的に
`TwitterService` の動作を前提としてしまうため単体テストできません。単体テストが
できないとすべてを結合して粒度の大きなテストしかできなくなるため、問題が起きたと
きに問題の切り分けが難しくなります。この例はまだ単純だからよいのですが、他にもい
ろんなオブジェクトに依存しているとすると依存オブジェクト一つ一つを調べなければな
らないため、問題箇所の特定が難しくなるのです。

ではどうするのかというと、依存性を抽象的に宣言しておいてそのインターフェイスに対
してメッセージを呼ぶということをやります。具体的には次のようにします。

```scala
trait TwitterService {
  def tweet(text: String, inReplyTo: Option[Int]): Int
  def getTimeline(count: Int): Seq[Status]
}

class TwitterBot(twitterService: TwitterService) {
  def eventLoop() {
    val statusIds = action(10)
    ...
    Thread.sleep(60 * 1000)
  }
  def action(count: Int): Seq[Int] = {
    val tl = twitterService.getTimeline(count)
    tl.map { status: Status =>
      twitterService.tweet("@" + status.userId + " おやすみ〜", Some(status.id))
    }
  }
}
```

`TwitterService` がトレイトになり、 `TwitterBot` がクラスになってコンストラクタ
に `TwitterService` のインスタンスを取るようになりました。注目すべきは、コンスト
ラクタに渡している `twitterService` は `TwitterService` トレイトのオブジェクトで
あると言っているだけで、その具体的な実装クラスは指定されていないことです。

こうすると、 `TwitterBot` クラスの単体テストにはモックした `TwitterService` のイ
ンスタンスを渡せば良くなり、依存しているオブジェクトの振る舞いを一時的に変えると
いうことができるようになります。

これを使った `TwitterBot` クラスの単体テストは次のように書けます。
[Mockito][Mockito] と [specs2][specs2] を使った例。

```scala
import org.mockito._
import org.specs2.mutable._

class TwitterBotSpec extends Specification {
  val twitterService = Mockito.mock(classOf[TwitterService])
  val twitterBot = new TwitterBot(twitterService)
  "action" should {
    "return status ids" in {
      val status1 = Status(id = 1, userId = "foo", text = "Hello")
      val status2 = Status(id = 2, userId = "bar", text = "Scala")
      val statuses = Seq(status1, status2)
      Mockito.when(twitterService.getTimeline(2)).thenReturn(statuses)
      val id1 = 100
      val id2 = 102
      Mockito.when(twitterService.tweet("@foo おやすみ〜", Some(1))).thenReturn(id1)
      Mockito.when(twitterService.tweet("@bar おやすみ〜", Some(2))).thenReturn(id2)
      twitterBot.action(2) must_== Seq(id1, id2)
    }
  }
}
```

この例では `new TwitterBot(twitterService)` としてモックしたオブジェクトを注入し
ており、さらにテストケース内では `Mockito` の機能を使って `twitterService` オブ
ジェクトの振る舞いをモックしています。 `TwitterBot.action` メソッドのテストが、
依存しているオブジェクトをうまくモックした状態で実行できているのがわかります。

このように、あるクラスが依存している別のオブジェクトを、そのクラス内で直接インス
タンス化せず、後から注入 (inject) できるような設計にしておきます。テストの際には
依存しているオブジェクトのところに挙動を適宜モック・スタブしたオブジェクトを渡せ
ば、依存オブジェクトの振る舞いを一時的に固定することができ、テストしやすくなる。
これを Dependency Injection といいます。

## 自分型アノテーション

Cake Pattern では Scala の自分型アノテーション (self-type annotation) という機能
を使います。これはクラスを定義するときに自分の型をそのクラス以外にもできるという
ものです。

```scala
trait A { def print(x: String) = println(x) }
trait B { val x: String }
class C {
  // 自分の型は A と B をミクスインしたものである
  self: A with B =>
  def f() = print(x)
}
```

のようにすると、 `C` は外からはただの `C` として見えますが、自分の中からはトレイ
ト `A` と `B` をミクスインしているとみなせます。 `B.x` の具体的な実装は書いてい
ませんがコンパイルは通ります。ただし、 `C` をインスタンス化するときに問題が起こ
ります。

```scala
scala> val c = new C
<console>:10: error: class C cannot be instantiated because it does not conform to its self-type C with A with B
scala> val c = new C with A with B
<console>:10: error: object creation impossible, since value x in trait B of type String is not defined
```

`B.x` が定義されていないためインスタンスを作成できないと出ます。そこでミクスイン
のときに `B.x` を定義してやります。

```scala
scala> val c = new C with A with B { val x: String = "Hello" }
scala> c.f
Hello
```

(`A` と `B` を両方不完全な実装にしておくと似たような構文
`new C with A { def print() { ... } } with B { val x = ... }` でインスタンス化す
ることはできませんでした。これできるのか？)

これ何が嬉しいのという話なんですが、外からは `C` として見えるが実は `A` と `B`
に依存しているというのが表せるのです。「`C` というクラスが `A` と `B` に依存して
いて、かつその依存している実装を後から指定できる」というわけです。 Dependency
Injection の臭いがしてきました。

## Cake Pattern

さて、ようやく Cake Pattern に入ります。以下は
[実戦での Scala: Cake パターンを用いた Dependency Injection (DI)][cake-original]
を参考にしたものです。

ユーザーを表すケースクラスとそれを扱うクラスを定義します。

```scala
case class User(name: String, email: String)

class UserRepository {
  def authenticate(user: User): User = {
    println("authenticating: " + user)
    user
  }
  def create(user: User) = println("creating: " + user)
  def delete(user: User) = println("deleting: " + user)
}
```

ここで `UserRepository` クラスは単にユーザーを扱う関数を集めている名前空間の役割
しかないため、 `object` として定義したくなる。しかし後のために普通のクラスとして
定義しています。

次にもう少しユーザーを扱うために抽象化されているはずである `UserService` を定義
します。

```scala
object UserService {
  def authenticate(name: String, email: String): User =
    UserRepository.authenticate(User(name, email))
  def create(name: String, email: String) =
    UserRepository.create(User(name, email))
  def delete(user: User) =
    UserRepository.delete(user)
}
```

上で見たとおり、ここで `UserRepository` に依存しているとテストしにくくなります。
そこで `UserRepository` を注入してほしいオブジェクトとしておくのでした。

```scala
class UserService {
  def authenticate(name: String, email: String): User =
    userRepository.authenticate(User(name, email))
  def create(name: String, email: String) =
    userRepository.create(User(name, email))
  def delete(user: User) =
    userRepository.delete(user)
}
```

`userRepository` はここでは定義されていませんが、これが注入してほしいオブジェク
トであることを覚えておきます。さて、ここからまず `UserRepository` を名前空間トレ
イトに包みます。ここで `userRepository` は後から注入されるべきオブジェクトとして
宣言だけしておきます。

```scala
trait UserRepositoryComponent {
  val userRepository: UserRepository
  class UserRepository {
    def authenticate(user: User): User = {
      println("authenticating user: " + user)
      user
    }
    def create(user: User) = println("creating user: " + user)
    def delete(user: User) = println("deleting user: " + user)
  }
}
```

同じく `UserService` を名前空間トレイト `UserServiceComponent` に包みますが、そ
こで `UserRepositoryComponent` に依存していることを自分型アノテーションで示しま
す。

```scala
trait UserServiceComponent {
  self: UserRepositoryComponent =>
  val userService: UserService
  class UserService {
    def authenticate(username: String, password: String): User =
      userRepository.authenticate(username, password)
    def create(username: String, password: String) =
      userRepository.create(new User(username, password))
    def delete(user: User) = userRepository.delete(user)
  }
}
```

最後に、これらのトレイトを継承した環境トレイトを作ります。ここでは実際にアプリケ
ーションに使うものを `RealWorld` としました。そしてそのトレイト内で
`UserRepositoryComponent` と `UserServiceComponent` をインスタンス化して保持して
おきます。

```scala
trait RealWorld
  extends UserRepositoryComponent
  with UserServiceComponent {
  val userRepositoryComponent = new UserRepositoryComponent
  val userServiceComponent = new UserServiceComponent
}
```

こうしておくと、 `Main` オブジェクトで `RealWorld` を継承するだけでアプリケーシ
ョン用のコードを書くことができます。すべての依存性が `RealWorld` トレイトに集ま
っているのがわかります。

```scala
object Main extends RealWorld {
  def main(args: Array[String]) {
    ...
  }
}
```

また、テスト時には次のようにすべての依存性をモックした `TestEnvironment` を使う
ことができます。

```scala
trait TestEnvironment
  extends UserRepositoryComponent
  with UserServiceComponent {
  val userRepositoryComponent = mock[UserRepositoryComponent]
  val userServiceComponent = mock[UserServiceComponent]
}
```

そして、単体テストしたいクラスは実際にインスタンス化して試すとよいでしょう。

```scala
class UserServiceSpec extends Specification with TestEnvironment {
  override val userService = new UserService
  ...
}
```

実際に動く完全なコードは一番下に GitHub へのリンクを置いておきました。これを見る
とうまいこと依存性を分離して保管できており、しかもテスト時にもうまくモックできて
いることがわかります。

## 考察

自分型アノテーションを使うところ、べつに
`UserServiceComponent extends UserRepositoryComponent` と書いても問題なく動くの
だけど、自分型アノテーションを使うのは環境トレイトを作るときに依存性を見やすくす
ることが目的だろうか。つまり

```scala
trait UserRepositoryComponent {
  ...
}

trait UserServiceComponent extends UserRepositoryComponent {
  ...
}

trait RealWorld extends UserServiceComponent {
  val userRepositoryComponent = ...
  val userServiceComponent = ...
}
```

と書いても問題なく動くのだが、それより

```scala
trait UserRepositoryComponent {
  ...
}

trait UserServiceComponent {
  self: UserRepositoryComponent =>
  ...
}

trait RealWorld
  extends UserRepositoryComponent
  with UserServiceComponent {
  val userRepositoryComponent = ...
  val userServiceComponent = ...
}
```

と書くほうが `RealWorld` が `extends` しているトレイトと注入している依存性が一対
一に対応するぶん見やすい。

あと Haskell で似たようなことできないかなーと思って探してみたら予想通り型クラス
を使った [それっぽい論文][implicit-configurations] を見つけたのでそのうち読む。

## まとめ

今回書いたコードは GitHub にまとめておいた。 `TwitterBot` の例も Cake Pattern で
書いてみたよ！といっても同じことを繰り返しただけだけど…

- [daimatz/CakePattern][cake-pattern-repository]

[Mockito]: https://code.google.com/p/mockito/
[specs2]: http://etorreborre.github.io/specs2/
[cake-original]: http://eed3si9n.com/ja/real-world-scala-dependency-injection-di
[gist]: https://gist.github.com/daimatz/8503238
[implicit-configurations]: http://www.cs.rutgers.edu/~ccshan/prepose/prepose.pdf
[cake-pattern-repository]: https://github.com/daimatz/CakePattern
