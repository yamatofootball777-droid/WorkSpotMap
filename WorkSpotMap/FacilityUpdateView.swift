import SwiftUI

struct FacilityUpdateView: View {
    @EnvironmentObject private var store: SpotStore
    @State private var selectedID: UUID?

    private var selected: Spot? {
        store.spots.first(where: { $0.id == selectedID }) ?? store.spots.first
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("これは施設用操作のデモです。MVPでは施設の本人確認・認証・サーバー同期はまだ実装していません。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("更新する施設") {
                    Picker("施設", selection: $selectedID) {
                        ForEach(store.spots) { spot in
                            Text(spot.name).tag(Optional(spot.id))
                        }
                    }
                    .pickerStyle(.menu)
                }
                if let spot = selected {
                    Section("現在の混雑状況") {
                        HStack {
                            Circle().fill(spot.crowd.tint).frame(width: 12, height: 12)
                            Text(spot.crowd.rawValue).bold()
                            Spacer()
                        }
                        ForEach([CrowdLevel.available, .busy, .full], id: \.self) { level in
                            Button {
                                store.update(spot.id, to: level)
                            } label: {
                                HStack {
                                    Circle().fill(level.tint).frame(width: 20, height: 20)
                                    Text(level.rawValue)
                                        .font(.headline)
                                    Spacer()
                                    if spot.crowd == level {
                                        Image(systemName: "checkmark.circle.fill")
                                    }
                                }
                                .padding(.vertical, 10)
                            }
                            .foregroundStyle(level.tint)
                            .accessibilityLabel("混雑状況を\(level.rawValue)に変更")
                        }
                        Button("不明に戻す") { store.update(spot.id, to: .unknown) }
                            .foregroundStyle(.secondary)
                    }
                }
                Section {
                    Text("変更はこの端末内に保存され、下の『空席マップ』タブへ即時反映されます。別端末との共有にはバックエンドが必要です。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("施設側の更新")
            .onAppear { if selectedID == nil { selectedID = store.spots.first?.id } }
        }
    }
}
