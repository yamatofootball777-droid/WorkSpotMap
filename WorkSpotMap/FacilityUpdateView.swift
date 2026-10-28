import SwiftUI

struct FacilityUpdateView: View {
    @EnvironmentObject private var store: SpotStore
    @State private var selectedID: UUID?
    private var selected: Spot? { store.spots.first(where: { $0.id == selectedID }) ?? store.spots.first }

    var body: some View {
        NavigationStack {
            if let spot = selected {
                List {
                    Section {
                        Picker("施設", selection: $selectedID) {
                            ForEach(store.spots) { Text($0.name).tag(Optional($0.id)) }
                        }
                    }
                    Section("混雑状況") {
                        ForEach([CrowdLevel.available, .busy, .full]) { level in
                            Button { store.update(spot.id, to: level) } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: spot.crowd == level ? "checkmark.circle.fill" : "circle")
                                        .font(.title2)
                                    Text(level.rawValue).font(.title3.weight(.semibold))
                                    Spacer()
                                }
                                .foregroundStyle(spot.crowd == level ? .white : level.tint)
                                .padding(.horizontal, 18).frame(minHeight: 72)
                                .background(spot.crowd == level ? level.tint : level.tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("混雑状況を\(level.rawValue)に変更")
                            .accessibilityValue(spot.crowd == level ? "選択中" : "未選択")
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                        }
                        Button("不明に戻す") { store.update(spot.id, to: .unknown) }
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    Section("施設情報") {
                        LabeledContent("名前", value: spot.name)
                        profileRow("メニュー", value: store.profile(for: spot).menu)
                        profileRow("営業時間", value: store.profile(for: spot).hours)
                        profileRow("メモ", value: store.profile(for: spot).memo)
                        NavigationLink("施設情報を編集") {
                            FacilityProfileEditor(spot: spot, profile: store.profile(for: spot))
                        }
                    }
                    Section {
                        Text("この端末内のデモです。変更は地図と施設詳細に反映されます。")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .navigationTitle("施設管理")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .onAppear { if selectedID == nil { selectedID = store.spots.first?.id } }
    }

    private func profileRow(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline)
            Text(value.isEmpty ? "未設定" : value).foregroundStyle(.secondary)
        }.padding(.vertical, 4)
    }
}

private struct FacilityProfileEditor: View {
    @EnvironmentObject private var store: SpotStore
    @Environment(\.dismiss) private var dismiss
    let spot: Spot
    @State var profile: FacilityProfile
    @State private var saveError = false

    var body: some View {
        Form {
            Section("名前") { TextField("施設名", text: $profile.name) }
            Section("メニュー") {
                TextField("季節のメニュー・価格など", text: $profile.menu, axis: .vertical).lineLimit(4...10)
            }
            Section("営業時間") {
                TextField("例：平日 9:00〜18:00／水曜定休", text: $profile.hours, axis: .vertical).lineLimit(2...6)
            }
            Section("メモ") {
                TextField("キャンペーン・臨時休業など", text: $profile.memo, axis: .vertical).lineLimit(4...10)
            }
        }
        .navigationTitle("施設情報")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    if store.saveProfile(profile, for: spot.id) { dismiss() } else { saveError = true }
                }.disabled(profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .alert("保存できませんでした", isPresented: $saveError) { Button("OK", role: .cancel) {} }
    }
}
