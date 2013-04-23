# PaginatedFeed

Pagination機能付きのRSSやAtomを生成するMovable Typeアプリケーション

## 更新履歴

 * 0.01 (Sat Oct 28 17:58:17 2006 UTC)
   * 初版公開。

## 概要

Movable Typeでは、AtomフィードやRSSフィードを生成する場合、最新の指定個数のエントリーのみを対象にしたフィードを生成するのが一般的です。全エントリーを含むフィードを生成することもできますが、ファイルが巨大なものとなるため、Webサーバやフィードを利用するクライアントプログラム・サービスの負荷が問題となります。

一方で、[OpenSearch](http://www.opensearch.org/Specifications/OpenSearch/1.1)のレスポンスフィード(要素)やGoogle Blogger betaのAtomフィードは、openSearchというXML名前空間を使ったフィードの「Pagination」を実現しています。

PaginatedFeedは、フィードのPaginationを実現し、OpenSearchのレスポンス仕様に準拠したフィードの生成を支援する、Movable Typeアプリケーション(CGIスクリプト)です。言い換えると、PaginatedFeedは以下の機能を提供するものです。

 * 指定したオフセット・件数のエントリーを含んだフィードを動的に生成する機能
 * OpenSearchレスポンスに必要な要素をフィードに追加するのに役立つ、いくつかのテンプレートタグ機能

## インストール方法

パッケージに含まれる以下のファイルをMovable Typeのインストールされているディレクトリにコピーまたはアップロードします。

 * mt-pfeed.cgi
 * extlib/MT/App/PaginatedFeed.pm

CGIスクリプトとして実行できるように、mt-pfeed.cgiに実行パーミッションを与える必要があります。

## 使い方

始めに、PaginatedFeedが使用するフィード用テンプレートモジュールをMovable Type上で作ります。テンプレートは「PFeed: <format>」という名前にする必要があります。

ここではAtomフィードを生成する場合を例にとって説明します。

テンプレートの名前は「PFeed: Atom」、テンプレートの内容は以下のようにします。

    <$MTHTTPContentType type="application/atom+xml"$><?xml version="1.0" encoding="<$MTPublishCharset$>"?>
    <feed xmlns="http://www.w3.org/2005/Atom" xmlns:opensearch="http://a9.com/-/spec/opensearch/1.1/">
       <title><$MTBlogName remove_html="1" encode_xml="1"$></title>
       <link rel="alternate" type="text/html" href="<$MTBlogURL encode_xml="1"$>" />

       <link rel="self" type="application/atom+xml" href="<$MTPaginatedFeedSelfURL encode_xml="1"$>" />
       <link rel="first" href="<$MTPaginatedFeedFirstURL encode_xml="1"$>" type="application/atom+xml" />
       <link rel="last" href="<$MTPaginatedFeedLastURL encode_xml="1"$>" type="application/atom+xml" />
       <MTIfNonEmpty tag="MTPaginatedFeedPreviousURL"><link rel="previous" href="<$MTPaginatedFeedPreviousURL encode_xml="1"$>" type="application/atom+xml" /></MTIfNonEmpty>
       <MTIfNonEmpty tag="MTPaginatedFeedPreviousURL"><link rel="next" href="<$MTPaginatedFeedNextURL encode_xml="1"$>" type="application/atom+xml" /></MTIfNonEmpty>
    
       <opensearch:totalResults><$MTPaginatedFeedTotalResults$></opensearch:totalResults>
       <opensearch:startIndex><$MTPaginatedFeedStartIndex$></opensearch:startIndex>
       <opensearch:itemsPerPage><$MTPaginatedFeedMaxResults$></opensearch:itemsPerPage>
    
       <id>tag:<$MTBlogHost exclude_port="1" encode_xml="1"$>,<$MTDate format="%Y"$>:<$MTBlogRelativeURL encode_xml="1"$>/<$MTBlogID$></id>
       <updated><MTEntries lastn="1"><$MTEntryModifiedDate utc="1" format="%Y-%m-%dT%H:%M:%SZ"$></MTEntries></updated>
       <MTIfNonEmpty tag="MTBlogDescription"><subtitle><$MTBlogDescription remove_html="1" encode_xml="1"$></subtitle></MTIfNonEmpty>
       <generator uri="http://www.sixapart.com/movabletype/"><$MTProductName version="1"$></generator>
    
    <MTPaginatedFeedEntries>
    <entry>
       <title><$MTEntryTitle remove_html="1" encode_xml="1"$></title>
       <link rel="alternate" type="text/html" href="<$MTEntryPermalink encode_xml="1"$>" />
       <id><$MTEntryAtomID$></id>
       <published><$MTEntryDate utc="1" format="%Y-%m-%dT%H:%M:%SZ"$></published>
       <updated><$MTEntryModifiedDate utc="1" format="%Y-%m-%dT%H:%M:%SZ"$></updated>
   
       <summary><$MTEntryExcerpt remove_html="1" encode_xml="1"$></summary>
       <author>
          <name><$MTEntryAuthorDisplayName encode_xml="1"$></name>
          <MTIfNonEmpty tag="MTEntryAuthorURL"><uri><$MTEntryAuthorURL encode_xml="1"$></uri></MTIfNonEmpty>
       </author>
       <MTEntryCategories>
          <category term="<$MTCategoryLabel encode_xml="1"$>" scheme="http://www.sixapart.com/ns/types#category" />
       </MTEntryCategories>
       <MTEntryIfTagged><MTEntryTags><category term="<$MTTagID encode_xml="1"$>" label="<$MTTagName encode_xml="1"$>" scheme="http://www.sixapart.com/ns/types#tag" />
       </MTEntryTags></MTEntryIfTagged>
       <content type="html" xml:lang="<$MTBlogLanguage ietf="1"$>" xml:base="<$MTBlogURL encode_xml="1"$>">
          <$MTEntryBody encode_xml="1" convert_breaks="0"$>
          <$MTEntryMore encode_xml="1" convert_breaks="0"$>
       </content>
    </entry>
    </MTPaginatedFeedEntries>
    </feed>

これはMovable TypeのデフォルトのAtomフィードのテンプレートに以下の変更を施しただけのものです。Atomフィードをカスタマイズしている場合には参考にしてください。

 * feed要素にopenSearch名前空間の宣言を追加。
 * link要素(rel="self")をPaginatedFeedのURLに変更。
 * OpenSearchのレスポンス仕様に準拠したlink要素、openSearch:*要素を追加。
 * MTEntriesコンテナをMTPaginatedFeedEntriesコンテナに変更。

テンプレートで使用できる拡張タグについては「テンプレートタグ」を参照してください。

さてこの作業が済めば、ブラウザから以下のようなURLにアクセスすると動的に生成されたAtomフィードが取得されるはずです。

    http://your.domain.name/mt-dir/mt-pfeed.cgi?blog_id=1&format=Atom

mt-pfeed.cgiに与えるオプションについては「mt-pfeed.cgiスクリプト」の説明を参照してください。

## mt-pfeed.cgiスクリプト

mt-pfeed.cgiは、指定されたIDを持つのブログの、指定されたテンプレートを、動的にレンダリングして表示するものです。

### オプション

このスクリプトは、URL引数として以下に示すオプションをとります。

 * blog_id=<blog_id>: (必須) ブログのIDを指定します。
 * format=<format>: 「PFeed: <format>」という名前のテンプレートをレンダリングすることを指定します。デフォルトでは「Atom」が指定されています(「PFeed: Atom」というテンプレートが使われます)。
 * startIndex=<startIndex>: フィードに表示するエントリーの「開始インデックス」を指定します。エントリーのインデックスは、作成時刻の新しいエントリーから順に1以上の整数が割り当てられています。デフォルトは「1」。
 * maxResults=<maxResults>: フィードに表示するエントリーの「最大表示件数」を指定します。デフォルトは「20」。

### 例

ID 1のブログを「PFeed: Atom」テンプレートを使ってレンダリングして表示するには、以下のURLにアクセスします。

    http://your.domain.name/mt-dir/mt-pfeed.cgi?blog_id=1&format=Atom

同じブログの、10番目のエントリーから50件分を表示するには、以下のURLにアクセスします。

    http://your.domain.name/mt-dir/mt-pfeed.cgi?blog_id=1&format=Atom&startIndex=10&maxResults=50

## テンプレートタグ

PaginatedFeedのテンプレートモジュールでは、通常のMovable Typeのテンプレートタグに加え、以下に示す変数タグとコンテナタグが利用可能です。利用例については「使い方」を参照してください。

### MTPaginatedFeedStartIndex 変数タグ

mt-pfeed.cgiに与えた、エントリーの開始インデックスを表示します。

### MTPaginatedFeedMaxResults 変数タグ

mt-pfeed.cgiに与えた、エントリーの最大表示件数を表示します。

### MTPaginatedFeedTotalResults 変数タグ

エントリーの総件数を表示します。MTBlogEntryCountと同じ機能ですが、多少最適化したものです。

### MTPaginatedFeedSelfURL 変数タグ

現在表示中のフィードのURLを表示します。省略されたオプションを補ったURLとなります。

### MTPaginatedFeedFirstURL 変数タグ

現在表示中のフィードの、最初のページのフィードURLを表示します。

### MTPaginatedFeedLastURL 変数タグ

現在表示中のフィードの、最後のページのフィードURLを表示します。

### MTPaginatedFeedNextURL 変数タグ

現在表示中のフィードの、次のページのフィードURLを表示します。存在しない場合には空白文字が返ります。

### MTPaginatedFeedPreviousURL 変数タグ

現在表示中のフィードの、前のページのフィードURLを表示します。存在しない場合には空白文字が返ります。

### MTPaginatedFeedEntries コンテナタグ

現在表示中のフィードのエントリーをレンダリングするコンテナタグです。

MTPaginatedFeedEntriesコンテナでは、MTEntriesコンテナと同様のタグが利用できます。

## 注意点

このスクリプトはフィード以外のテンプレートを動的にレンダリングして表示する目的に使えます(念のため、Movable Typeにはこの目的のために用意されたmt-view.cgiというスクリプトが付属しています)。ただし、任意のテンプレートを表示できるようにすると、意図しないテンプレートがmt-pfeed.cgi経由で閲覧できてしまうという問題があります。例えば、Master Archive Indexのレンダリングを繰り返し要求することでDoS攻撃が可能になってしまいます。

PaginatedFeedが使用するテンプレートに接頭辞として「PFeed: 」を付けることにしているのは、こうした問題に対処するためです。

この他、If-Modified-Since付きリクエストに対しては、指定された時刻よりエントリーが最後に更新された時刻が新しい場合にだけレンダリングを行い、そうでない場合には304 Not Modifiedを返すようになっています。これにより、サーバのオーバーヘッドとトラフィックの削減が期待されます。

## See Also

## TODO

 * HTTP Compressionに対応する。
 * maxResultsを際限なく大きくするとやっぱりDoS攻撃されてしまうので、まじめに使う場合にはmaxResultsをhard-codedした方がよい。カットオフ値を設けるのがリファレンス実装としてはよいだろう。

## License

This code is released under the Artistic License. The terms of the Artistic License are described at [http://www.perl.com/language/misc/Artistic.html](http://www.perl.com/language/misc/Artistic.html).

## Author & Copyright

Copyright 2006 Hirotaka Ogawa (hirotaka.ogawa at gmail.com)
