import SwiftUI

@main
struct MacCleanerApp: App {
    @StateObject private var viewModel = CleanerViewModel()
    @StateObject private var menuBarViewModel: MenuBarViewModel

    init() {
        let cleanerViewModel = CleanerViewModel()
        let menuViewModel = MenuBarViewModel(cleanerViewModel: cleanerViewModel)
        _viewModel = StateObject(wrappedValue: cleanerViewModel)
        _menuBarViewModel = StateObject(wrappedValue: menuViewModel)
    }

    var body: some Scene {
        Window("Mac Cleaner", id: "main") {
            ContentView()
                .environmentObject(viewModel)
                .frame(minWidth: 1100, idealWidth: 1100, maxWidth: .infinity,
                       minHeight: 720, idealHeight: 720, maxHeight: .infinity)
        }
        .defaultSize(width: 1100, height: 720)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)

        MenuBarExtra("Mac Cleaner", systemImage: "sparkles") {
            MenuBarPopoverView()
                .environmentObject(viewModel)
                .environmentObject(menuBarViewModel)
        }
        .menuBarExtraStyle(.window)
    }
}
