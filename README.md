# WorkSpotMap — 空席マップ v2 (SwiftUI / MapKit)

## 起動
Xcode 16以降で `WorkSpotMap.xcodeproj` を開き、iOS 17以上のシミュレータでRun。実機は自分の署名チームを設定してください。

## v1から維持
- 新宿・早稲田付近の架空サンプル50件、カテゴリと混雑フィルター
- スポンサーの大きな名前付きPRピン、正方形地図、仮広告
- 駅名・地名検索、施設詳細、施設用デモの混雑編集と既存保存キー

## v2
- 「現在地」を押したときだけ使用中の位置情報許可を要求。拒否しても駅名検索可能。
- 現在地を地図に表示し、3km以内のサンプル施設を距離順に表示。カテゴリ・空席フィルターも適用。
- 「検知・履歴」タブで、OS許可とは別に説明と確認を経て実験的検知へ同意。初期値オフ。いつでも撤回・全履歴削除可能。
- アプリ表示中だけ、50サンプル施設周辺への進入・退出を推定。入店、施設利用、実在施設の混雑を確認する機能ではありません。
- 開始時刻・終了時刻・推定滞在時間・終了理由を端末のApplication Supportに保存。位置軌跡は保存しません。ファイル保護を使用し、履歴ディレクトリをバックアップから除外。
- 開発用履歴画面はv2の検証用としてDebug/Releaseの両方に表示。

## 検知の仕様と限界
`CLLocationManager` の通常位置更新を使用。Always許可、バックグラウンド位置取得、OSジオフェンスは使用しません。
精度50m以内かつ「正確な位置情報」の場合のみ検知。施設までの距離＋誤差が100m以内で開始、距離−誤差が150mを超えると退出。範囲内で有効化した場合も最初の観測で開始します。複数施設の重なりは複数履歴になり得ます。
画面非表示、許可取消、精度不足、取得エラーで中断。次の観測まで60秒を超える間隔があれば中断して新しい観測として扱います。中断時は最後の観測時刻で終了し、実際の退出時刻とは区別します。アプリ強制終了後も次回起動時に同様に処理します。継続中の滞在時間は最終観測までで、時計だけで延長しません。

位置情報・訪問履歴の独自サーバー送信、混雑自動判定、実広告配信は未実装です。地図・駅名検索・Appleマップで開く操作はAppleの地図サービスを利用します。サンプルのない地域に実在施設は追加しません。

## 検証
```sh
xcodebuild -project WorkSpotMap.xcodeproj -scheme WorkSpotMap -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build
xcodebuild -project WorkSpotMap.xcodeproj -scheme WorkSpotMap -sdk iphoneos -configuration Release CODE_SIGNING_ALLOWED=NO build
swiftc WorkSpotMap/VisitHistory.swift Tests/VisitHistoryChecks.swift -o /tmp/workspot-visit-checks
/tmp/workspot-visit-checks
```
履歴テスト: 精度、進入退出境界、重複、時刻の逆行、中断、再起動、バックアップ除外、削除、破損データ保護。

手動確認:
1. 初回起動で許可ダイアログが出ないこと。50件・PR・正方形地図・広告・施設編集があること。
2. 現在地を押して拒否し、駅名「新宿駅」で検索できること。
3. シミュレータで位置をサンプル付近に設定して使用中許可。近隣一覧と現在地表示を確認。同意前は履歴が増えないこと。
4. 同意確認のキャンセルではオフ、明示同意後は範囲内で履歴開始。100m/150mの境界と誤差余裕を考慮して移動し退出・時間を確認。
5. 画面非表示、再起動、許可取消、精度低下で退出ではなく中断になること。同意撤回後は増えないこと。削除後の再起動で復元されないこと。
6. 実機のGPS精度、電池消費、移動時の検知は別途フィールドテストが必要。

位置情報APIの根拠: [Appleの使用中許可](https://developer.apple.com/documentation/corelocation/cllocationmanager/requestwheninuseauthorization())、[位置更新](https://developer.apple.com/documentation/corelocation/cllocationmanager/startupdatinglocation())。

## v2.1 施設管理と画面整理
- 地図画面の上部タイトル・検索欄を削除。地図を先頭にし、検索・カテゴリ・空席フィルターは地図下の検索ボタンから開きます。
- 「施設管理」タブで空いている／やや混雑／満席を大きなボタンで更新。
- 名前、季節メニューなどの自由文、営業時間、キャンペーン・臨時休業メモを編集して保存。地図の施設名と詳細に反映。
- 施設情報はこの端末のみに保存。実施設の管理者認証・別端末への公開は未接続です。
- 既存の50サンプル、PRピン、広告、任意の位置情報・同意制履歴を維持。

施設情報の保存・既存v1データ移行の検証:
```sh
swiftc WorkSpotMap/Models.swift WorkSpotMap/FacilityProfile.swift WorkSpotMap/SpotStore.swift Tests/FacilityProfileChecks.swift -o /tmp/workspot-profile-checks
/tmp/workspot-profile-checks
```

## 固定する画面方針
- 地図は必ず正方形（縦横比1:1）。全画面の縦長・横長地図には変更しません。
- 広告はスクロール領域の外、下部タブの上に固定。検索・現在地の操作や地図のスクロールで画面外に流れません。
- 広い画面では地図の最大幅を560ptに抑えて中央配置。狭い画面では利用可能幅に合わせて正方形を縮小します。
- 画面の高さが足りない場合も広告領域を先に確保し、地図側をスクロールできます。
- 地図サービスの選択より見やすさを優先。ただし現在のアプリはiOS/iPadOS用であり、Android・Web対応を追加したわけではありません。
