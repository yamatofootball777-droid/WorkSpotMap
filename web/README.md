# 空席マップ Web

スマートフォン・タブレット・PCのブラウザ向け静的サイト。`dist/` が配信ファイルです。

- 正方形の地図（最大560px）、固定広告枠、施設管理と検知・履歴タブ
- 新宿・早稲田付近の50架空サンプル、スポンサー大ラベル
- 任意の現在地取得、距離順の3km近隣表示、地図上部の虫眼鏡から駅名検索、種類・1人あたり予算の絞り込みとリセット
- 施設名・メニュー・営業時間・メモ・三段階混雑をlocalStorageに保存
- 個別同意後のみ周辺検知。ページ表示中、精度50m以内、100m進入・150m退出（誤差を考慮）。中断時間は含めない。
- 屋内入店・実際の混雑は確認しない。履歴のサーバー送信なし。再読み込み時は検知オフ。

施設編集は各ブラウザ内のデモで、他の利用者への共有・管理者認証はありません。iOS版からのデータ移行は行いません。

## 外部サービス
MapLibre GL JS 4.7.1（同梱ライセンス）、OpenFreeMap Libertyのベクター地図、Photonの検索APIを使用。
日本語名を優先し、駅・バス停を強調。初期表示は空き施設のみで、条件内の空き施設が画面外なら表示されるまで縮小します。
Photonはユーザーによる検索送信時のみ呼び出し、セッション内キャッシュと連打抑止を使用。無料のデモサービスに可用性保証はありません。利用拡大時は専用プロバイダーへ切り替えてください。
https://openfreemap.org/
https://github.com/komoot/photon

## 検証
`node --check dist/app.js`
`python3 -m http.server 4173 --directory dist`
ブラウザで施設の保存・再読込、駅名検索（新宿駅）、スマホ幅の正方形と固定広告を確認。
実機GPSでの周辺検知は未検証。

初期地点は新宿駅。指定地点から1km以内にあり、絞り込み条件に合う空き施設数を表示します。地図の移動・自動縮小で集計基準は変わりません。価格も架空のデモ値で、詳細画面に表示します。

施設ピンは白い種別マークを内包し、スポンサーのみ大型の縦長ピン内に施設名（最大2行・末尾省略）とPRを追加。先端は施設座標に固定。混雑色・空席のみの初期表示を維持しています。

混み具合の絞り込みは「空きのみ」（初期値・リセット時）、「やや混雑も表示」（空き＋やや混雑）、「全表示」（満席・不明も含む）。1km以内の空き件数は空き施設のみを集計します。

## Facility creation and local crowd estimate prototype
Facility management supports adding a facility with name, address, category and price. Select a Photon address result or enter coordinates. Address lookup sends only the entered address to Photon. Profiles remain local; new facilities start with unknown crowd status.

Reviews (latest one per facility/browser, 60 minutes), going intent (30 minutes), nearby place searches (30 minutes, deduplicated per facility/browser) and separately consented active nearby visits feed an experimental estimate. Reviews are primary; other signals are weak indicators and cannot alone establish occupancy. Recent facility updates take priority for 60 minutes. Legacy sample values are explicitly labelled. Location cannot confirm indoor entry or seating. Weights are uncalibrated.

No server aggregation, multi-user sharing or manager authentication is implemented. All contributions remain in this browser. Location consent resets after reload.

Validation: `node --test tests/crowd-model.test.cjs` covers missing evidence, expiration, future dates, location consent, exits and combined signals. Browser checks cover address selection, creation, reload persistence, review submission, going cancellation and manager override. Physical GPS remains untested.
