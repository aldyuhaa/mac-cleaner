import AppKit
import Foundation
import SwiftUI

@MainActor
final class MenuBarViewModel: ObservableObject {
    @Published private(set) var snapshot: MonitorSnapshot = .empty
    @Published private(set) var recentActivity: [ActivityEntry] = []
    @Published private(set) var healthSummary = "Checking your Mac"
    @Published var menuBarOnlyModeEnabled: Bool {
        didSet {
            UserDefaults.standard.set(menuBarOnlyModeEnabled, forKey: Self.menuBarOnlyDefaultsKey)
            applyActivationPolicy()
        }
    }

    private static let menuBarOnlyDefaultsKey = "MenuBarOnlyModeEnabled"

    private let cleanerViewModel: CleanerViewModel
    private let activityStore = ActivityStore()
    private let diskMonitor = DiskMonitorService()
    private let memoryMonitor = MemoryMonitorService()
    private let cpuMonitor = CPUMonitorService()
    private let networkMonitor = NetworkMonitorService()
    private let driveMonitor = ExternalDriveMonitorService()

    private var refreshTask: Task<Void, Never>?
    private var networkState: NetworkSnapshotState?
    private var cpuSample: CPUSample?

    init(cleanerViewModel: CleanerViewModel) {
        self.cleanerViewModel = cleanerViewModel
        self.menuBarOnlyModeEnabled = UserDefaults.standard.bool(forKey: Self.menuBarOnlyDefaultsKey)
        refreshRecentActivity()
        refreshSnapshot()
        startRefreshing()
        DispatchQueue.main.async { [weak self] in
            self?.applyActivationPolicy()
        }
    }

    deinit {
        refreshTask?.cancel()
    }

    var diskTitle: String {
        snapshot.disk?.volumeName ?? "Macintosh HD"
    }

    var diskValue: String {
        guard let disk = snapshot.disk else { return "Unavailable" }
        return "Available: \(ByteFormat.string(disk.availableBytes))"
    }

    var diskSecondary: String {
        guard let disk = snapshot.disk else { return "Disk information unavailable" }
        return "\(ByteFormat.string(disk.usedBytes)) used of \(ByteFormat.string(disk.totalBytes))"
    }

    var memoryTitle: String {
        "Memory"
    }

    var memoryValue: String {
        guard let memory = snapshot.memory else { return "Unavailable" }
        return "Pressure: \(NumberFormat.percent(memory.usedRatio * 100, digits: 0))"
    }

    var memorySecondary: String {
        guard let memory = snapshot.memory else { return "Memory information unavailable" }
        return "\(memory.pressureLabel) • \(ByteFormat.string(memory.availableBytes)) free"
    }

    var cpuTitle: String {
        "CPU"
    }

    var cpuValue: String {
        guard let cpu = snapshot.cpu else { return "Unavailable" }
        return "Load: \(NumberFormat.percent(cpu.usagePercent, digits: 0))"
    }

    var cpuSecondary: String {
        "Live processor activity"
    }

    var networkTitle: String {
        snapshot.network.primaryInterfaceName ?? "Network"
    }

    var networkUpload: String {
        "↑ \(ByteFormat.throughput(snapshot.network.uploadBytesPerSecond))"
    }

    var networkDownload: String {
        "↓ \(ByteFormat.throughput(snapshot.network.downloadBytesPerSecond))"
    }

    func startRefreshing() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await MainActor.run {
                    self.refreshSnapshot()
                    self.refreshRecentActivity()
                }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    func quickScan() {
        cleanerViewModel.selectedModule = .cleanup
        cleanerViewModel.scan()
        refreshRecentActivity()
    }

    func prepareMainWindowPresentation() {
        if menuBarOnlyModeEnabled {
            NSApp.setActivationPolicy(.regular)
        }
    }

    func openSpaceLens() {
        cleanerViewModel.selectedModule = .spaceLens
    }

    func showInFinder(_ path: String) {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
    }

    func toggleMenuBarOnlyMode() {
        menuBarOnlyModeEnabled.toggle()
    }

    private func refreshSnapshot() {
        let networkResult = networkMonitor.snapshot(since: networkState)
        networkState = networkResult.1
        let cpuResult = cpuMonitor.snapshot(previous: cpuSample)
        cpuSample = cpuResult.1

        snapshot = MonitorSnapshot(
            timestamp: Date(),
            disk: diskMonitor.systemDiskSnapshot(),
            memory: memoryMonitor.snapshot(),
            cpu: cpuResult.0,
            network: networkResult.0,
            externalDrives: driveMonitor.snapshots()
        )
        updateHealthSummary()
    }

    private func refreshRecentActivity() {
        recentActivity = Array(activityStore.load().prefix(4))
    }

    private func updateHealthSummary() {
        guard let disk = snapshot.disk, let memory = snapshot.memory, let cpu = snapshot.cpu else {
            healthSummary = "Monitoring startup"
            return
        }

        let diskHealthy = disk.availableBytes > 15 * 1024 * 1024 * 1024
        let memoryHealthy = memory.usedRatio < 0.75
        let cpuHealthy = cpu.usagePercent < 90

        if diskHealthy && memoryHealthy && cpuHealthy {
            healthSummary = "Excellent"
        } else if disk.availableBytes > 8 * 1024 * 1024 * 1024
                    && memory.usedRatio < 0.88
                    && cpu.usagePercent < 95 {
            healthSummary = "Good"
        } else {
            healthSummary = "Needs attention"
        }
    }

    private func applyActivationPolicy() {
        guard NSApp != nil else { return }
        NSApp.setActivationPolicy(menuBarOnlyModeEnabled ? .accessory : .regular)
    }

}
