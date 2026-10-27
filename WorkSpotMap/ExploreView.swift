import SwiftUI
import MapKit

struct ExploreView: View {
    @EnvironmentObject private var store: SpotStore
    @State private var query = ""
    @State private var camera: MapCameraPosition = .region(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 35.695, longitude: 139.705), span: MKCoordinateSpan(latitudeDelta: 0.065, longitudeDelta: 0.065)))
    @State private var searchResultName = "東京・早稲田付近"
    @State private var selectedCategory: SpotCategory?
    @State private var selectedSpot: Spot?
    @State private var isSearching = false
    @State private var searchError: String?
    @State private var showOnlyAvailable = false
    @State private var visibleRegion: MKCoordinateRegion?

    private var filtered: [Spot] {
        store.spots.filter { spot in
            (selectedCategory == nil || selectedCategory == spot.category) &&
            (!showOnlyAvailable || spot.crowd == .available)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("駅名・地名で探す（例：梅田駅）", text: $query)
                        .textInputAutocapitalization(.never)
                        .submitLabel(.search)
                        .onSubmit { Task { await searchPlace() } }
                        .accessibilityLabel("駅名または地名")
                    if isSearching { ProgressView().controlSize(.small) }
                    Button("検索") { Task { await searchPlace() } }
                        .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSearching)
                }
                .padding(12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        categoryButton(nil, text: "すべて")
                        ForEach(SpotCategory.allCases) { category in
                            categoryButton(category, text: category.rawValue)
                        }
                    }
                    .padding(.horizontal)
                }

                Toggle("空いている施設のみ", isOn: $showOnlyAvailable)
                    .font(.subheadline)
                    .padding(.horizontal)

                GeometryReader { geometry in
                    ZStack(alignment: .top) {
                        Map(position: $camera) {
                            ForEach(filtered) { spot in
                                Annotation("", coordinate: spot.coordinate, anchor: .bottom) {
                                    Button { selectedSpot = spot } label: {
                                        if spot.isSponsored {
                                            VStack(spacing: 4) {
                                                HStack(spacing: 5) {
                                                    Image(systemName: spot.category.symbol)
                                                        .font(.system(size: 19, weight: .bold))
                                                    Text("PR").font(.system(size: 10, weight: .bold))
                                                        .padding(.horizontal, 4).padding(.vertical, 2)
                                                        .background(.white.opacity(0.25), in: Capsule())
                                                }
                                                Text(spot.name)
                                                    .font(.system(size: 11, weight: .bold))
                                                    .lineLimit(1)
                                            }
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 10).padding(.vertical, 9)
                                            .background(spot.crowd.tint, in: RoundedRectangle(cornerRadius: 12))
                                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white, lineWidth: 2))
                                            .shadow(color: .black.opacity(0.25), radius: 5, y: 3)
                                        } else {
                                            Image(systemName: spot.category.symbol)
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundStyle(.white)
                                                .frame(width: 31, height: 31)
                                                .background(spot.crowd.tint, in: Circle())
                                                .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                                                .shadow(radius: 2)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("\(spot.name)、\(spot.crowd.rawValue)\(spot.isSponsored ? "、広告掲載施設" : "")")
                                }
                                .annotationTitles(.hidden)
                            }
                        }
                        .mapControlVisibility(.hidden)
                        .onMapCameraChange(frequency: .onEnd) { context in
                            visibleRegion = context.region
                        }
                        .mapStyle(.standard(pointsOfInterest: .excludingAll))
                        VStack(spacing: 4) {
                            HStack {
                                Image(systemName: "mappin.and.ellipse")
                                Text(searchResultName).lineLimit(1)
                                Spacer()
                                Text("デモ施設 \(filtered.count)件")
                            }
                            .font(.caption)
                            .padding(9)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 9))
                            HStack(spacing: 9) {
                                legend(.available); legend(.busy); legend(.full); legend(.unknown)
                            }
                            .font(.caption2)
                            .padding(7)
                            .background(.regularMaterial, in: Capsule())
                        }
                        .padding(8)
                        VStack {
                            Spacer()
                            Text("※ 架空のサンプル施設です。実際の混雑情報ではありません")
                                .font(.system(size: 10))
                                .padding(5)
                                .background(.regularMaterial, in: Capsule())
                                .padding(.bottom, 8)
                        }
                    }
                    .frame(width: geometry.size.width, height: geometry.size.width)
                    .clipShape(RoundedRectangle(cornerRadius: 13))
                }
                .aspectRatio(1, contentMode: .fit)
                .padding(.horizontal, 8)

                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(Color.teal.opacity(0.13))
                        .frame(width: 62, height: 62)
                        .overlay(Image(systemName: "cup.and.saucer.fill").font(.title2).foregroundStyle(.teal))
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text("広告スペース（サンプル）").font(.subheadline.bold())
                            Text("広告").font(.system(size: 10)).padding(3)
                                .background(Color.gray.opacity(0.14), in: RoundedRectangle(cornerRadius: 3))
                        }
                        Text("作業場所を探している人に向けた広告枠")
                            .font(.caption).foregroundStyle(.secondary)
                        Text("実際の広告配信・課金は未接続")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 13))
                .padding(.horizontal, 8)
                Spacer(minLength: 0)
            }
            .navigationTitle("空席マップ")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selectedSpot) { spot in
                if let current = store.spots.first(where: { $0.id == spot.id }) {
                    SpotDetailView(spot: current)
                        .presentationDetents([.medium, .large])
                }
            }
            .alert("検索できませんでした", isPresented: Binding(get: { searchError != nil }, set: { if !$0 { searchError = nil } })) {
                Button("OK") { searchError = nil }
            } message: { Text(searchError ?? "") }
        }
    }

    private func categoryButton(_ category: SpotCategory?, text: String) -> some View {
        Button(text) { selectedCategory = category }
            .font(.subheadline)
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .background(selectedCategory == category ? Color.teal : Color.gray.opacity(0.12), in: Capsule())
            .foregroundStyle(selectedCategory == category ? Color.white : Color.primary)
    }

    private func legend(_ level: CrowdLevel) -> some View {
        HStack(spacing: 3) {
            Circle().fill(level.tint).frame(width: 7, height: 7)
            Text(level.rawValue)
        }
    }

    private func searchPlace() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isSearching = true
        defer { isSearching = false }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmed
        request.region = visibleRegion ?? MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 36, longitude: 138), span: MKCoordinateSpan(latitudeDelta: 12, longitudeDelta: 15))
        request.resultTypes = [.address, .pointOfInterest]
        do {
            let response = try await MKLocalSearch(request: request).start()
            guard let first = response.mapItems.first else {
                searchError = "該当する場所がありません。地名や駅名を変えてください。"
                return
            }
            camera = .region(.init(center: first.placemark.coordinate, span: .init(latitudeDelta: 0.06, longitudeDelta: 0.06)))
            searchResultName = first.name ?? trimmed
        } catch {
            searchError = "ネットワーク接続を確認して、もう一度検索してください。"
        }
    }
}

struct SpotDetailView: View {
    let spot: Spot

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label(spot.category.rawValue, systemImage: spot.category.symbol)
                    HStack {
                        Text("混雑状況")
                        Spacer()
                        Text(spot.crowd.rawValue)
                            .bold()
                            .foregroundStyle(spot.crowd.tint)
                    }
                    Text(spot.address)
                    Text(spot.note)
                }
                Section("設備") {
                    Label(spot.hasWifi ? "Wi-Fiあり" : "Wi-Fi情報なし", systemImage: "wifi")
                    Label(spot.hasPower ? "電源あり" : "電源情報なし", systemImage: "powerplug")
                }
                Section {
                    Button("Appleマップで開く") {
                        let item = MKMapItem(placemark: MKPlacemark(coordinate: spot.coordinate))
                        item.name = spot.name
                        item.openInMaps()
                    }
                }
            }
            .navigationTitle(spot.name)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
