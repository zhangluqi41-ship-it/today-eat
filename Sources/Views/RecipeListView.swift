import SwiftUI

struct RecipeListView: View {
    @Environment(RecipeStore.self) private var store

    @State private var keyword = ""
    @State private var category = ""
    @State private var sort: RecipeSort = .default
    @State private var favoritesOnly = false
    @State private var editingRecipe: Recipe?
    @State private var selectionTick = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                categoryBar
                recipeList
            }
            .navigationTitle("菜谱")
            .searchable(text: $keyword, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜菜名、食材、标签")
            .toolbar {
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
            .sensoryFeedback(.selection, trigger: selectionTick)
        }
    }

    // MARK: 分类快捷栏

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: "全部", emoji: "🍽️", key: "", count: store.recipes.count)
                ForEach(DishCategory.all) { item in
                    chip(title: item.name, emoji: item.emoji, key: item.key, count: count(of: item.key))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(.bar)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private func chip(title: String, emoji: String, key: String, count: Int) -> some View {
        let selected = category == key
        let action: () -> Void = {
            category = key
            selectionTick += 1
        }
        let label = HStack(spacing: 4) {
            Text(emoji)
                .font(.caption)
            Text(title)
                .font(.subheadline.weight(selected ? .semibold : .regular))
            Text("\(count)")
                .font(.caption2)
                .foregroundStyle(selected ? Color.white.opacity(0.85) : Color.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 36)
        .contentShape(Capsule())

        return Group {
            if selected {
                Button(action: action) { label }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.accentColor)
                    .accessibilityAddTraits(.isSelected)
            } else {
                Button(action: action) { label }
                    .buttonStyle(.bordered)
                    .tint(Color.secondary)
            }
        }
    }

    // MARK: 列表

    private var recipeList: some View {
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
        .scrollDismissesKeyboard(.interactively)
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
            .tint(.accentColor)
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

    private func count(of categoryKey: String) -> Int {
        store.recipes.filter { $0.category == categoryKey }.count
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
