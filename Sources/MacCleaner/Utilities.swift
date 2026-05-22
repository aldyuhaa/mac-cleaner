import Foundation

enum ByteFormat {
    static func string(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    static func throughput(_ bytesPerSecond: Int64) -> String {
        "\(string(bytesPerSecond))/s"
    }
}

enum NumberFormat {
    static func percent(_ value: Double, digits: Int = 0) -> String {
        String(format: "%.\(digits)f%%", value)
    }
}

extension Sequence where Element == ScanItem {
    var totalSize: Int64 {
        reduce(0) { $0 + $1.size }
    }
}
