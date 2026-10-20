import SwiftUI

struct RootView: View {
    @Environment(RecipeStore.self) private var store
    @State private var selection: Int = 0

    var body: some View {
        TabView(selection: $selection) {
            TonightView()
                .tabItem { Label("今晚", systemImage: "sparkles") }
                .tag(0)

            RecipeListView()
                .tabItem { Label("菜谱", systemImage: "book.closed") }
                .tag(1)

            KitchenView()
                .tabItem { Label("厨房", systemImage: "basket") }
                .tag(2)

            ShoppingView()
                .tabItem { Label("清单", systemImage: "checklist") }
                .tag(3)

            ProfileView()
                .tabItem { Label("我的", systemImage: "person.crop.circle") }
                .tag(4)
        }
        .onAppear { store.retryLoadIfNeeded() }
    }
}
