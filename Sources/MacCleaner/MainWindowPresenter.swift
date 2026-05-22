import AppKit

@MainActor
enum MainWindowPresenter {
    static var hasMainWindow: Bool {
        mainApplicationWindow != nil
    }

    static func reveal() {
        NSApp.activate(ignoringOtherApps: true)

        guard let window = mainApplicationWindow else { return }

        if window.isMiniaturized {
            window.deminiaturize(nil)
        }

        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    private static var mainApplicationWindow: NSWindow? {
        NSApp.windows.first(where: isMainApplicationWindow(_:))
    }

    private static func isMainApplicationWindow(_ window: NSWindow) -> Bool {
        guard window.canBecomeMain else { return false }
        guard !window.styleMask.contains(.nonactivatingPanel) else { return false }
        guard window.level == .normal else { return false }

        let className = String(describing: type(of: window))
        if className.contains("StatusBar") || className.contains("MenuBarExtra") {
            return false
        }

        return window.contentView != nil
    }
}
