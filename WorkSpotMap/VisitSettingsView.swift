import SwiftUI

struct VisitSettingsView: View {
    @EnvironmentObject private var location: LocationService
    @ObservedObject var history: VisitHistory
    @State private var showConsent = false
    @State private var showDelete = false

    var body: some View {
        NavigationStack {
            List {
                Section("実験的な施設周辺検知") {
                    Text("位置情報の許可とは別に、ここでの同意が必要です。初期状態はオフです。")
                    Text("アプリ表示中のみ、サンプル施設の周辺への進入・退出と滞在時間を推定します。屋内への入店・施設の利用は確認できません。複数施設の範囲が重なることもあります。")
                    Toggle("施設周辺検知に同意する", isOn: Binding(get: { location.consent }, set: { value in
                        if value { showConsent = true } else { location.setConsent(false) }
                    }))
                    Text(location.status).font(.caption)
                    Button("使用中の位置情報を許可・取得") { location.requestNearby() }
                    Text("位置情報の軌跡は保存しません。施設名・開始/終了時刻・推定滞在時間だけを端末内に保存し、バックアップから除外します。サーバー送信・混雑の自動判定は行いません。地図表示・駅名検索ではAppleの地図サービスを利用します。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("開発用訪問履歴（すべてサンプル施設）") {
                    Text("中断時の終了時刻は最後の観測時刻です。実際の退出時刻ではありません。画面非表示・終了中の時間は含めません。")
                        .font(.caption)
                    if let error = history.storageError { Text(error).foregroundStyle(.red) }
                    if history.visits.isEmpty { Text("履歴はありません") }
                    ForEach(history.visits) { visit in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(visit.name).font(.headline)
                            Text("開始: \(visit.startedAt.formatted(date: .abbreviated, time: .standard))")
                            if let end = visit.endedAt {
                                Text("終了: \(end.formatted(date: .abbreviated, time: .standard))")
                            } else { Text("終了: 未確定（最終観測までの時間を表示）") }
                            Text("推定滞在時間: \(Int(visit.duration))秒")
                            Text(visit.endReason ?? "周辺で観測中").foregroundStyle(.secondary)
                        }.font(.caption)
                    }
                    Button("検知を停止して履歴をすべて削除", role: .destructive) { showDelete = true }
                }
            }
            .navigationTitle("検知・開発用履歴")
            .alert("実験的な周辺検知への同意", isPresented: $showConsent) {
                Button("同意して有効にする") { location.setConsent(true) }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("屋内入店は確認できません。アプリ表示中にサンプル施設周辺の進入・退出を推定し、時刻と滞在時間をこの端末だけに保存します。いつでも停止・削除できます。位置情報のOS許可は別途必要です。")
            }
            .alert("履歴をすべて削除しますか？", isPresented: $showDelete) {
                Button("停止して削除", role: .destructive) { location.setConsent(false); history.clear() }
                Button("キャンセル", role: .cancel) {}
            }
        }
    }
}
