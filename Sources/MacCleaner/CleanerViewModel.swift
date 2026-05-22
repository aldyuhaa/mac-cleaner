import AppKit
import Foundation

@MainActor
final class CleanerViewModel: ObservableObject {
    @Published var selectedModule: CleanerModule = .smartCare
    @Published var scanItems: [ScanItem] = []
    @Published var selectedItemIDs: Set<UUID> = []
    @Published var selectedApplicationIDs: Set<UUID> = []
    @Published var selectedLeftoverIDs: Set<UUID> = []
    @Published var activity: [ActivityEntry] = []
    @Published var applications: [AppInventoryItem] = []
    @Published var applicationLeftovers: [AppLeftoverItem] = []
    @Published var spaceLensItems: [SpaceLensItem] = []
    @Published var expandedSpaceLensIDs: Set<UUID> = []
    @Published var spaceLensChildren: [UUID: [SpaceLensItem]] = [:]
    @Published var loadingSpaceLensChildrenIDs: Set<UUID> = []
    @Published var selectedSpaceLensURL: URL?
    @Published var isScanning = false
    @Published var isScanningSpaceLens = false
    @Published var showingCleanupConfirmation = false
    @Published var showingApplicationUninstallConfirmation = false
    @Published var showingLeftoverCleanupConfirmation = false
    @Published var statusMessage = "Ready to scan"
    @Published var lastOperationTitle = ""
    @Published var lastOperationFailures: [CleanupFailure] = []

    private let scanner = JunkScanner()
    private let cleanupService = CleanupService()
    private let applicationScanner = ApplicationScanner()
    private let spaceLensScanner = SpaceLensScanner()
    private let activityStore = ActivityStore()

    init() {
        activity = activityStore.load()
    }

    var selectedItems: [ScanItem] {
        scanItems.filter { selectedItemIDs.contains($0.id) }
    }

    var totalFoundSize: Int64 {
        scanItems.totalSize
    }

    var selectedSize: Int64 {
        selectedItems.totalSize
    }

    var selectedApplications: [AppInventoryItem] {
        applications.filter { selectedApplicationIDs.contains($0.id) }
    }

    var selectedApplicationsSize: Int64 {
        selectedApplications.reduce(0) { $0 + $1.size }
    }

    var selectedLeftovers: [AppLeftoverItem] {
        applicationLeftovers.filter { selectedLeftoverIDs.contains($0.id) }
    }

    var selectedLeftoversSize: Int64 {
        selectedLeftovers.reduce(0) { $0 + $1.size }
    }

    var totalLeftoversSize: Int64 {
        applicationLeftovers.reduce(0) { $0 + $1.size }
    }

    var totalReviewSize: Int64 {
        totalFoundSize + totalLeftoversSize
    }

    var lastActivityTitle: String {
        activity.first?.title ?? "No activity yet"
    }

    var safeLeftovers: [AppLeftoverItem] {
        applicationLeftovers.filter { $0.safety == .safe }
    }

    var cautionLeftovers: [AppLeftoverItem] {
        applicationLeftovers.filter { $0.safety == .caution }
    }

    var scanButtonTitle: String {
        if selectedModule == .cleanup && !selectedItems.isEmpty {
            return "Clean All"
        }
        if selectedModule == .applications && !selectedApplications.isEmpty {
            return "Uninstall"
        }
        if selectedModule == .applications && !selectedLeftovers.isEmpty {
            return "Remove"
        }
        return "Scan"
    }

    func scan() {
        isScanning = true
        statusMessage = "Scanning safe user cleanup locations..."
        lastOperationFailures = []
        lastOperationTitle = ""

        Task {
            let foundItems = scanner.scan()
            let foundApps = applicationScanner.scanApplications()
            let foundLeftovers = applicationScanner.scanLeftovers(installedApps: foundApps)
            scanItems = foundItems
            applications = foundApps
            applicationLeftovers = foundLeftovers
            selectedItemIDs = Set(foundItems.filter { $0.safety == .safe }.map(\.id))
            selectedApplicationIDs = []
            selectedLeftoverIDs = []
            isScanning = false
            statusMessage = "Found \(ByteFormat.string(foundItems.totalSize)) junk and \(ByteFormat.string(foundLeftovers.reduce(0) { $0 + $1.size })) leftovers"
            activity.insert(ActivityEntry(
                date: Date(),
                title: "Scan completed",
                detail: "\(foundItems.count) cleanup items, \(foundApps.count) apps, \(foundLeftovers.count) leftovers",
                bytes: foundItems.totalSize + foundLeftovers.reduce(0) { $0 + $1.size }
            ), at: 0)
            saveActivity()
        }
    }

    func toggleSelection(for item: ScanItem) {
        if selectedItemIDs.contains(item.id) {
            selectedItemIDs.remove(item.id)
        } else if item.safety != .protected {
            selectedItemIDs.insert(item.id)
        }
    }

    func requestCleanup() {
        guard !selectedItems.isEmpty else {
            statusMessage = "Select at least one item to clean"
            return
        }
        showingCleanupConfirmation = true
    }

    func performPrimaryAction() {
        if selectedModule == .cleanup && !selectedItems.isEmpty {
            requestCleanup()
        } else if selectedModule == .applications && !selectedApplications.isEmpty {
            requestApplicationUninstall()
        } else if selectedModule == .applications && !selectedLeftovers.isEmpty {
            requestLeftoverCleanup()
        } else {
            scan()
        }
    }

    func cleanSelectedConfirmed() {
        let items = selectedItems
        guard !items.isEmpty else {
            statusMessage = "Select at least one item to clean"
            return
        }

        let result = cleanupService.moveToTrash(items)
        scanItems.removeAll { result.movedIDs.contains($0.id) }
        selectedItemIDs.subtract(result.movedIDs)
        recordFailures(result.failures, title: "Cleanup issues")

        if result.failures.isEmpty {
            statusMessage = "Moved \(result.movedCount) items to Trash: \(ByteFormat.string(result.bytes))"
        } else {
            statusMessage = "Moved \(result.movedCount) items. \(result.failures.count) failed."
        }

        activity.insert(ActivityEntry(
            date: Date(),
            title: "Cleanup completed",
            detail: "Moved \(result.movedCount) items to Trash",
            bytes: result.bytes
        ), at: 0)
        saveActivity()
    }

    func toggleApplicationSelection(for app: AppInventoryItem) {
        selectedLeftoverIDs = []
        if selectedApplicationIDs.contains(app.id) {
            selectedApplicationIDs.remove(app.id)
        } else {
            selectedApplicationIDs.insert(app.id)
        }
    }

    func toggleLeftoverSelection(for leftover: AppLeftoverItem) {
        selectedApplicationIDs = []
        guard leftover.safety != .protected else { return }
        if selectedLeftoverIDs.contains(leftover.id) {
            selectedLeftoverIDs.remove(leftover.id)
        } else {
            selectedLeftoverIDs.insert(leftover.id)
        }
    }

    func requestApplicationUninstall() {
        guard !selectedApplications.isEmpty else {
            statusMessage = "Select at least one application to uninstall"
            return
        }
        showingApplicationUninstallConfirmation = true
    }

    func uninstallSelectedApplicationsConfirmed() {
        let apps = selectedApplications
        guard !apps.isEmpty else {
            statusMessage = "Select at least one application to uninstall"
            return
        }

        let result = cleanupService.moveApplicationsToTrash(apps)
        applications.removeAll { result.movedIDs.contains($0.id) }
        selectedApplicationIDs.subtract(result.movedIDs)
        recordFailures(result.failures, title: "Uninstall issues")

        if result.failures.isEmpty {
            statusMessage = "Moved \(result.movedCount) apps to Trash: \(ByteFormat.string(result.bytes))"
        } else {
            statusMessage = "Moved \(result.movedCount) apps. \(result.failures.count) failed."
        }

        activity.insert(ActivityEntry(
            date: Date(),
            title: "Applications uninstalled",
            detail: "Moved \(result.movedCount) apps to Trash",
            bytes: result.bytes
        ), at: 0)
        saveActivity()
    }

    func requestLeftoverCleanup() {
        guard !selectedLeftovers.isEmpty else {
            statusMessage = "Select at least one leftover item to remove"
            return
        }
        showingLeftoverCleanupConfirmation = true
    }

    func cleanSelectedLeftoversConfirmed() {
        let leftovers = selectedLeftovers
        guard !leftovers.isEmpty else {
            statusMessage = "Select at least one leftover item to remove"
            return
        }

        let result = cleanupService.moveLeftoversToTrash(leftovers)
        applicationLeftovers.removeAll { result.movedIDs.contains($0.id) }
        selectedLeftoverIDs.subtract(result.movedIDs)
        recordFailures(result.failures, title: "Leftover cleanup issues")

        if result.failures.isEmpty {
            statusMessage = "Moved \(result.movedCount) leftovers to Trash: \(ByteFormat.string(result.bytes))"
        } else {
            statusMessage = "Moved \(result.movedCount) leftovers. \(result.failures.count) failed."
        }

        activity.insert(ActivityEntry(
            date: Date(),
            title: "Leftovers removed",
            detail: "Moved \(result.movedCount) leftover items to Trash",
            bytes: result.bytes
        ), at: 0)
        saveActivity()
    }

    func chooseSpaceLensFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose a folder to scan"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser

        if panel.runModal() == .OK, let url = panel.url {
            scanSpaceLensFolder(url)
        }
    }

    func scanHomeFolderForSpaceLens() {
        scanSpaceLensFolder(FileManager.default.homeDirectoryForCurrentUser)
    }

    private func scanSpaceLensFolder(_ url: URL) {
        selectedSpaceLensURL = url
        isScanningSpaceLens = true
        statusMessage = "Scanning folder: \(url.lastPathComponent)"

        Task {
            let items = spaceLensScanner.scanFolder(url)
            spaceLensItems = items
            expandedSpaceLensIDs = []
            spaceLensChildren = [:]
            loadingSpaceLensChildrenIDs = []
            isScanningSpaceLens = false
            statusMessage = "Space Lens found \(ByteFormat.string(items.reduce(0) { $0 + $1.size })) in \(items.count) items"
            activity.insert(ActivityEntry(
                date: Date(),
                title: "Space Lens scan completed",
                detail: url.path,
                bytes: items.reduce(0) { $0 + $1.size }
            ), at: 0)
            saveActivity()
        }
    }

    func toggleSpaceLensExpansion(for item: SpaceLensItem) {
        guard item.isDirectory else {
            NSWorkspace.shared.activateFileViewerSelecting([item.url])
            return
        }

        if expandedSpaceLensIDs.contains(item.id) {
            expandedSpaceLensIDs.remove(item.id)
            return
        }

        expandedSpaceLensIDs.insert(item.id)
        guard spaceLensChildren[item.id] == nil else { return }

        loadingSpaceLensChildrenIDs.insert(item.id)
        Task {
            let children = spaceLensScanner.scanFolder(item.url, limit: 25)
            spaceLensChildren[item.id] = children
            loadingSpaceLensChildrenIDs.remove(item.id)
        }
    }

    private func saveActivity() {
        activityStore.save(activity)
    }

    private func recordFailures(_ failures: [CleanupFailure], title: String) {
        lastOperationTitle = failures.isEmpty ? "" : title
        lastOperationFailures = failures
    }
}
