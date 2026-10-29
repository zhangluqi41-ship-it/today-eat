import SwiftUI

@main
struct TodayEatApp: App {
    @State private var store = RecipeStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .tint(Color.accentColor)
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    case .active:
                        // 回到前台补一次加载：上次若因权限/IO 失败，这里能自愈。
                        store.retryLoadIfNeeded()
                    case .background:
                        store.persist()
                    default:
                        break
                    }
                }
        }
    }
}
