import Foundation

@main
struct VisitHistoryChecks {
    @MainActor static func main() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("history.json")
        let history = VisitHistory(file: file)
        let id = UUID(), now = Date()
        func observe(_ distance: Double, _ seconds: Double, accuracy: Double = 10) {
            history.observe(id: id, name: "Sample", distance: distance, accuracy: accuracy, at: now.addingTimeInterval(seconds))
        }
        observe(0, 0, accuracy: 100)
        assert(history.visits.isEmpty, "Poor accuracy must not start a visit")
        observe(95, 0)
        assert(history.visits.isEmpty, "Uncertainty crossing entry boundary must not start")
        observe(80, 0)
        observe(80, 0)
        observe(120, 30)
        assert(history.visits.count == 1 && history.visits[0].endedAt == nil)
        observe(155, 40)
        assert(history.visits[0].endedAt == nil, "Uncertain exit must remain open")
        observe(170, 60)
        assert(history.visits[0].duration == 60 && history.visits[0].endReason == "周辺退出を検知")
        observe(50, 80)
        observe(50, 90)
        observe(50, 85)
        assert(history.visits[0].duration == 10, "Out-of-order updates must not regress time")
        history.interrupt(reason: "同意撤回による中断")
        assert(history.visits[0].duration == 10 && history.visits[0].endedAt == now.addingTimeInterval(90))
        observe(50, 100)
        observe(50, 110)
        let restored = VisitHistory(file: file)
        assert(restored.visits.count == 3)
        assert(restored.visits[0].endReason == "アプリ終了による中断" && restored.visits[0].duration == 10)
        let backup = try directory.resourceValues(forKeys: [.isExcludedFromBackupKey])
        assert(backup.isExcludedFromBackup == true)
        restored.clear()
        assert(restored.visits.isEmpty && !FileManager.default.fileExists(atPath: file.path))
        try Data("broken".utf8).write(to: file)
        let corrupted = VisitHistory(file: file)
        assert(corrupted.storageError != nil)
        corrupted.observe(id: id, name: "Sample", distance: 0, accuracy: 10, at: now)
        assert(corrupted.visits.isEmpty, "Do not overwrite unreadable data")
        corrupted.clear()
        assert(corrupted.storageError == nil)
        print("PASS: accuracy, hysteresis, duplicates, timestamps, interruption, persistence, backup exclusion, deletion, corruption")
    }
}
