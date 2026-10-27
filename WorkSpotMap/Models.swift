import Foundation
import CoreLocation
import SwiftUI

enum SpotCategory: String, CaseIterable, Identifiable, Codable {
    case cafe = "カフェ"
    case library = "図書館"
    case study = "自習室"
    case coworking = "コワーキング"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .cafe: "cup.and.saucer.fill"
        case .library: "books.vertical.fill"
        case .study: "pencil.and.outline"
        case .coworking: "laptopcomputer"
        }
    }
}

enum CrowdLevel: String, CaseIterable, Codable, Identifiable {
    case available = "空いている"
    case busy = "やや混雑"
    case full = "満席"
    case unknown = "不明"
    var id: String { rawValue }
    var tint: Color {
        switch self {
        case .available: .green
        case .busy: .orange
        case .full: .red
        case .unknown: .gray
        }
    }
}

struct Spot: Identifiable, Codable {
    var id: UUID
    var name: String
    var category: SpotCategory
    var latitude: Double
    var longitude: Double
    var address: String
    var note: String
    var hasWifi: Bool
    var hasPower: Bool
    var crowd: CrowdLevel
    var isSponsored: Bool = false
    var coordinate: CLLocationCoordinate2D { .init(latitude: latitude, longitude: longitude) }
}

// 将来の利用者投稿を追加しやすいように、施設の公式更新と投稿を別データとして設計。
// このMVPは利用者投稿を保存・表示しません。
struct CrowdReport: Identifiable, Codable {
    enum Source: String, Codable { case facility, visitor }
    var id: UUID
    var spotID: UUID
    var level: CrowdLevel
    var source: Source
    var createdAt: Date
}
