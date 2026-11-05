import Foundation
import Combine

struct LocalVisit: Identifiable, Codable {
    var id = UUID()
    let spotID: UUID
    let name: String
    let startedAt: Date
    var lastObservedAt: Date
    var endedAt: Date?
    var endReason: String?
    var duration: TimeInterval { max(0, (endedAt ?? lastObservedAt).timeIntervalSince(startedAt)) }
}

@MainActor
final class VisitHistory: ObservableObject {
    @Published private(set) var visits: [LocalVisit] = []
    @Published private(set) var storageError: String?
    private let file: URL

    init(file: URL? = nil) {
        self.file = file ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LocalVisits/history.json")
        do {
            if FileManager.default.fileExists(atPath: self.file.path) {
                visits = try JSONDecoder().decode([LocalVisit].self, from: Data(contentsOf: self.file))
                // Never count time while the process was absent as a visit.
                interrupt(reason: "アプリ終了による中断")
            }
        } catch { storageError = "履歴を読み込めません。履歴を削除してから再開してください。" }
    }

    func observe(id: UUID, name: String, distance: Double, accuracy: Double, at date: Date) {
        guard storageError == nil, accuracy >= 0, accuracy <= 50 else { return }
        if let index = visits.firstIndex(where: { $0.spotID == id && $0.endedAt == nil }) {
            guard date > visits[index].lastObservedAt else { return }
            visits[index].lastObservedAt = date
            // Hysteresis and uncertainty margin prevent boundary jitter.
            if distance - accuracy > 150 {
                visits[index].endedAt = date
                visits[index].endReason = "周辺退出を検知"
            }
        } else if distance + accuracy <= 100 {
            visits.insert(LocalVisit(spotID: id, name: name, startedAt: date, lastObservedAt: date), at: 0)
        } else { return }
        save()
    }

    func interrupt(reason: String) {
        var changed = false
        for index in visits.indices where visits[index].endedAt == nil {
            visits[index].endedAt = visits[index].lastObservedAt
            visits[index].endReason = reason
            changed = true
        }
        if changed { save() }
    }

    func clear() {
        do {
            if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) }
            visits = []
            storageError = nil
        } catch { storageError = "履歴を削除できませんでした。" }
    }

    private func save() {
        do {
            let directory = file.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            var excluded = directory
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try excluded.setResourceValues(values)
            let data = try JSONEncoder().encode(visits)
            #if os(iOS)
            try data.write(to: file, options: [.atomic, .completeFileProtection])
            #else
            try data.write(to: file, options: .atomic)
            #endif
            storageError = nil
        } catch { storageError = "履歴を保存できません。検知を停止して履歴を確認してください。" }
    }
}
