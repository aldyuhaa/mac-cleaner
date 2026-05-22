import SwiftUI

struct MenuBarPopoverView: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var cleanerViewModel: CleanerViewModel
    @EnvironmentObject private var menuBarViewModel: MenuBarViewModel

    var body: some View {
        VStack(spacing: 12) {
            unlockBanner
            header
            metricGrid
            externalDrivesSection
            recentActivitySection
            footer
        }
        .padding(14)
        .frame(width: 500)
        .background(
            LinearGradient(
                colors: CleanerModule.spaceLens.backgroundPalette,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .foregroundStyle(.white)
    }

    private var unlockBanner: some View {
        Text("Mac Cleaner Menu")
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.black.opacity(0.85))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.yellow.opacity(0.95))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("Mac Health:")
                        .font(.title3.weight(.bold))
                    Text(menuBarViewModel.healthSummary)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.cyan)
                }
                Text(cleanerViewModel.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(2)

                Button("Quick Scan") {
                    menuBarViewModel.quickScan()
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 6)
            }

            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.white.opacity(0.12))
                    .frame(width: 58, height: 58)
                Image(systemName: "sparkles.rectangle.stack")
                    .font(.title2.weight(.bold))
            }
        }
        .padding(.horizontal, 2)
    }

    private var metricGrid: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 10) {
                MenuMetricCard(
                    title: menuBarViewModel.diskTitle,
                    icon: "internaldrive.fill",
                    primary: menuBarViewModel.diskValue,
                    secondary: menuBarViewModel.diskSecondary,
                    actionTitle: "Free Up",
                    action: {
                        cleanerViewModel.selectedModule = .cleanup
                        openMainApplication()
                    },
                    onTap: {}
                )

                MenuMetricCard(
                    title: menuBarViewModel.cpuTitle,
                    icon: "cpu.fill",
                    primary: menuBarViewModel.cpuValue,
                    secondary: menuBarViewModel.cpuSecondary,
                    actionTitle: nil,
                    action: nil,
                    onTap: {}
                )
            }

            VStack(spacing: 10) {
                MenuMetricCard(
                    title: menuBarViewModel.memoryTitle,
                    icon: "memorychip.fill",
                    primary: menuBarViewModel.memoryValue,
                    secondary: menuBarViewModel.memorySecondary,
                    actionTitle: "Optimize",
                    action: {
                        cleanerViewModel.selectedModule = .smartCare
                        openMainApplication()
                    },
                    onTap: {}
                )

                MenuMetricCard(
                    title: menuBarViewModel.networkTitle,
                    icon: "wifi",
                    primary: menuBarViewModel.networkUpload,
                    secondary: menuBarViewModel.networkDownload,
                    actionTitle: nil,
                    action: nil,
                    onTap: {}
                )
            }
        }
    }

    private var externalDrivesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("External Drives")
                .font(.headline.weight(.bold))

            if menuBarViewModel.snapshot.externalDrives.isEmpty {
                Text("No external drives connected")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.74))
            } else {
                ForEach(menuBarViewModel.snapshot.externalDrives.prefix(3)) { drive in
                    HStack(spacing: 10) {
                        Image(systemName: "externaldrive.fill")
                            .font(.caption.weight(.bold))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(drive.name)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                            Text("Available \(ByteFormat.string(drive.availableBytes))")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                        }

                        Spacer()

                        Button {
                            menuBarViewModel.showInFinder(drive.mountPath)
                        } label: {
                            Image(systemName: "eject.fill")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
        .padding(12)
        .background(.black.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Activity")
                .font(.headline.weight(.bold))

            if menuBarViewModel.recentActivity.isEmpty {
                Text("No recent activity yet")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.74))
            } else {
                ForEach(menuBarViewModel.recentActivity) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.title)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                            Text(entry.detail)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.72))
                                .lineLimit(1)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(ByteFormat.string(entry.bytes))
                                .font(.caption.weight(.bold))
                            Text(entry.date.formatted(date: .omitted, time: .shortened))
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
        .padding(12)
        .background(.black.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: $menuBarViewModel.menuBarOnlyModeEnabled)
                .labelsHidden()
                .toggleStyle(.switch)

            Text("Menu Bar Only Mode")
                .font(.caption.weight(.semibold))

            Spacer()

            Button("Open Mac Cleaner") {
                openMainApplication()
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 2)
    }

    private func openMainApplication() {
        menuBarViewModel.prepareMainWindowPresentation()

        if MainWindowPresenter.hasMainWindow {
            MainWindowPresenter.reveal()
            return
        }

        openWindow(id: "main")

        if menuBarViewModel.menuBarOnlyModeEnabled {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                MainWindowPresenter.reveal()
            }
        } else {
            DispatchQueue.main.async {
                MainWindowPresenter.reveal()
            }
        }
    }
}

private struct MenuMetricCard: View {
    let title: String
    let icon: String
    let primary: String
    let secondary: String
    let actionTitle: String?
    let action: (() -> Void)?
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.subheadline.weight(.bold))
                Text(title)
                    .font(.headline.weight(.bold))
                    .lineLimit(1)
            }

            Text(primary)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.cyan)

            Text(secondary)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.78))

            if let actionTitle, let action {
                HStack {
                    Spacer()
                    Button(actionTitle, action: action)
                        .buttonStyle(.plain)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.cyan)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
        .padding(14)
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture(perform: onTap)
    }
}
