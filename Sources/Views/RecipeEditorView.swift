import SwiftUI

struct RecipeEditorView: View {
    @Environment(RecipeStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let isNew: Bool

    @State private var draft: Recipe
    @State private var tagText: String

    init(recipe: Recipe, isNew: Bool) {
        self.isNew = isNew
        _draft = State(initialValue: recipe)
        _tagText = State(initialValue: recipe.tags.joined(separator: "、"))
    }

    var body: some View {
        Form {
            Section("基本信息") {
                TextField("菜名", text: $draft.name)
                    .onChange(of: draft.name) { _, value in
                        if value.count > 40 { draft.name = String(value.prefix(40)) }
                    }

                Picker("分类", selection: $draft.category) {
                    ForEach(DishCategory.all) { item in
                        Text("\(item.emoji) \(item.name)").tag(item.key)
                    }
                }

                Picker("类型", selection: $draft.kind) {
                    Text("荤菜").tag("荤")
                    Text("素菜").tag("素")
                    Text("汤水").tag("汤")
                    Text("蛋类").tag("蛋")
                    Text("豆制品").tag("豆")
                }

                Stepper(value: $draft.minutes, in: 5...240, step: 5) {
                    HStack {
                        Text("耗时")
                        Spacer()
                        Text("\(draft.minutes) 分钟").foregroundStyle(.secondary)
                    }
                }

                Picker("难度", selection: $draft.difficulty) {
                    Text("简单").tag(1)
                    Text("中等").tag(2)
                    Text("有点讲究").tag(3)
                }

                Picker("辣度", selection: $draft.spicy) {
                    Text("不辣").tag(0)
                    Text("微辣").tag(1)
                    Text("中辣").tag(2)
                    Text("很辣").tag(3)
                }

                Stepper(value: $draft.baseServings, in: 1...8) {
                    HStack {
                        Text("基准份量")
                        Spacer()
                        Text("\(draft.baseServings) 人").foregroundStyle(.secondary)
                    }
                }

                TextField("标签，用顿号分隔（如：下饭、快手）", text: $tagText)
            }

            Section {
                ForEach($draft.ingredients) { $item in
                    VStack(spacing: 6) {
                        HStack {
                            TextField("食材", text: $item.name)
                                .onChange(of: item.name) { _, value in
                                    if value.count > 20 { item.name = String(value.prefix(20)) }
                                }
                            Divider()
                            TextField("用量", text: $item.amount)
                                .frame(maxWidth: 110)
                                .onChange(of: item.amount) { _, value in
                                    if value.count > 20 { item.amount = String(value.prefix(20)) }
                                }
                        }
                        Picker("分组", selection: $item.group) {
                            Text("主料").tag("主料")
                            Text("调料").tag("调料")
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.vertical, 2)
                }
                .onDelete { offsets in
                    draft.ingredients.remove(atOffsets: offsets)
                }

                Menu {
                    Button("加一样主料") {
                        draft.ingredients.append(Ingredient(name: "", amount: "", group: "主料"))
                    }
                    Button("加一样调料") {
                        draft.ingredients.append(Ingredient(name: "", amount: "", group: "调料"))
                    }
                } label: {
                    Label("添加配料", systemImage: "plus.circle")
                }
            } header: {
                Text("配料")
            } footer: {
                Text("左滑可以删掉一行。用量写成「200 克」「1 勺」这样，改份量时能自动换算。")
            }

            Section {
                ForEach(draft.steps.indices, id: \.self) { index in
                    HStack(alignment: .top) {
                        Text("\(index + 1)")
                            .font(.callout.bold())
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 22)
                        TextField("第 \(index + 1) 步", text: Binding(
                            get: { draft.steps[safe: index] ?? "" },
                            set: { value in
                                guard draft.steps.indices.contains(index) else { return }
                                draft.steps[index] = String(value.prefix(200))
                            }
                        ), axis: .vertical)
                        .lineLimit(1...4)
                    }
                }
                .onDelete { offsets in
                    draft.steps.remove(atOffsets: offsets)
                }

                Button {
                    draft.steps.append("")
                } label: {
                    Label("加一步", systemImage: "plus.circle")
                }
            } header: {
                Text("做法")
            } footer: {
                Text("步骤里写「5 分钟」这样的时间，做饭模式就能一键计时。")
            }

            Section("关键窍门") {
                TextField("一句话说清这道菜最容易翻车的地方", text: $draft.tips, axis: .vertical)
                    .lineLimit(2...5)
                    .onChange(of: draft.tips) { _, value in
                        if value.count > 300 { draft.tips = String(value.prefix(300)) }
                    }
            }
        }
        .navigationTitle(isNew ? "新增菜谱" : "编辑菜谱")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") { save() }
                    .disabled(draft.name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func save() {
        var cleaned = draft
        cleaned.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        cleaned.tags = tagText
            .split(whereSeparator: { "、,， ".contains($0) })
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        cleaned.ingredients = draft.ingredients
            .filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
        cleaned.steps = draft.steps
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        cleaned.source = isNew ? "手写" : draft.source
        cleaned.updatedAt = Date()
        store.upsert(cleaned)
        dismiss()
    }
}
