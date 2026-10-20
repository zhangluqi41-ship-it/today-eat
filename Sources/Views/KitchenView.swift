import SwiftUI

/// 冰箱里有什么，就做什么。用主料匹配，差几样一眼能看见。
struct KitchenView: View {
    @Environment(RecipeStore.self) private var store

    @State private var newItem = ""
    @State private var showAllMatches = false

    private let quickItems = ["鸡蛋", "番茄", "土豆", "豆腐", "五花肉", "鸡腿", "牛腩", "青椒", "洋葱", "香菇", "白菜", "粉丝"]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        TextField("比如：鸡蛋", text: $newItem)
                            .submitLabel(.done)
                            .onSubmit(add)
                        Button("添加", action: add)
                            .disabled(newItem.trimmingCharacters(in: .whitespaces).isEmpty)
                    }

                    Menu {
                        ForEach(quickItems, id: \.self) { item in
                            Button(item) { store.addInventory(item) }
                        }
                    } label: {
                        Label("从常备食材里挑", systemImage: "list.bullet.rectangle")
                    }
                } header: {
                    Text("家里有什么")
                } footer: {
                    if !store.inventory.isEmpty {
                        Text("左滑可以删掉一项。")
                    }
                }

                if !store.inventory.isEmpty {
                    Section("已录入 \(store.inventory.count) 样") {
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
                    let matches = store.matches()
                    Section {
                        ForEach(showAllMatches ? matches : Array(matches.prefix(20))) { result in
                            NavigationLink(value: result.recipe.id) {
                                matchRow(result)
                            }
                        }
                    } header: {
                        HStack {
                            Text("能做 \(matches.count) 道")
                            Spacer()
                            if matches.count > 20 {
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
            .navigationTitle("厨房")
            .navigationDestination(for: String.self) { id in
                RecipeDetailView(recipeID: id)
            }
        }
    }

    private func matchRow(_ result: RecipeStore.MatchResult) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(result.recipe.name)
                Spacer()
                if result.isComplete {
                    Label("齐了", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
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
