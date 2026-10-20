import SwiftUI

struct RecipeListView: View {
    @Environment(RecipeStore.self) private var store

    @State private var keyword = ""
    @State private var category = ""
    @State private var sort: RecipeSort = .default
    @State private var favoritesOnly = false
    @State private var editingRecipe: Recipe?

    var body: some View {
        NavigationStack {
            List {
                if let message = store.loadMessage {
                    Section {
                        DataWarningCard(message: message) { store.retryLoadIfNeeded() }
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
                }

                if results.isEmpty {
                    Section {
                        EmptyHint(
                            title: keyword.isEmpty ? "这个分类还没有菜" : "没搜到「\(keyword)」",
                            message: keyword.isEmpty ? "点右上角的加号自己加一道" : "换个词试试，比如「茄子」或「下饭」",
                            systemImage: "magnifyingglass"
                        )
                        .listRowBackground(Color.clear)
                    }
                } else if category.isEmpty && keyword.isEmpty {
                    ForEach(DishCategory.all) { item in
                        let dishes = results.filter { $0.category == item.key }
                        if !dishes.isEmpty {
                            Section {
                                ForEach(dishes) { recipe in
                                    row(recipe)
                                }
                            } header: {
                                HStack {
                                    Text("\(item.emoji) \(item.name)")
                                    Spacer()
                                    Text("\(dishes.count) 道")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } else {
                    Section {
                        ForEach(results) { recipe in
                            row(recipe)
                        }
                    } header: {
                        Text("\(results.count) 道菜")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("菜谱")
            .searchable(text: $keyword, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜菜名、食材、标签")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    categoryMenu
                }
                ToolbarItem(placement: .topBarTrailing) {
                    filterMenu
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editingRecipe = Recipe(
                            name: "",
                            category: category.isEmpty ? "pork" : category,
                            kind: "荤",
                            minutes: 20,
                            difficulty: 1,
                            spicy: 0
                        )
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("新增菜谱")
                }
            }
            .navigationDestination(for: String.self) { id in
                RecipeDetailView(recipeID: id)
            }
            .sheet(item: $editingRecipe) { recipe in
                NavigationStack {
                    RecipeEditorView(recipe: recipe, isNew: store.recipe(id: recipe.id) == nil)
                        .environment(store)
                }
            }
        }
    }

    private func row(_ recipe: Recipe) -> some View {
        NavigationLink(value: recipe.id) {
            RecipeRow(recipe: recipe, isFavorite: store.favorites.contains(recipe.id))
        }
        .swipeActions(edge: .leading) {
            Button {
                store.toggleFavorite(recipe)
            } label: {
                Label(store.favorites.contains(recipe.id) ? "取消收藏" : "收藏",
                      systemImage: store.favorites.contains(recipe.id) ? "star.slash" : "star")
            }
            .tint(.orange)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                store.delete(recipe)
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }

    private var results: [Recipe] {
        store.filtered(category: category, keyword: keyword, favoritesOnly: favoritesOnly, sort: sort)
    }

    private var categoryMenu: some View {
        Menu {
            Button("全部分类") { category = "" }
            ForEach(DishCategory.all) { item in
                Button("\(item.emoji) \(item.name)") { category = item.key }
            }
        } label: {
            HStack(spacing: 4) {
                Text(category.isEmpty ? "全部" : DishCategory.name(for: category))
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .font(.subheadline)
        }
    }

    private var filterMenu: some View {
        Menu {
            Picker("排序", selection: $sort) {
                ForEach(RecipeSort.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            Divider()
            Toggle("只看收藏", isOn: $favoritesOnly)
            if favoritesOnly || !category.isEmpty {
                Divider()
                Button("清除筛选") {
                    favoritesOnly = false
                    category = ""
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
        }
        .accessibilityLabel("筛选与排序")
    }
}
