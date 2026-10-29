import SwiftUI

/// 冰箱里有什么，就做什么。用主料匹配，差几样一眼能看见。
struct KitchenView: View {
    @Environment(RecipeStore.self) private var store

    @State private var newItem = ""
    @State private var showAllMatches = false
    @State private var showPantryEditor = false
    @State private var selectionTick = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                pantryBar
                ingredientList
            }
            .navigationTitle("厨房")
            .navigationDestination(for: String.self) { id in
                RecipeDetailView(recipeID: id)
            }
            .sheet(isPresented: $showPantryEditor) {
                NavigationStack {
                    PantryEditorView()
                        .environment(store)
                }
            }
            .sensoryFeedback(.selection, trigger: selectionTick)
        }
    }

    // MARK: 常备食材快捷栏

    private var pantryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(store.settings.quickIngredients, id: \.self) { item in
                    let added = store.inventory.contains(item)
                    Button {
                        store.toggleInventory(item)
                        selectionTick += 1
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: added ? "checkmark.circle.fill" : "plus.circle")
                            Text(item)
                        }
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 36)
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.bordered)
                    .tint(added ? Color.accentColor : Color.secondary)
                    .accessibilityLabel(added ? "把\(item)从家里有什么中移除" : "把\(item)加进家里有什么")
                    .accessibilityAddTraits(added ? AccessibilityTraits.isSelected : AccessibilityTraits())
                }

                Button {
                    showPantryEditor = true
                } label: {
                    Label("编辑", systemImage: "slider.horizontal.3")
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 36)
                }
                .buttonStyle(.bordered)
                .tint(Color.accentColor)
                .accessibilityLabel("编辑常备食材")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(.bar)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    // MARK: 列表

    private var ingredientList: some View {
        List {
            Section {
                HStack {
                    TextField("比如：鸡蛋", text: $newItem)
                        .submitLabel(.done)
                        .onSubmit(add)
                    Button("添加", action: add)
                        .disabled(newItem.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } header: {
                Text("家里有什么")
            } footer: {
                Text(store.inventory.isEmpty
                     ? "点上面那排常备食材，或者在这里手输。"
                     : "已经录了 \(store.inventory.count) 样。左滑可以删掉一项。")
            }

            if !store.inventory.isEmpty {
                Section {
                    ForEach(store.inventory, id: \.self) { item in
                        HStack {
                            Image(systemName: "checkmark.seal")
                                .foregroundStyle(Color.accentColor)
                            Text(item)
                        }
                    }
                    .onDelete { offsets in
                        offsets.map { store.inventory[$0] }.forEach(store.removeInventory)
                    }
                } header: {
                    HStack {
                        Text("已录入 \(store.inventory.count) 样")
                        Spacer()
                        Button("全部清空") {
                            store.clearInventory()
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            }

            if store.inventory.isEmpty {
                Section {
                    EmptyHint(
                        title: "先告诉我冰箱里有什么",
                        message: "把家里现有的食材加进来，我按“还差几样”给你排菜。",
                        systemImage: "refrigerator"
                    )
                    .listRowBackground(Color.clear)
                }
            } else {
                Section {
                    ForEach(showAllMatches ? matchList : Array(matchList.prefix(20))) { result in
                        NavigationLink(value: result.recipe.id) {
                            matchRow(result)
                        }
                    }
                } header: {
                    HStack {
                        Text("能做 \(matchList.count) 道")
                        Spacer()
                        if matchList.count > 20 {
                            Button(showAllMatches ? "收起来" : "看全部") {
                                showAllMatches.toggle()
                            }
                            .font(.caption)
                        }
                    }
                } footer: {
                    Text("只按主料算，调料当成家里都有。")
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollDismissesKeyboard(.interactively)
    }

    private var matchList: [RecipeStore.MatchResult] { store.matches() }

    private func matchRow(_ result: RecipeStore.MatchResult) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(result.recipe.name)
                Spacer()
                if result.isComplete {
                    Label("齐了", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                } else {
                    Text("差 \(result.missing.count) 样")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text(result.isComplete
                 ? "主料都有，可以马上开火"
                 : "还差：" + result.missing.prefix(3).joined(separator: "、"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
    }

    private func add() {
        store.addInventory(newItem)
        newItem = ""
    }
}

/// 编辑厨房顶部那排常备食材。
struct PantryEditorView: View {
    @Environment(RecipeStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var newName = ""
    @State private var editMode: EditMode = .active

    var body: some View {
        List {
            Section {
                ForEach(store.settings.quickIngredients, id: \.self) { name in
                    Text(name)
                }
                .onDelete { offsets in
                    offsets.map { store.settings.quickIngredients[$0] }.forEach(store.removeQuickIngredient)
                }
                .onMove { source, destination in
                    store.moveQuickIngredients(from: source, to: destination)
                }
            } header: {
                Text("现在有 \(store.settings.quickIngredients.count) 项")
            } footer: {
                Text("这一排只是快捷入口，点一下就会加进「家里有什么」。拖动可以调顺序。")
            }

            Section {
                HStack {
                    TextField("加一项，比如：豆芽", text: $newName)
                        .submitLabel(.done)
                        .onSubmit(add)
                    Button("加入", action: add)
                        .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                Button("恢复默认列表") {
                    store.resetQuickIngredients()
                }
                .foregroundStyle(Color.accentColor)
            }
        }
        .listStyle(.insetGrouped)
        .environment(\.editMode, $editMode)
        .navigationTitle("常备食材")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("完成") { dismiss() }
            }
        }
    }

    private func add() {
        store.addQuickIngredient(newName)
        newName = ""
    }
}
