import SwiftUI

struct RecipeDetailView: View {
    @Environment(RecipeStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let recipeID: String

    @State private var servings: Int
    @State private var checked: Set<UUID> = []
    @State private var showCooking = false
    @State private var showEditor = false
    @State private var showDeleteConfirm = false
    @State private var showPlanPicker = false
    @State private var feedbackTrigger = 0

    init(recipeID: String, servings: Int = 2) {
        self.recipeID = recipeID
        _servings = State(initialValue: servings)
    }

    var body: some View {
        Group {
            if let recipe = store.recipe(id: recipeID) {
                content(recipe)
            } else {
                EmptyHint(title: "这道菜不在了", message: "可能已被删除，回到列表看看别的", systemImage: "questionmark.folder")
            }
        }
        .navigationTitle(store.recipe(id: recipeID)?.name ?? "菜谱")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let recipe = store.recipe(id: recipeID) {
                    Menu {
                        Button {
                            showEditor = true
                        } label: {
                            Label("编辑这道菜", systemImage: "square.and.pencil")
                        }
                        Button {
                            store.toggleFavorite(recipe)
                        } label: {
                            Label(store.favorites.contains(recipe.id) ? "取消收藏" : "收藏",
                                  systemImage: store.favorites.contains(recipe.id) ? "star.slash" : "star")
                        }
                        Button {
                            showPlanPicker = true
                        } label: {
                            Label("排进这周的菜单", systemImage: "calendar")
                        }
                        ShareLink(item: shareText(recipe)) {
                            Label("分享文字版", systemImage: "square.and.arrow.up")
                        }
                        Divider()
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("更多操作")
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            if let recipe = store.recipe(id: recipeID) {
                NavigationStack {
                    RecipeEditorView(recipe: recipe, isNew: false)
                        .environment(store)
                }
            }
        }
        .confirmationDialog("确定删除这道菜？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                if let recipe = store.recipe(id: recipeID) {
                    store.delete(recipe)
                }
                dismiss()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除后只能通过「恢复内置菜谱」找回内置菜，自己写的菜找不回来。")
        }
        .sensoryFeedback(.success, trigger: feedbackTrigger)
    }

    // MARK: 主体

    private func content(_ recipe: Recipe) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                header(recipe)

                GroupBox {
                    VStack(spacing: 10) {
                        HStack {
                            Text("份量")
                            Spacer()
                            Stepper("\(servings) 人", value: $servings, in: 1...8)
                                .fixedSize()
                        }
                        Divider()
                        ingredientList(recipe)
                    }
                    .padding(.vertical, 4)
                } label: {
                    Label("配料", systemImage: "list.bullet")
                        .font(.headline)
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: 10) {
                                Text("\(index + 1)")
                                    .font(.system(size: 17, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.accentColor)
                                    .monospacedDigit()
                                    .frame(width: 24, alignment: .leading)
                                Text(step)
                                    .font(.body)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                } label: {
                    Label("做法（\(recipe.steps.count) 步）", systemImage: "flame")
                        .font(.headline)
                }

                if !recipe.tips.isEmpty {
                    GroupBox {
                        Text(recipe.tips)
                            .font(.callout)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 2)
                    } label: {
                        Label("关键窍门", systemImage: "lightbulb")
                            .font(.headline)
                    }
                }

                footer(recipe)
            }
            .padding(16)
            .padding(.bottom, 12)
        }
        .safeAreaInset(edge: .bottom) {
            actionBar(recipe)
        }
        .fullScreenCover(isPresented: $showCooking) {
            CookingModeView(recipe: recipe, servings: servings)
        }
        .sheet(isPresented: $showPlanPicker) {
            PlanSlotPicker(recipe: recipe) { day, slot in
                store.setPlan(day: day, slot: slot, recipe: recipe)
                feedbackTrigger += 1
            }
            .environment(store)
        }
    }

    private func header(_ recipe: Recipe) -> some View {
        VStack(spacing: 8) {
            Text(recipe.emoji)
                .font(.system(size: 44))
                .accessibilityHidden(true)
            HStack(spacing: 8) {
                Text(recipe.name)
                    .font(.title.bold())
                if store.favorites.contains(recipe.id) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .accessibilityLabel("已收藏")
                }
            }
            Text("\(recipe.categoryName) · \(recipe.kindLabel)")
                .font(.footnote)
                .foregroundStyle(.secondary)
            RecipeMetaLine(recipe: recipe)
            if !recipe.tags.isEmpty {
                Text(recipe.tags.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    private func ingredientList(_ recipe: Recipe) -> some View {
        let main = recipe.mainIngredients
        let seasonings = recipe.seasonings
        return VStack(alignment: .leading, spacing: 12) {
            if !main.isEmpty {
                ingredientGroup(title: "主料", items: main, recipe: recipe)
            }
            if !seasonings.isEmpty {
                ingredientGroup(title: "调料", items: seasonings, recipe: recipe)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func ingredientGroup(title: String, items: [Ingredient], recipe: Recipe) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(items) { item in
                HStack(spacing: 8) {
                    Image(systemName: checked.contains(item.id) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(checked.contains(item.id) ? Color.accentColor : Color.secondary)
                    Text(item.name)
                        .strikethrough(checked.contains(item.id))
                    Spacer()
                    Text(recipe.scaledAmount(item.amount, servings: servings))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .font(.callout)
                .frame(minHeight: 32)
                .contentShape(Rectangle())
                .onTapGesture {
                    if checked.contains(item.id) {
                        checked.remove(item.id)
                    } else {
                        checked.insert(item.id)
                    }
                }
            }
        }
    }

    private func footer(_ recipe: Recipe) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                Text(store.cookCount(for: recipe) == 0 ? "还没做过这道菜" : "已经做过 \(store.cookCount(for: recipe)) 次")
                Text("来源：\(recipe.source) · 最后修改 \(DayFormat.monthDay.string(from: recipe.updatedAt))")
                Text("用量按 \(recipe.baseServings) 人份记录，改份量会自动换算，只能换数字开头的用量。")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func actionBar(_ recipe: Recipe) -> some View {
        HStack(spacing: 10) {
            Button {
                showCooking = true
            } label: {
                Label("开始做菜", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
            }
            .liquidGlassButton()

            Button {
                store.addToShopping(recipe, servings: servings)
                feedbackTrigger += 1
            } label: {
                Image(systemName: "cart.badge.plus")
                    .frame(width: 44, height: 44)
            }
            .liquidGlassButton()
            .accessibilityLabel("配料加入购物清单")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private func shareText(_ recipe: Recipe) -> String {
        var lines: [String] = ["【\(recipe.name)】\(recipe.minutes) 分钟 · \(recipe.difficultyLabel)"]
        lines.append("")
        lines.append("配料（\(servings) 人份）：")
        for item in recipe.ingredients {
            lines.append("· \(item.name) \(recipe.scaledAmount(item.amount, servings: servings))")
        }
        lines.append("")
        lines.append("做法：")
        for (index, step) in recipe.steps.enumerated() {
            lines.append("\(index + 1). \(step)")
        }
        if !recipe.tips.isEmpty {
            lines.append("")
            lines.append("窍门：\(recipe.tips)")
        }
        lines.append("")
        lines.append("—— 来自《今晚吃什么》")
        return lines.joined(separator: "\n")
    }
}
