import Foundation
import SwiftUI

enum CleanerModule: String, CaseIterable, Identifiable {
    case smartCare = "Smart Care"
    case cleanup = "Cleanup"
    case applications = "Applications"
    case spaceLens = "Space Lens"
    case activity = "Activity"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .smartCare: "sparkles"
        case .cleanup: "trash.circle.fill"
        case .applications: "app.gift.fill"
        case .spaceLens: "scope"
        case .activity: "clock.arrow.circlepath"
        }
    }

    var title: String { rawValue }

    var subtitle: String {
        switch self {
        case .smartCare: "Quick maintenance for everyday Mac cleanup."
        case .cleanup: "Review safe junk and reclaim disk space."
        case .applications: "Inspect apps and prepare for leftover cleanup."
        case .spaceLens: "Find what takes the most room on your storage."
        case .activity: "Track scans and cleanup actions."
        }
    }

    var colors: [Color] {
        switch self {
        case .smartCare: [.purple, .pink, .indigo]
        case .cleanup: [.green, .teal, .black]
        case .applications: [.blue, .cyan, .indigo]
        case .spaceLens: [.indigo, .purple, .black]
        case .activity: [.teal, .blue, .black]
        }
    }

    var backgroundPalette: [Color] {
        switch self {
        case .smartCare:
            [
                Color(red: 0.51, green: 0.12, blue: 0.67),
                Color(red: 0.74, green: 0.16, blue: 0.80),
                Color(red: 0.95, green: 0.24, blue: 0.57),
                Color(red: 0.94, green: 0.27, blue: 0.34),
                Color(red: 0.37, green: 0.40, blue: 0.88)
            ]
        case .cleanup:
            [
                Color(red: 0.06, green: 0.48, blue: 0.26),
                Color(red: 0.10, green: 0.76, blue: 0.44),
                Color(red: 0.06, green: 0.80, blue: 0.74),
                Color(red: 0.03, green: 0.62, blue: 0.74),
                Color(red: 0.02, green: 0.15, blue: 0.16)
            ]
        case .applications:
            [
                Color(red: 0.15, green: 0.28, blue: 0.72),
                Color(red: 0.18, green: 0.45, blue: 0.88),
                Color(red: 0.08, green: 0.72, blue: 0.90),
                Color(red: 0.07, green: 0.36, blue: 0.78),
                Color(red: 0.04, green: 0.11, blue: 0.35)
            ]
        case .spaceLens:
            [
                Color(red: 0.33, green: 0.36, blue: 0.78),
                Color(red: 0.53, green: 0.38, blue: 0.90),
                Color(red: 0.83, green: 0.20, blue: 0.84),
                Color(red: 0.67, green: 0.17, blue: 0.71),
                Color(red: 0.13, green: 0.03, blue: 0.18)
            ]
        case .activity:
            [
                Color(red: 0.02, green: 0.53, blue: 0.56),
                Color(red: 0.03, green: 0.66, blue: 0.78),
                Color(red: 0.06, green: 0.53, blue: 0.91),
                Color(red: 0.10, green: 0.41, blue: 0.78),
                Color(red: 0.04, green: 0.12, blue: 0.25)
            ]
        }
    }
}

enum ScanCategory: String, CaseIterable, Identifiable {
    case cache = "User Cache"
    case logs = "User Logs"
    case trash = "Trash"
    case applications = "Applications"
    case largeFiles = "Large Files"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .cache: "externaldrive.fill.badge.timemachine"
        case .logs: "doc.text.fill"
        case .trash: "trash.fill"
        case .applications: "app.fill"
        case .largeFiles: "folder.fill"
        }
    }
}

enum SafetyLevel: String {
    case safe = "Safe"
    case caution = "Review"
    case protected = "Protected"

    var color: Color {
        switch self {
        case .safe: .green
        case .caution: .yellow
        case .protected: .red
        }
    }
}

struct ScanItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let url: URL
    let category: ScanCategory
    let size: Int64
    let safety: SafetyLevel

    var displayPath: String { url.path }
}

struct CleanupFailure: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let path: String
    let reason: String
}

struct CleanupResult {
    let movedIDs: Set<UUID>
    let bytes: Int64
    let failures: [CleanupFailure]

    var movedCount: Int { movedIDs.count }
}

struct ActivityEntry: Identifiable, Codable {
    let id: UUID
    let date: Date
    let title: String
    let detail: String
    let bytes: Int64

    init(id: UUID = UUID(), date: Date, title: String, detail: String, bytes: Int64) {
        self.id = id
        self.date = date
        self.title = title
        self.detail = detail
        self.bytes = bytes
    }
}

struct AppInventoryItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let url: URL
    let size: Int64
    let bundleIdentifier: String?
}

struct AppLeftoverItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let url: URL
    let category: String
    let size: Int64
    let appHint: String
    let safety: SafetyLevel

    var displayPath: String { url.path }
}

struct SpaceLensItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let url: URL
    let size: Int64
    let isDirectory: Bool

    var displayPath: String { url.path }
}

struct SystemDiskSnapshot: Equatable {
    let volumeName: String
    let mountPath: String
    let totalBytes: Int64
    let availableBytes: Int64

    var usedBytes: Int64 {
        max(0, totalBytes - availableBytes)
    }

    var usageRatio: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes)
    }
}

struct MemorySnapshot: Equatable {
    let totalBytes: Int64
    /// Active app memory: active + wired + compressed pages.
    let pressureBytes: Int64
    /// Reclaimable memory: free + inactive cache.
    let cachedAvailableBytes: Int64

    var availableBytes: Int64 {
        cachedAvailableBytes
    }

    var usedRatio: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(pressureBytes) / Double(totalBytes)
    }

    var pressureLabel: String {
        switch usedRatio {
        case ..<0.45: return "Light"
        case ..<0.70: return "Moderate"
        default: return "High"
        }
    }
}

struct CPUSnapshot: Equatable {
    let usagePercent: Double
}

struct NetworkSnapshot: Equatable {
    let uploadBytesPerSecond: Int64
    let downloadBytesPerSecond: Int64
    let primaryInterfaceName: String?
}

struct ExternalDriveSnapshot: Identifiable, Equatable {
    let id: String
    let name: String
    let mountPath: String
    let totalBytes: Int64
    let availableBytes: Int64
    let isRemovable: Bool

    var usedBytes: Int64 {
        max(0, totalBytes - availableBytes)
    }

    var usageRatio: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes)
    }
}

struct MonitorSnapshot: Equatable {
    let timestamp: Date
    let disk: SystemDiskSnapshot?
    let memory: MemorySnapshot?
    let cpu: CPUSnapshot?
    let network: NetworkSnapshot
    let externalDrives: [ExternalDriveSnapshot]

    static let empty = MonitorSnapshot(
        timestamp: .distantPast,
        disk: nil,
        memory: nil,
        cpu: nil,
        network: NetworkSnapshot(uploadBytesPerSecond: 0, downloadBytesPerSecond: 0, primaryInterfaceName: nil),
        externalDrives: []
    )
}
