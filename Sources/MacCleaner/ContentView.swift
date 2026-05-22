import SwiftUI

struct LayoutMetrics: Equatable {
    let size: CGSize

    var width: CGFloat { size.width }
    var height: CGFloat { size.height }
    var isCompactWidth: Bool { width < 1020 }
    var isCompactHeight: Bool { height < 700 }
    var isTight: Bool { width < 900 || height < 620 }

    var sidebarWidth: CGFloat { isCompactWidth ? 210 : 250 }

    var topPadding: CGFloat { isCompactHeight ? 42 : 58 }
    var contentPadding: CGFloat { isCompactWidth ? 32 : 56 }
    var sectionSpacing: CGFloat { isCompactHeight ? 18 : 28 }
    var scanButtonCompact: Bool { isCompactHeight }
    var scanFooterHeight: CGFloat { isCompactHeight ? 136 : 168 }
}

private struct LayoutMetricsKey: EnvironmentKey {
    static let defaultValue = LayoutMetrics(size: CGSize(width: 1100, height: 720))
}

extension EnvironmentValues {
    var layoutMetrics: LayoutMetrics {
        get { self[LayoutMetricsKey.self] }
        set { self[LayoutMetricsKey.self] = newValue }
    }
}

struct HoverablePanel: ViewModifier {
    @State private var isHovering = false
    let cornerRadius: CGFloat
    let selected: Bool
    /// Large panels (e.g. Space Lens) feel janky when scaled; keep stroke/background only.
    var scalesOnHover: Bool

    func body(content: Content) -> some View {
        content
            .background(backgroundOpacity)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.white.opacity(isHovering ? 0.30 : 0.0), lineWidth: 1)
            )
            .scaleEffect(scalesOnHover && isHovering ? 1.01 : 1)
            .animation(.easeOut(duration: 0.14), value: isHovering)
            .onHover { hovering in
                isHovering = hovering
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
    }

    private var backgroundOpacity: Color {
        if selected { return .white.opacity(isHovering ? 0.24 : 0.18) }
        return .white.opacity(isHovering ? 0.16 : 0.10)
    }
}

extension View {
    func hoverablePanel(cornerRadius: CGFloat = 16, selected: Bool = false, scalesOnHover: Bool = true) -> some View {
        modifier(HoverablePanel(cornerRadius: cornerRadius, selected: selected, scalesOnHover: scalesOnHover))
    }
}

struct ContentView: View {
    @EnvironmentObject private var viewModel: CleanerViewModel

    var body: some View {
        GeometryReader { geometry in
            let metrics = LayoutMetrics(size: geometry.size)

            ZStack {
                ModuleBackground(module: viewModel.selectedModule)

                HStack(spacing: 0) {
                    SidebarView()
                        .frame(width: metrics.sidebarWidth)
                        .frame(maxHeight: .infinity)

                    Divider()
                        .opacity(0.15)

                    MainPanelView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .environment(\.layoutMetrics, metrics)
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .foregroundStyle(.white)
        .alert("Move selected items to Trash?", isPresented: $viewModel.showingCleanupConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Move to Trash", role: .destructive) {
                viewModel.cleanSelectedConfirmed()
            }
        } message: {
            Text("Mac Cleaner will move \(viewModel.selectedItems.count) selected items totaling \(ByteFormat.string(viewModel.selectedSize)) to Trash. You can restore them from Trash if needed.")
        }
        .alert("Uninstall selected applications?", isPresented: $viewModel.showingApplicationUninstallConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Move to Trash", role: .destructive) {
                viewModel.uninstallSelectedApplicationsConfirmed()
            }
        } message: {
            Text("Mac Cleaner will move \(viewModel.selectedApplications.count) selected applications totaling \(ByteFormat.string(viewModel.selectedApplicationsSize)) to Trash. Related leftover files are not removed yet.")
        }
        .alert("Remove selected leftovers?", isPresented: $viewModel.showingLeftoverCleanupConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Move to Trash", role: .destructive) {
                viewModel.cleanSelectedLeftoversConfirmed()
            }
        } message: {
            Text("Mac Cleaner will move \(viewModel.selectedLeftovers.count) leftover items totaling \(ByteFormat.string(viewModel.selectedLeftoversSize)) to Trash. You can restore them from Trash if needed.")
        }
    }
}

struct ModuleBackground: View {
    let module: CleanerModule

    private var palette: [Color] { module.backgroundPalette }

    var body: some View {
        ZStack {
            palette[2]

            LinearGradient(
                stops: gradientStops,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(palette[0].opacity(0.65))
                .frame(width: 740, height: 740)
                .blur(radius: 150)
                .offset(x: -360, y: -260)

            Circle()
                .fill(palette[2].opacity(0.55))
                .frame(width: 820, height: 820)
                .blur(radius: 180)
                .offset(x: 230, y: -260)

            Circle()
                .fill(palette[3].opacity(0.48))
                .frame(width: 820, height: 820)
                .blur(radius: 190)
                .offset(x: -130, y: 250)

            Circle()
                .fill(palette[4].opacity(0.66))
                .frame(width: 720, height: 720)
                .blur(radius: 180)
                .offset(x: 510, y: 310)

            RadialGradient(
                colors: [.white.opacity(0.13), .white.opacity(0.03), .clear],
                center: .top,
                startRadius: 40,
                endRadius: 820
            )

            LinearGradient(
                colors: [.white.opacity(0.04), .clear, .black.opacity(0.18)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
            .ignoresSafeArea()
    }

    private var gradientStops: [Gradient.Stop] {
        [
            .init(color: palette[0], location: 0.00),
            .init(color: palette[1], location: 0.22),
            .init(color: palette[2], location: 0.44),
            .init(color: palette[3], location: 0.68),
            .init(color: palette[4], location: 1.00)
        ]
    }
}

struct SidebarView: View {
    @EnvironmentObject private var viewModel: CleanerViewModel
    @Environment(\.layoutMetrics) private var metrics

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: metrics.isCompactHeight ? 10 : 16) {
                    ForEach(CleanerModule.allCases) { module in
                        SidebarItem(
                            module: module,
                            isSelected: module == viewModel.selectedModule,
                            compact: metrics.isCompactHeight
                        )
                        .onTapGesture {
                            viewModel.selectedModule = module
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, metrics.isCompactHeight ? 36 : 56)
                .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            StatusCard(compact: metrics.isCompactHeight)
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, metrics.isCompactHeight ? 52 : 64)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [.black.opacity(0.17), .black.opacity(0.09), .white.opacity(0.035)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }
}

struct SidebarItem: View {
    let module: CleanerModule
    let isSelected: Bool
    var compact = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: module.icon)
                .font(.system(size: compact ? 14 : 16, weight: .semibold))
                .frame(width: 24)

            Text(module.title)
                .font(.system(size: compact ? 13 : 14, weight: .semibold))

            Spacer()
        }
        .padding(.horizontal, compact ? 12 : 14)
        .padding(.vertical, compact ? 10 : 13)
        .background(isSelected ? .white.opacity(0.16) : .clear)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.0), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct StatusCard: View {
    @EnvironmentObject private var viewModel: CleanerViewModel
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 8) {
            Text("Status")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.65))
            Text(viewModel.statusMessage)
                .font(.system(size: compact ? 12 : 13, weight: .medium))
                .lineLimit(compact ? 2 : 3)
            Text(ByteFormat.string(viewModel.totalReviewSize))
                .font(.system(size: compact ? 22 : 26, weight: .bold))
        }
        .padding(compact ? 14 : 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct MainPanelView: View {
    @EnvironmentObject private var viewModel: CleanerViewModel
    @Environment(\.layoutMetrics) private var metrics

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
                    switch viewModel.selectedModule {
                    case .smartCare:
                        SmartCareDashboardView()
                    case .cleanup:
                        HeroHeader(module: viewModel.selectedModule)
                        CleanupView()
                    case .applications:
                        HeroHeader(module: viewModel.selectedModule)
                        ApplicationsView()
                    case .spaceLens:
                        HeroHeader(module: viewModel.selectedModule)
                        SpaceLensView()
                    case .activity:
                        HeroHeader(module: viewModel.selectedModule)
                        ActivityView()
                    }

                    if !viewModel.lastOperationFailures.isEmpty {
                        FailedItemsView(
                            title: viewModel.lastOperationTitle,
                            failures: viewModel.lastOperationFailures
                        )
                    }
                }
                .padding(.horizontal, metrics.contentPadding)
                .padding(.top, metrics.topPadding)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack {
                Spacer()
                ScanButton(compact: metrics.scanButtonCompact)
                Spacer()
            }
            .frame(height: metrics.scanFooterHeight)
            .padding(.bottom, metrics.isCompactHeight ? 28 : 36)
            .background(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.10)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct HeroHeader: View {
    let module: CleanerModule
    @Environment(\.layoutMetrics) private var metrics

    var body: some View {
        HStack(spacing: metrics.isCompactHeight ? 28 : 44) {
            ZStack {
                RoundedRectangle(cornerRadius: metrics.isCompactHeight ? 44 : 60, style: .continuous)
                    .fill(.white.opacity(0.18))
                    .frame(
                        width: metrics.isCompactHeight ? 180 : 260,
                        height: metrics.isCompactHeight ? 150 : 220
                    )
                    .rotationEffect(.degrees(-6))
                    .shadow(color: .black.opacity(0.25), radius: 24, x: 0, y: 16)

                Image(systemName: module.icon)
                    .font(.system(size: metrics.isCompactHeight ? 58 : 82, weight: .bold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white.opacity(0.92))
            }

            VStack(alignment: .leading, spacing: metrics.isCompactHeight ? 10 : 18) {
                Text(module.title)
                    .font(.system(size: metrics.isCompactHeight ? 36 : 48, weight: .medium))
                    .lineLimit(2)
                Text(module.subtitle)
                    .font(.system(size: metrics.isCompactHeight ? 16 : 20, weight: .regular))
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(3)
                    .frame(maxWidth: 460, alignment: .leading)
            }

            Spacer(minLength: 0)
        }
    }
}

struct SmartCareDashboardView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            HeroHeader(module: .smartCare)
            SmartCareView()
        }
    }
}

struct SmartCareHeroView: View {
    @EnvironmentObject private var viewModel: CleanerViewModel
    @Environment(\.layoutMetrics) private var metrics

    var body: some View {
        Group {
            if metrics.isTight {
                VStack(alignment: .leading, spacing: 22) {
                    illustration
                    copyBlock
                    compactMetrics
                }
            } else {
                HStack(spacing: metrics.isCompactWidth ? 34 : 56) {
                    illustration
                        .frame(maxWidth: .infinity)
                    copyBlock
                        .frame(maxWidth: metrics.isCompactWidth ? 320 : 360, alignment: .leading)
                }
                .frame(maxWidth: .infinity, minHeight: metrics.isCompactHeight ? 330 : 440, alignment: .center)
            }
        }
    }

    private var illustration: some View {
        ZStack {
            RoundedRectangle(cornerRadius: metrics.isCompactHeight ? 52 : 68, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.30), .white.opacity(0.09)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(
                    width: metrics.isCompactHeight ? 230 : 330,
                    height: metrics.isCompactHeight ? 190 : 270
                )
                .rotationEffect(.degrees(-5))
                .shadow(color: .black.opacity(0.22), radius: 32, x: 0, y: 22)

            Image(systemName: "sparkles")
                .font(.system(size: metrics.isCompactHeight ? 72 : 108, weight: .bold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white.opacity(0.96))
        }
    }

    private var copyBlock: some View {
        VStack(alignment: .leading, spacing: metrics.isCompactHeight ? 18 : 24) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Smart Care")
                    .font(.system(size: metrics.isCompactHeight ? 38 : 48, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text("Quick maintenance that takes care of the essentials.")
                    .font(.system(size: metrics.isCompactHeight ? 16 : 20, weight: .regular))
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(3)
            }

            VStack(alignment: .leading, spacing: metrics.isCompactHeight ? 12 : 16) {
                FeatureBullet(icon: "bolt.fill", title: "Quick Scan")
                FeatureBullet(icon: "trash.fill", title: "\(viewModel.scanItems.count) cleanup items")
                FeatureBullet(icon: "checkmark.shield.fill", title: "\(ByteFormat.string(viewModel.selectedSize)) selected safely")
            }
        }
    }

    private var compactMetrics: some View {
        HStack(spacing: 12) {
            MiniMetric(title: "Junk", value: ByteFormat.string(viewModel.totalFoundSize))
            MiniMetric(title: "Apps", value: "\(viewModel.applications.count)")
        }
    }
}

struct FeatureBullet: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .frame(width: 30, height: 30)
                .background(.white.opacity(0.16))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            Text(title)
                .font(.system(size: 15, weight: .bold))
        }
    }
}

struct MiniMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.68))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct ScanButton: View {
    @EnvironmentObject private var viewModel: CleanerViewModel
    @State private var isHovering = false
    var compact = false

    private var outerSize: CGFloat { compact ? 88 : 110 }
    private var innerSize: CGFloat { compact ? 72 : 92 }

    var body: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(isHovering ? 0.18 : 0.12))
                .frame(width: outerSize + (isHovering ? 8 : 0), height: outerSize + (isHovering ? 8 : 0))
                .blur(radius: isHovering ? 14 : 10)

            Circle()
                .fill(.white.opacity(viewModel.isScanning ? 0.10 : (isHovering ? 0.26 : 0.18)))
                .frame(width: innerSize, height: innerSize)
                .overlay(Circle().stroke(.white.opacity(isHovering ? 0.82 : 0.55), lineWidth: isHovering ? 2.5 : 2))
                .shadow(color: .white.opacity(isHovering ? 0.18 : 0.0), radius: 18, x: 0, y: 0)

            if viewModel.isScanning {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
            } else {
                Text(viewModel.scanButtonTitle)
                    .font(.system(size: 17, weight: .bold))
            }
        }
        .contentShape(Circle())
        .opacity(viewModel.isScanning ? 0.75 : 1)
        .scaleEffect(isHovering && !viewModel.isScanning ? 1.06 : 1)
        .animation(.spring(response: 0.22, dampingFraction: 0.72), value: isHovering)
        .onHover { hovering in
            isHovering = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .onTapGesture {
            guard !viewModel.isScanning else { return }
            viewModel.performPrimaryAction()
        }
    }
}

struct SmartCareView: View {
    @EnvironmentObject private var viewModel: CleanerViewModel
    @Environment(\.layoutMetrics) private var metrics

    private var gridMinimum: CGFloat { metrics.isCompactWidth ? 170 : 190 }

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: gridMinimum), spacing: 16)], spacing: 16) {
            MetricCard(title: "Total Review", value: ByteFormat.string(viewModel.totalReviewSize), icon: "sparkles")
            MetricCard(title: "Junk Found", value: ByteFormat.string(viewModel.totalFoundSize), icon: "trash.fill")
            MetricCard(title: "Cleanup Items", value: "\(viewModel.scanItems.count)", icon: "list.bullet.rectangle")
            MetricCard(title: "Selected", value: ByteFormat.string(viewModel.selectedSize), icon: "checkmark.circle")
            MetricCard(title: "Apps Indexed", value: "\(viewModel.applications.count)", icon: "app")
            MetricCard(title: "Leftovers", value: ByteFormat.string(viewModel.totalLeftoversSize), icon: "puzzlepiece.extension.fill")
            MetricCard(title: "Leftover Items", value: "\(viewModel.applicationLeftovers.count)", icon: "shippingbox.fill")
            MetricCard(title: "Last Action", value: viewModel.lastActivityTitle, icon: "clock.fill", style: .text)
        }
    }
}

struct MetricCard: View {
    enum Style {
        case metric
        case text
    }

    let title: String
    let value: String
    let icon: String
    var style: Style = .metric

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
            Text(value)
                .font(.system(size: 28, weight: .bold))
                .lineLimit(style == .text ? 1 : 2)
                .minimumScaleFactor(style == .text ? 0.45 : 0.65)
                .truncationMode(.tail)
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.72))
        }
        .padding(20)
        .frame(minHeight: 132, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

struct CleanupView: View {
    @EnvironmentObject private var viewModel: CleanerViewModel

    private var groupedItems: [(category: ScanCategory, items: [ScanItem])] {
        ScanCategory.allCases.compactMap { category in
            let items = viewModel.scanItems.filter { $0.category == category }
            return items.isEmpty ? nil : (category, items)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Review before cleaning")
                        .font(.title2.bold())
                    Text(cleanupSummary)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.68))
                }
                Spacer()
                Button("Clean Selected") {
                    viewModel.requestCleanup()
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.selectedItems.isEmpty)
            }

            if viewModel.scanItems.isEmpty {
                EmptyState(title: "No cleanup items yet", message: "Press Scan to inspect safe user cache, logs, and Trash locations.")
            } else {
                VStack(spacing: 18) {
                    ForEach(groupedItems, id: \.category.id) { group in
                        CleanupCategorySection(category: group.category, items: group.items)
                    }
                }
            }
        }
    }

    private var cleanupSummary: String {
        if viewModel.scanItems.isEmpty {
            return "Safe items are selected automatically after scan."
        }
        return "\(viewModel.scanItems.count) items • \(ByteFormat.string(viewModel.totalFoundSize)) found • \(viewModel.selectedItems.count) selected"
    }
}

struct FailedItemsView: View {
    let title: String
    let failures: [CleanupFailure]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                Text(title.isEmpty ? "Items that need attention" : title)
                    .font(.headline)
                Text("\(failures.count) failed")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.65))
            }

            ForEach(failures.prefix(6)) { failure in
                VStack(alignment: .leading, spacing: 4) {
                    Text(failure.name)
                        .font(.subheadline.weight(.semibold))
                    Text(failure.reason)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.72))
                    Text(failure.path)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.52))
                        .lineLimit(1)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding(18)
        .background(.white.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct CleanupCategorySection: View {
    @EnvironmentObject private var viewModel: CleanerViewModel
    let category: ScanCategory
    let items: [ScanItem]

    private var totalSize: Int64 {
        items.reduce(0) { $0 + $1.size }
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: category.icon)
                    .font(.headline)
                Text(category.rawValue)
                    .font(.headline)
                Text("\(items.count) items")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.65))
                Spacer()
                Text(ByteFormat.string(totalSize))
                    .font(.headline)
            }
            .padding(.horizontal, 4)

            ForEach(items) { item in
                ScanResultRow(item: item, isSelected: viewModel.selectedItemIDs.contains(item.id))
                    .onTapGesture { viewModel.toggleSelection(for: item) }
            }
        }
    }
}

struct ScanResultRow: View {
    let item: ScanItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(isSelected ? .green : .white.opacity(0.55))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                Text(item.displayPath)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.58))
                    .lineLimit(1)
            }

            Spacer()

            Text(item.category.rawValue)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.78))

            Text(item.safety.rawValue)
                .font(.caption.weight(.bold))
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(item.safety.color.opacity(0.25))
                .clipShape(Capsule())

            Text(ByteFormat.string(item.size))
                .font(.system(size: 14, weight: .bold))
                .frame(width: 90, alignment: .trailing)
        }
        .padding(14)
        .hoverablePanel(selected: isSelected)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct ApplicationsView: View {
    @EnvironmentObject private var viewModel: CleanerViewModel

    private var leftoverGroups: [(name: String, items: [AppLeftoverItem])] {
        Dictionary(grouping: viewModel.applicationLeftovers, by: \.appHint)
            .map { (name: $0.key, items: $0.value.sorted { $0.size > $1.size }) }
            .sorted { $0.items.reduce(0) { $0 + $1.size } > $1.items.reduce(0) { $0 + $1.size } }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Applications Manager")
                        .font(.title2.bold())
                    Text(applicationSummary)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.68))
                }

                Spacer()

                if hasSelection {
                    Button("Clear Selection") {
                        viewModel.selectedApplicationIDs.removeAll()
                        viewModel.selectedLeftoverIDs.removeAll()
                    }
                    .buttonStyle(.bordered)
                }
            }

            if viewModel.applications.isEmpty && viewModel.applicationLeftovers.isEmpty {
                EmptyState(title: "No app inventory yet", message: "Press Scan to list apps from /Applications and ~/Applications.")
            } else {
                if !viewModel.applicationLeftovers.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Leftover Files")
                                    .font(.headline)
                                Text(leftoverSummary)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.white.opacity(0.66))
                            }

                            Spacer()

                            Button(viewModel.selectedLeftovers.count == viewModel.safeLeftovers.count ? "Deselect All" : "Select Safe") {
                                if viewModel.selectedLeftovers.count == viewModel.safeLeftovers.count {
                                    viewModel.selectedLeftoverIDs.removeAll()
                                } else {
                                    viewModel.selectedApplicationIDs.removeAll()
                                    viewModel.selectedLeftoverIDs = Set(viewModel.safeLeftovers.map(\.id))
                                }
                            }
                            .buttonStyle(.bordered)
                        }

                        ForEach(leftoverGroups.prefix(8), id: \.name) { group in
                            LeftoverGroupSection(name: group.name, items: group.items)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Installed Apps")
                        .font(.headline)

                    ForEach(viewModel.applications.prefix(25)) { app in
                        ApplicationRow(
                            app: app,
                            isSelected: viewModel.selectedApplicationIDs.contains(app.id)
                        )
                        .onTapGesture {
                            viewModel.toggleApplicationSelection(for: app)
                        }
                    }
                }
            }
        }
    }

    private var hasSelection: Bool {
        !viewModel.selectedApplications.isEmpty || !viewModel.selectedLeftovers.isEmpty
    }

    private var applicationSummary: String {
        if !viewModel.selectedApplications.isEmpty {
            return "\(viewModel.selectedApplications.count) apps selected • \(ByteFormat.string(viewModel.selectedApplicationsSize))"
        }
        if !viewModel.selectedLeftovers.isEmpty {
            return "\(viewModel.selectedLeftovers.count) leftovers selected • \(ByteFormat.string(viewModel.selectedLeftoversSize))"
        }
        return "Select apps to uninstall, or leftover files to clean."
    }

    private var leftoverSummary: String {
        "\(viewModel.applicationLeftovers.count) items • \(ByteFormat.string(viewModel.totalLeftoversSize)) • \(viewModel.safeLeftovers.count) safe, \(viewModel.cautionLeftovers.count) review"
    }
}

struct ApplicationRow: View {
    let app: AppInventoryItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: isSelected ? "checkmark.square.fill" : "square.fill")
                .font(.title3)
                .foregroundStyle(isSelected ? .green : .white.opacity(0.92))

            VStack(alignment: .leading, spacing: 3) {
                Text(app.name)
                    .font(.headline)
                Text(app.url.path)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.58))
                    .lineLimit(1)
            }

            Spacer()

            Text(ByteFormat.string(app.size))
                .font(.headline)
        }
        .padding(14)
        .hoverablePanel(selected: isSelected)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct LeftoverGroupSection: View {
    @EnvironmentObject private var viewModel: CleanerViewModel
    let name: String
    let items: [AppLeftoverItem]

    private var totalSize: Int64 {
        items.reduce(0) { $0 + $1.size }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "puzzlepiece.extension.fill")
                    .font(.headline)
                Text(name)
                    .font(.headline)
                    .lineLimit(1)
                Text("\(items.count) items")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.65))
                Spacer()
                Text(ByteFormat.string(totalSize))
                    .font(.headline)
            }
            .padding(.horizontal, 4)

            ForEach(items.prefix(6)) { leftover in
                AppLeftoverRow(
                    leftover: leftover,
                    isSelected: viewModel.selectedLeftoverIDs.contains(leftover.id)
                )
                .onTapGesture {
                    viewModel.toggleLeftoverSelection(for: leftover)
                }
            }
        }
        .padding(.top, 4)
    }
}

struct AppLeftoverRow: View {
    let leftover: AppLeftoverItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: isSelected ? "checkmark.square.fill" : "square.fill")
                .font(.title3)
                .foregroundStyle(isSelected ? .green : .white.opacity(0.92))

            Image(systemName: "puzzlepiece.extension.fill")
                .font(.headline)
                .frame(width: 32, height: 32)
                .background(.white.opacity(0.16))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(leftover.appHint)
                    .font(.headline)
                    .lineLimit(1)
                Text("\(leftover.category) • \(leftover.displayPath)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.58))
                    .lineLimit(1)
            }

            Spacer()

            Text(ByteFormat.string(leftover.size))
                .font(.headline)

            Text(leftover.safety.rawValue)
                .font(.caption.weight(.bold))
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(leftover.safety.color.opacity(0.25))
                .clipShape(Capsule())
        }
        .padding(14)
        .hoverablePanel(selected: isSelected)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct SpaceLensView: View {
    @EnvironmentObject private var viewModel: CleanerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Storage overview")
                        .font(.title2.bold())
                    Text(viewModel.selectedSpaceLensURL?.path ?? "Choose a folder to map its largest direct contents.")
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(2)
                }
                Spacer()
                Button("Home Folder") {
                    viewModel.scanHomeFolderForSpaceLens()
                }
                .buttonStyle(.bordered)

                Button("Choose Folder") {
                    viewModel.chooseSpaceLensFolder()
                }
                .buttonStyle(.borderedProminent)
            }

            if viewModel.isScanningSpaceLens {
                HStack(spacing: 12) {
                    ProgressView()
                        .tint(.white)
                    Text("Scanning folder sizes...")
                        .font(.headline)
                }
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            } else if viewModel.spaceLensItems.isEmpty {
                EmptyState(title: "No storage map yet", message: "Choose a folder or scan your home folder to see the largest items.")
            } else {
                ForEach(viewModel.spaceLensItems) { item in
                    SpaceLensTopLevelCard(
                        item: item,
                        maxSize: viewModel.spaceLensItems.first?.size ?? item.size
                    )
                }
            }
        }
    }
}

/// Relative-size bar. Uses an explicit fill width (min = bar height) so both ends always render as proper rounded caps,
/// regardless of how small the ratio is. `GeometryReader` is hard-constrained to `height` so it can't steal vertical hover.
private struct SpaceLensVolumeTrack: View {
    let ratio: Double
    var height: CGFloat = 6
    var tint: Color = .white

    private var clamped: CGFloat {
        CGFloat(max(0.0, min(1, ratio)))
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.14))

                Capsule(style: .continuous)
                    .fill(tint.opacity(0.62))
                    .frame(width: max(height, proxy.size.width * clamped))
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
    }
}

/// One glass card per top-level folder; contents render inside the same card.
struct SpaceLensTopLevelCard: View {
    @EnvironmentObject private var viewModel: CleanerViewModel
    @State private var isHeaderHovering = false

    let item: SpaceLensItem
    let maxSize: Int64

    private var isExpanded: Bool {
        viewModel.expandedSpaceLensIDs.contains(item.id)
    }

    private var isLoadingChildren: Bool {
        viewModel.loadingSpaceLensChildrenIDs.contains(item.id)
    }

    private var children: [SpaceLensItem] {
        viewModel.spaceLensChildren[item.id] ?? []
    }

    private var ratio: Double {
        guard maxSize > 0 else { return 0 }
        return max(0.08, min(1, Double(item.size) / Double(maxSize)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection

            if isLoadingChildren {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                    Text("Reading contents...")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.72))
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
            } else if isExpanded {
                Divider()
                    .opacity(0.2)
                    .padding(.horizontal, 10)

                if children.isEmpty {
                    Text("No readable child items.")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.62))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        let siblingMax = children.map(\.size).max() ?? 1
                        ForEach(children) { child in
                            SpaceLensInlineRow(
                                item: child,
                                indent: 0,
                                maxSiblingSize: siblingMax
                            )
                        }
                    }
                    .padding(.bottom, 6)
                }
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.white.opacity(0.10))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// Hover only tracks the real header height (no greedy `GeometryReader` filling the card).
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: item.isDirectory ? (isExpanded ? "chevron.down" : "chevron.right") : "doc.fill")
                    .font(.caption.weight(.bold))
                    .frame(width: 14)
                    .opacity(item.isDirectory ? 1 : 0.72)

                Image(systemName: item.isDirectory ? "folder.fill" : "doc.fill")
                    .font(.title2)

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name)
                        .font(.title3.weight(.bold))
                        .lineLimit(1)
                    Text(item.displayPath)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.58))
                        .lineLimit(1)
                }

                Spacer()

                Text(ByteFormat.string(item.size))
                    .font(.title3.weight(.bold))

                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([item.url])
                } label: {
                    Image(systemName: "arrow.up.forward.square")
                }
                .buttonStyle(.plain)
                .help("Show in Finder")
            }

            SpaceLensVolumeTrack(ratio: ratio, height: 8)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(14)
        .background(Color.white.opacity(isHeaderHovering ? 0.06 : 0))
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.toggleSpaceLensExpansion(for: item)
        }
        .onHover { hovering in
            isHeaderHovering = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

/// Row inside a top-level card (and nested folders inside the same card).
private struct SpaceLensInlineRow: View {
    @EnvironmentObject private var viewModel: CleanerViewModel
    @State private var isRowHovering = false

    let item: SpaceLensItem
    let indent: Int
    /// Largest size among siblings — used for the in-row volume bar only.
    let maxSiblingSize: Int64

    private var isExpanded: Bool {
        viewModel.expandedSpaceLensIDs.contains(item.id)
    }

    private var isLoadingChildren: Bool {
        viewModel.loadingSpaceLensChildrenIDs.contains(item.id)
    }

    private var children: [SpaceLensItem] {
        viewModel.spaceLensChildren[item.id] ?? []
    }

    private var volumeRatio: Double {
        guard maxSiblingSize > 0 else { return 0.08 }
        return max(0.06, min(1, Double(item.size) / Double(maxSiblingSize)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 8) {
                    if item.isDirectory {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption2.weight(.bold))
                            .frame(width: 12)
                    } else {
                        Color.clear.frame(width: 12, height: 1)
                    }

                    Image(systemName: item.isDirectory ? "folder.fill" : "doc.fill")
                        .font(.subheadline)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Text(item.displayPath)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.52))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    Text(ByteFormat.string(item.size))
                        .font(.subheadline.weight(.semibold))

                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([item.url])
                    } label: {
                        Image(systemName: "arrow.up.forward.square")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .help("Show in Finder")
                }

                SpaceLensVolumeTrack(ratio: volumeRatio, height: 6)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .padding(.leading, CGFloat(indent) * 14)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.white.opacity(isRowHovering ? 0.14 : 0.07))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.white.opacity(isRowHovering ? 0.22 : 0.08), lineWidth: 1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .onTapGesture {
                viewModel.toggleSpaceLensExpansion(for: item)
            }
            .onHover { hovering in
                isRowHovering = hovering
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }

            if isLoadingChildren {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(.white)
                    Text("Reading…")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.65))
                }
                .padding(.leading, CGFloat(indent + 1) * 14 + 14)
                .padding(.bottom, 6)
            } else if item.isDirectory, isExpanded {
                if children.isEmpty {
                    Text("Empty folder")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.55))
                        .padding(.leading, CGFloat(indent + 1) * 14 + 14)
                        .padding(.bottom, 6)
                } else {
                    let nestedMax = children.map(\.size).max() ?? 1
                    ForEach(children) { child in
                        SpaceLensInlineRow(
                            item: child,
                            indent: indent + 1,
                            maxSiblingSize: nestedMax
                        )
                    }
                }
            }
        }
    }
}

struct ActivityView: View {
    @EnvironmentObject private var viewModel: CleanerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent activity")
                .font(.title2.bold())

            if viewModel.activity.isEmpty {
                EmptyState(title: "No activity yet", message: "Scans and cleanup actions will appear here.")
            } else {
                ForEach(viewModel.activity) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.title).font(.headline)
                            Text(entry.detail).foregroundStyle(.white.opacity(0.68))
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(ByteFormat.string(entry.bytes)).font(.headline)
                            Text(entry.date.formatted(date: .omitted, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.58))
                        }
                    }
                    .padding(14)
                    .background(.white.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
    }
}

struct EmptyState: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title3.bold())
            Text(message)
                .foregroundStyle(.white.opacity(0.72))
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
