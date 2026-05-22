import AppKit
import Foundation
import Darwin
import IOKit.ps

struct JunkScanner {
    private let fileManager = FileManager.default

    func scan() -> [ScanItem] {
        var results: [ScanItem] = []

        for target in scanTargets() {
            guard fileManager.fileExists(atPath: target.url.path) else { continue }
            let children = (try? fileManager.contentsOfDirectory(
                at: target.url,
                includingPropertiesForKeys: [.isDirectoryKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey],
                options: []
            )) ?? []

            for child in children {
                let size = folderSize(at: child)
                guard size > 0 else { continue }
                results.append(ScanItem(
                    name: child.lastPathComponent,
                    url: child,
                    category: target.category,
                    size: size,
                    safety: target.safety
                ))
            }
        }

        return results.sorted { $0.size > $1.size }
    }

    private func scanTargets() -> [(url: URL, category: ScanCategory, safety: SafetyLevel)] {
        let home = fileManager.homeDirectoryForCurrentUser
        return [
            (home.appendingPathComponent("Library/Caches"), .cache, .safe),
            (home.appendingPathComponent("Library/Logs"), .logs, .safe),
            (home.appendingPathComponent(".Trash"), .trash, .safe)
        ]
    }

    private func folderSize(at url: URL) -> Int64 {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return 0 }

        if !isDirectory.boolValue {
            return fileSize(at: url)
        }

        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .isRegularFileKey],
            options: []
        ) else { return 0 }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            total += fileSize(at: fileURL)
        }
        return total
    }

    private func fileSize(at url: URL) -> Int64 {
        let values = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey])
        if let allocated = values?.totalFileAllocatedSize {
            return Int64(allocated)
        }
        if let allocated = values?.fileAllocatedSize {
            return Int64(allocated)
        }
        return 0
    }
}

struct CleanupService {
    private let fileManager = FileManager.default

    func moveToTrash(_ items: [ScanItem]) -> CleanupResult {
        var movedIDs: Set<UUID> = []
        var bytes: Int64 = 0
        var failures: [CleanupFailure] = []

        for item in items where item.safety != .protected {
            do {
                var resultingURL: NSURL?
                try fileManager.trashItem(at: item.url, resultingItemURL: &resultingURL)
                movedIDs.insert(item.id)
                bytes += item.size
            } catch {
                failures.append(CleanupFailure(name: item.name, path: item.url.path, reason: error.localizedDescription))
            }
        }

        return CleanupResult(movedIDs: movedIDs, bytes: bytes, failures: failures)
    }

    func moveApplicationsToTrash(_ apps: [AppInventoryItem]) -> CleanupResult {
        var movedIDs: Set<UUID> = []
        var bytes: Int64 = 0
        var failures: [CleanupFailure] = []

        for app in apps {
            if isApplicationRunning(app) {
                failures.append(CleanupFailure(
                    name: app.name,
                    path: app.url.path,
                    reason: "This app is currently open. Quit it first, then try uninstall again."
                ))
                continue
            }

            do {
                var resultingURL: NSURL?
                try fileManager.trashItem(at: app.url, resultingItemURL: &resultingURL)
                movedIDs.insert(app.id)
                bytes += app.size
            } catch {
                failures.append(CleanupFailure(
                    name: app.name,
                    path: app.url.path,
                    reason: uninstallFailureReason(for: error)
                ))
            }
        }

        return CleanupResult(movedIDs: movedIDs, bytes: bytes, failures: failures)
    }

    func moveLeftoversToTrash(_ leftovers: [AppLeftoverItem]) -> CleanupResult {
        var movedIDs: Set<UUID> = []
        var bytes: Int64 = 0
        var failures: [CleanupFailure] = []

        for leftover in leftovers where leftover.safety != .protected {
            do {
                var resultingURL: NSURL?
                try fileManager.trashItem(at: leftover.url, resultingItemURL: &resultingURL)
                movedIDs.insert(leftover.id)
                bytes += leftover.size
            } catch {
                failures.append(CleanupFailure(name: leftover.name, path: leftover.url.path, reason: error.localizedDescription))
            }
        }

        return CleanupResult(movedIDs: movedIDs, bytes: bytes, failures: failures)
    }

    private func isApplicationRunning(_ app: AppInventoryItem) -> Bool {
        NSWorkspace.shared.runningApplications.contains { runningApp in
            if let bundleIdentifier = app.bundleIdentifier, !bundleIdentifier.isEmpty {
                return runningApp.bundleIdentifier == bundleIdentifier
            }
            return runningApp.bundleURL?.path == app.url.path
        }
    }

    private func uninstallFailureReason(for error: Error) -> String {
        let nsError = error as NSError

        if nsError.domain == NSCocoaErrorDomain {
            if nsError.code == NSFileWriteNoPermissionError || nsError.code == NSFileNoSuchFileError {
                return "macOS denied this uninstall. Try again from Finder with admin authentication."
            }
        }

        if nsError.domain == NSPOSIXErrorDomain {
            if nsError.code == Int(EACCES) || nsError.code == Int(EPERM) {
                return "Permission denied by macOS. Use Finder and authenticate with your password."
            }
        }

        return nsError.localizedDescription
    }
}

struct ApplicationScanner {
    private let fileManager = FileManager.default

    func scanApplications() -> [AppInventoryItem] {
        let locations = [
            URL(fileURLWithPath: "/Applications"),
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
        ]

        var apps: [AppInventoryItem] = []
        for location in locations {
            let children = (try? fileManager.contentsOfDirectory(
                at: location,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )) ?? []

            for app in children where app.pathExtension == "app" {
                apps.append(AppInventoryItem(
                    name: app.deletingPathExtension().lastPathComponent,
                    url: app,
                    size: folderSize(at: app),
                    bundleIdentifier: Bundle(url: app)?.bundleIdentifier
                ))
            }
        }

        return apps.sorted { $0.size > $1.size }
    }

    func scanLeftovers(installedApps: [AppInventoryItem]) -> [AppLeftoverItem] {
        let installedSignatures = appSignatures(for: installedApps)
        let targets = leftoverTargets()
        var leftovers: [AppLeftoverItem] = []

        for target in targets {
            guard fileManager.fileExists(atPath: target.url.path) else { continue }

            let children = (try? fileManager.contentsOfDirectory(
                at: target.url,
                includingPropertiesForKeys: [.isDirectoryKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey],
                options: [.skipsHiddenFiles]
            )) ?? []

            for child in children where isLeftoverCandidate(child, installedSignatures: installedSignatures) {
                let size = folderSize(at: child)
                guard size > 0 else { continue }

                leftovers.append(AppLeftoverItem(
                    name: child.lastPathComponent,
                    url: child,
                    category: target.category,
                    size: size,
                    appHint: appHint(for: child),
                    safety: target.safety
                ))
            }
        }

        return leftovers.sorted { $0.size > $1.size }
    }

    private func folderSize(at url: URL) -> Int64 {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return 0 }

        if !isDirectory.boolValue {
            return fileSize(at: url)
        }

        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            let values = try? fileURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey])
            total += Int64(values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? 0)
        }
        return total
    }

    private func fileSize(at url: URL) -> Int64 {
        let values = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey])
        return Int64(values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? 0)
    }

    private func leftoverTargets() -> [(url: URL, category: String, safety: SafetyLevel)] {
        let home = fileManager.homeDirectoryForCurrentUser
        return [
            (home.appendingPathComponent("Library/Caches"), "Cache", .safe),
            (home.appendingPathComponent("Library/Logs"), "Logs", .safe),
            (home.appendingPathComponent("Library/Saved Application State"), "Saved State", .safe),
            (home.appendingPathComponent("Library/Application Support"), "Application Support", .caution),
            (home.appendingPathComponent("Library/Preferences"), "Preferences", .caution),
            (home.appendingPathComponent("Library/Containers"), "Container", .caution)
        ]
    }

    private func appSignatures(for apps: [AppInventoryItem]) -> Set<String> {
        var signatures = Set<String>()

        for app in apps {
            signatures.insert(normalized(app.name))
            if let bundleIdentifier = app.bundleIdentifier {
                signatures.insert(bundleIdentifier.lowercased())
                signatures.insert(normalized(bundleIdentifier))
            }
        }

        signatures.insert("maccleaner")
        return signatures.filter { $0.count > 2 }
    }

    private func isLeftoverCandidate(_ url: URL, installedSignatures: Set<String>) -> Bool {
        let rawName = url.deletingPathExtension().lastPathComponent.lowercased()
        let normalizedName = normalized(rawName)

        guard !rawName.hasPrefix("com.apple"),
              !rawName.hasPrefix("group.com.apple"),
              !normalizedName.hasPrefix("apple"),
              normalizedName.count > 2 else {
            return false
        }

        for signature in installedSignatures {
            if rawName == signature || rawName.hasPrefix("\(signature).") || rawName.contains(signature) {
                return false
            }

            if normalizedName == signature || normalizedName.contains(signature) || signature.contains(normalizedName) {
                return false
            }
        }

        return true
    }

    private func appHint(for url: URL) -> String {
        let name = url.deletingPathExtension().lastPathComponent
        let parts = name.split(separator: ".")
        guard parts.count > 1 else { return name }
        return parts.suffix(2).joined(separator: ".")
    }

    private func normalized(_ value: String) -> String {
        value.lowercased().filter { $0.isLetter || $0.isNumber }
    }
}

struct SpaceLensScanner {
    private let fileManager = FileManager.default

    func scanFolder(_ folder: URL, limit: Int = 40) -> [SpaceLensItem] {
        let children = (try? fileManager.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.isDirectoryKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )) ?? []

        return children
            .map { child in
                SpaceLensItem(
                    name: child.lastPathComponent,
                    url: child,
                    size: folderSize(at: child),
                    isDirectory: isDirectory(at: child)
                )
            }
            .filter { $0.size > 0 }
            .sorted { $0.size > $1.size }
            .prefix(limit)
            .map { $0 }
    }

    private func folderSize(at url: URL) -> Int64 {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return 0 }

        if !isDirectory.boolValue {
            return fileSize(at: url)
        }

        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return 0 }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            total += fileSize(at: fileURL)
        }
        return total
    }

    private func fileSize(at url: URL) -> Int64 {
        let values = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey])
        return Int64(values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? 0)
    }

    private func isDirectory(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }
}

struct ActivityStore {
    private let fileManager = FileManager.default

    private var storeURL: URL? {
        guard let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return support.appendingPathComponent("MacCleaner", isDirectory: true).appendingPathComponent("activity.json")
    }

    func load() -> [ActivityEntry] {
        guard let storeURL, fileManager.fileExists(atPath: storeURL.path) else { return [] }
        guard let data = try? Data(contentsOf: storeURL) else { return [] }
        return (try? JSONDecoder().decode([ActivityEntry].self, from: data)) ?? []
    }

    func save(_ entries: [ActivityEntry]) {
        guard let storeURL else { return }
        do {
            try fileManager.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(Array(entries.prefix(100)))
            try data.write(to: storeURL, options: [.atomic])
        } catch {
            // Activity persistence should never block cleanup or scanning.
        }
    }
}

struct DiskMonitorService {
    private let fileManager = FileManager.default

    func systemDiskSnapshot() -> SystemDiskSnapshot? {
        let home = fileManager.homeDirectoryForCurrentUser
        let values = try? home.resourceValues(forKeys: [.volumeNameKey])
        let attributes = try? fileManager.attributesOfFileSystem(forPath: home.path)
        let total = (attributes?[.systemSize] as? NSNumber)?.int64Value ?? 0
        let available = (attributes?[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
        guard total > 0 else { return nil }

        return SystemDiskSnapshot(
            volumeName: values?.volumeName ?? "System Disk",
            mountPath: home.path,
            totalBytes: total,
            availableBytes: available
        )
    }
}

struct MemoryMonitorService {
    func snapshot() -> MemorySnapshot? {
        let total = Int64(ProcessInfo.processInfo.physicalMemory)
        guard total > 0 else { return nil }

        var pageSize: vm_size_t = 0
        host_page_size(mach_host_self(), &pageSize)
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return nil }

        let pageBytes = Int64(pageSize)
        // Match utility-style pressure: exclude inactive cache, which macOS can reclaim.
        let pressure = pageBytes * Int64(stats.active_count + stats.wire_count + stats.compressor_page_count)
        let available = pageBytes * Int64(stats.free_count + stats.inactive_count)

        return MemorySnapshot(
            totalBytes: total,
            pressureBytes: min(total, max(0, pressure)),
            cachedAvailableBytes: min(total, max(0, available))
        )
    }
}

struct CPUMonitorService {
    func snapshot(previous: CPUSample?) -> (CPUSnapshot?, CPUSample?) {
        guard let current = sample() else { return (nil, previous) }
        guard let previous else {
            return (CPUSnapshot(usagePercent: 0), current)
        }

        let totalDelta = max(1, current.totalTicks - previous.totalTicks)
        let activeDelta = max(0, current.activeTicks - previous.activeTicks)
        let usage = min(100, max(0, (Double(activeDelta) / Double(totalDelta)) * 100))
        return (CPUSnapshot(usagePercent: usage), current)
    }

    private func sample() -> CPUSample? {
        var info = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }

        let ticks = Mirror(reflecting: info.cpu_ticks).children.compactMap { $0.value as? UInt32 }
        guard ticks.count == 4 else { return nil }
        let user = UInt64(ticks[0])
        let system = UInt64(ticks[1])
        let idle = UInt64(ticks[2])
        let nice = UInt64(ticks[3])

        return CPUSample(
            activeTicks: user + system + nice,
            totalTicks: user + system + idle + nice
        )
    }
}

struct NetworkMonitorService {
    private let excludedPrefixes = ["lo", "utun", "awdl", "llw", "bridge"]

    func snapshot(since previous: NetworkSnapshotState?) -> (NetworkSnapshot, NetworkSnapshotState) {
        let now = Date()
        let counters = interfaceCounters()
        let preferred = counters
            .sorted { ($0.rx + $0.tx) > ($1.rx + $1.tx) }
            .first

        guard let previous,
              let current = preferred,
              previous.interfaceName == current.name else {
            let current = preferred
            return (
                NetworkSnapshot(
                    uploadBytesPerSecond: 0,
                    downloadBytesPerSecond: 0,
                    primaryInterfaceName: current?.displayName
                ),
                NetworkSnapshotState(
                    timestamp: now,
                    interfaceName: current?.name,
                    displayName: current?.displayName,
                    rxBytes: Int64(current?.rx ?? 0),
                    txBytes: Int64(current?.tx ?? 0)
                )
            )
        }

        let interval = max(0.5, now.timeIntervalSince(previous.timestamp))
        let rxDelta = max(0, Int64(current.rx) - previous.rxBytes)
        let txDelta = max(0, Int64(current.tx) - previous.txBytes)

        return (
            NetworkSnapshot(
                uploadBytesPerSecond: Int64(Double(txDelta) / interval),
                downloadBytesPerSecond: Int64(Double(rxDelta) / interval),
                primaryInterfaceName: current.displayName
            ),
            NetworkSnapshotState(
                timestamp: now,
                interfaceName: current.name,
                displayName: current.displayName,
                rxBytes: Int64(current.rx),
                txBytes: Int64(current.tx)
            )
        )
    }

    private func interfaceCounters() -> [(name: String, displayName: String, rx: UInt64, tx: UInt64)] {
        var addressPointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addressPointer) == 0, let first = addressPointer else { return [] }
        defer { freeifaddrs(addressPointer) }

        var results: [(String, String, UInt64, UInt64)] = []
        var pointer = first

        while true {
            let ifa = pointer.pointee
            let name = String(cString: ifa.ifa_name)
            let isUp = (ifa.ifa_flags & UInt32(IFF_UP)) != 0
            let isRunning = (ifa.ifa_flags & UInt32(IFF_RUNNING)) != 0

            if isUp, isRunning,
               !excludedPrefixes.contains(where: { name.hasPrefix($0) }),
               let data = ifa.ifa_data?.assumingMemoryBound(to: if_data.self).pointee {
                results.append((name, displayName(for: name), UInt64(data.ifi_ibytes), UInt64(data.ifi_obytes)))
            }

            if let next = ifa.ifa_next {
                pointer = next
            } else {
                break
            }
        }

        return results
    }

    private func displayName(for interface: String) -> String {
        if interface.hasPrefix("en") { return "Wi-Fi / Ethernet" }
        return interface.uppercased()
    }
}

struct ExternalDriveMonitorService {
    private let fileManager = FileManager.default

    func snapshots() -> [ExternalDriveSnapshot] {
        let keys: [URLResourceKey] = [
            .volumeNameKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey,
            .volumeIsRemovableKey,
            .volumeIsInternalKey,
            .isVolumeKey
        ]

        let volumes = fileManager.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) ?? []

        return volumes.compactMap { url -> ExternalDriveSnapshot? in
            guard let values = try? url.resourceValues(forKeys: Set(keys)),
                  values.isVolume == true else { return nil }

            let isInternal = values.volumeIsInternal ?? false
            let isRemovable = values.volumeIsRemovable ?? false
            guard !isInternal || isRemovable else { return nil }

            let total = Int64(values.volumeTotalCapacity ?? 0)
            let importantAvailable = values.volumeAvailableCapacityForImportantUsage.map { Int64($0) }
            let fallbackAvailable = values.volumeAvailableCapacity.map { Int64($0) }
            let available = importantAvailable ?? fallbackAvailable ?? 0
            guard total > 0 else { return nil }

            return ExternalDriveSnapshot(
                id: url.path,
                name: values.volumeName ?? url.lastPathComponent,
                mountPath: url.path,
                totalBytes: total,
                availableBytes: available,
                isRemovable: isRemovable
            )
        }
        .sorted { $0.usedBytes > $1.usedBytes }
    }
}

struct NetworkSnapshotState {
    let timestamp: Date
    let interfaceName: String?
    let displayName: String?
    let rxBytes: Int64
    let txBytes: Int64
}

struct CPUSample {
    let activeTicks: UInt64
    let totalTicks: UInt64
}
