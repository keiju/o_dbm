= o_dbm.rb - オブジェクト指向データベース風 Object Base dbm
		      Keiju ISHITSUKA(keiju@ishitsuka.com)

== 使い方

+ ObjectDBM.new(db, adapter = ObjectDBM::DBM_Adapter)
ObjectDBMを作成します. adapterでどの物理DBMを用いるか指定します. 以下のアダ
プタが用意されています

  DBM_Adapter: DBMを用いる
  GDBM_Adapter: GDBMを用いる
  SDBM_Adapter: SDBMを用いる
  PHash_Adapter: フラットファイルを用いる(pstoreと同じフォーマット)
  VDB: 仮想データベースを用いる(実際にはファイルに書き込まず, メモリ上
       だけ処理を行う)

デフォルトでは, DBMを用います.

+ ObjectDBM#[key, mode = nil]
keyに関連づけられたオブジェクトを返します. mode は

  nil:			キャッシュを用い. キャッシュを優先する.
  ObjectDBM::UPDATE:	物理データベースから読み込みます.
  ObjectDBM::NO_CACHING	キャッシュに登録しません.

があります. デフォルトはnilです.

+ ObjectDBM#update(key, obj)
objが省略されたとき:
  keyに関連づけられたオブジェクトを物理DBに書き込むように指定します.
objが指定されたとき:
  objを物理DBに書き込むように指定します

+ ObjectDBM#[key]=(obj)
objをkeyに関連づけてDBに書き込むように指定します.

+ ObjectDBM#delete(key)
keyに関連づけられたobjを削除するように指定します.

+ ObjectDBM#indexes(*keys)/ObjectDBM#indeces(*keys)
keys関連づけられたobjの配列を返します.

+ ObjectDBM#root_names/ObjectDBM#keys
登録されているkeyの配列を返します.

+ ObjectDBM#size
登録されているkeyの数を返します.

+ ObjectDBM#roots(mode = nil)/ObjectDBM#values(mode = nil)
登録されているルートオブジェクトを返します. modeは:

  nil:			  読み込みキャッシュに登録しません
  ObjectDBM::UPDATE:	  読み込んだオブジェクトを書き込み指定します.
  ObjectDBM::READ_CACHING 読み込みキャッシュに登録します

です. デフォルトはnilに指定されています.

+ ObjectDBM#has_root_name?(root_name, mode = SCAN_DB)
キーとしてroot_nameが登録されているか調べます. modeは:

  ObjextDBM::SCAN_DB	      物理データベースをスキャンします
  ObjextDBM::SCAN_CACHE_ONLY  読み込みキャッシュのみチェックします

デフォルトはSCAN_DBです

+ ObjectDBM#root_name?/include?/key?

ObjectDBM#has_root_name?()とおなじです.

+ ObjectDBM#has_root?(root, mode = SCAN_DB){...}

rootがDBに登録されているか, 登録するようにしていされているかどうかを調べ
ます. iteratorとして呼ばれたときは, 比較をiteratorを用いて行います.

mode:
  ObjextDBM::SCAN_DB	      物理データベースをスキャンします
  ObjextDBM::SCAN_CACHE_ONLY  読み込みキャッシュのみチェックします
  ObjextDBM::SCAN_DB_ONLY     物理データベースのみチェックします

デフォルトはSCAN_DBです.

+ ObjectDBM#root?
  has_root?と同じです

+ ObjectDBM#each(mode = nil){|key, value| ...}
keyとvalueを引数としてブロックを評価します.

mode:
  nil			      読み込みキャッシュに登録しません.
  ObjectDBM::UPDATE:	      読み込んだオブジェクトを書き込み指定します.
  ObjectDBM::READ_CACHING     読み込みキャッシュに登録します
  ObjextDBM::SCAN_CACHE_ONLY  読み込みキャッシュのみスキャンします
  ObjextDBM::SCAN_DB_ONLY     物理データベースのみスキャンします

デフォルトは@default_caching_modeです.

+ ObjectDBM#each_pair

ObjectDBM#eachと同じです.

+ ObjectDBM#each_root_name(mode = nil){|key| ...}

keyを引数としてブロックを評価します.

mode:
  nil			      読み込みキャッシュに登録しません.
  ObjectDBM::UPDATE:	      読み込んだオブジェクトを書き込み指定します.
  ObjectDBM::READ_CACHING     読み込みキャッシュに登録します
  ObjextDBM::SCAN_CACHE_ONLY  読み込みキャッシュのみスキャンします
  ObjextDBM::SCAN_DB_ONLY     物理データベースのみスキャンします

デフォルトは@default_caching_modeです.

+ ObjectDBM#each_key

ObjectDBM#each_root_nameと同じです.

+ ObjectDBM#each_root(mode = nil){|obj| ...}
objを引数としてブロックを評価します.

mode:
  nil			      読み込みキャッシュに登録しません.
  ObjectDBM::UPDATE:	      読み込んだオブジェクトを書き込み指定します.
  ObjectDBM::READ_CACHING     読み込みキャッシュに登録します
  ObjextDBM::SCAN_CACHE_ONLY  読み込みキャッシュのみスキャンします
  ObjextDBM::SCAN_DB_ONLY     物理データベースのみスキャンします

デフォルトは@default_caching_modeです.

+ ObjectDBM#each_value
ObjectDBM#each_rootと同じです.

+ ObjectDBM#transaction(mode = READ_CACHING){...}

イテレータとして呼ばれたときには, 静的トランザクションを開始します. イテ
レータが正常に終了したときにはコミットします. つまり, 上位トランザクショ
ンへ変更を反映します. 最上位トランザクションの場合はデータベースに反映し
ます. 最後にデータベースをクローズします.

イテレータでないときには動的トランザクションを開始します. modeは
default_caching_modeの指定です.

+ ObjectDBM#current_transaction

現在のトランザクションを返します.

+ ObjectDBM#commit(txn)

トランザクションtxnをコミットします. つまり, 上位トランザクションへ変更
を反映します. 最上位トランザクションの場合はデータベースに反映します. ま
た, トランザクションtxnの下位トランザクションもコミットされます. 最後に
データベースをクローズします.

+ ObjectDBM#flush(txn)

トランザクションtxnのチェックポイントを実行します. ここまでの変更結果を
上位のトランザクションに反映します. 最上位の場合はデータベースに書き込み
ます. データベースは閉じません.

+ ObjectDBM#abort(txn)
これまでの変更結果を破棄します. トランザクションtxnの下位トランザクショ
ンもアボートされます.

+ StaticTransaction#abort(value = nil)
これまでの変更結果を破棄します. トランザクションブロックからも抜け出します。

+ StaticTransaction#checkpoint
トランザクションtxnのチェックポイントを実行します. すなわち, ここまでの
変更結果を上位のトランザクションに反映します. 最上位の場合はデータベース
に書き込みます. データベースは閉じません.

+ DynamicTransaction#commit
トランザクションtxnをコミットします. つまり, 上位トランザクションへ変更
を反映します. 最上位トランザクションの場合はデータベースに反映します. デー
タベースをクローズします.

+ DynamicTransaction#checkpoint
トランザクションtxnのチェックポイントを実行します. ここまでの変更結果を
上位のトランザクションに反映します. 最上位の場合はデータベースに書き込み
ます. データベースは閉じません.

+ DynamicTransaction#abort
これまでの変更結果を破棄します.
