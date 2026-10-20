import SwiftUI

/// 清单页：左边是购物清单，右边是这周的菜单，都是“决定之后要落地”的东西。
struct ShoppingView: View {
    @Environment(RecipeStore.self) private var store

    @State private var tab = 0
    @State private var showRecipePicker = false
    @State private var pickerSlot: PlanTarget?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("视图", selection: $tab) {
                        Text("购物清单").tag(0)
                        Text("这周菜单").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                }

                if tab == 0 {
                    shoppingContent
                } else {
                    planContent
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(tab == 0 ? "购物清单" : "这周菜单")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if tab == 0 {
                        Menu {
                            Button {
                                showRecipePicker = true
                            } label: {
                                Label("从菜谱加配料", systemImage: "book")
                            }
                            Button {
                                store.clearDoneShopping()
                            } label: {
                                Label("清掉已买的", systemImage: "checkmark.circle")
                            }
                            .disabled(store.shopping.allSatisfy { !$0.done })
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        .accessibilityLabel("清单操作")
                    } else {
                        Button {
                            store.fillEmptyDinners()
                        } label: {
                            Image(systemName: "wand.and.stars")
                        }
                        .accessibilityLabel("自动排满晚餐")
                    }
                }
            }
            .sheet(isPresented: $showRecipePicker) {
                RecipePickerSheet(title: "加入购物清单") { recipe in
                    store.addToShopping(recipe)
                }
                .environment(store)
            }
            .sheet(item: $pickerSlot) { target in
                RecipePickerSheet(title: "选一道菜") { recipe in
                    store.setPlan(day: target.day, slot: target.slot, recipe: recipe)
                }
                .environment(store)
            }
        }
    }

    // MARK: 购物清单

    private var pendingItems: [ShoppingItem] { store.shopping.filter { !$0.done } }
    private var doneItems: [ShoppingItem] { store.shopping.filter { $0.done } }

    @ViewBuilder
    private var shoppingContent: some View {
        if store.shopping.isEmpty {
            Section {
                EmptyHint(
                    title: "清单还是空的",
                    message: "在菜谱里点「加入购物清单」，或者从右上角直接按菜谱加。",
                    systemImage: "cart"
                )
                .listRowBackground(Color.clear)
            }
        } else {
            Section {
                ForEach(pendingItems) { item in
                    shoppingRow(item)
                }
                .onDelete { offsets in
                    offsets.map { pendingItems[$0] }.forEach(store.deleteShopping)
                }
            } header: {
                Text("要买 \(pendingItems.count) 样")
            }

            if !doneItems.isEmpty {
                Section("已经买到") {
                    ForEach(doneItems) { item in
                        shoppingRow(item)
                    }
                    .onDelete { offsets in
                        offsets.map { doneItems[$0] }.forEach(store.deleteShopping)
                    }
                }
            }
        }
    }

    private func shoppingRow(_ item: ShoppingItem) -> some View {
        HStack(spacing: 10) {
            Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(item.done ? Color.accentColor : Color.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .strikethrough(item.done)
                    .foregroundStyle(item.done ? .secondary : .primary)
                if !item.fromRecipe.isEmpty {
                    Text(item.fromRecipe)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Text(item.amount)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(minHeight: 40)
        .contentShape(Rectangle())
        .onTapGesture {
            store.toggleShopping(item)
        }
    }

    // MARK: 周菜单

    @ViewBuilder
    private var planContent: some View {
        ForEach(DayFormat.daysFromToday(7), id: \.self) { day in
            Section {
                planRow(day: day, slot: "午")
                planRow(day: day, slot: "晚")
            } header: {
                HStack {
                    Text(dayTitle(day))
                    Spacer()
                    Text(DayFormat.key.string(from: day))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func planRow(day: Date, slot: String) -> some View {
        let entry = store.planEntry(day: day, slot: slot)
        return HStack {
            Text(slot)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            HStack {
                Text(entry?.recipeName ?? "还没定")
                    .foregroundStyle(entry == nil ? .secondary : .primary)
                Spacer()
                Image(systemName: "plus.circle")
                    .font(.body)
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                pickerSlot = PlanTarget(day: day, slot: slot)
            }
        }
        .frame(minHeight: 36)
        .swipeActions(edge: .trailing) {
            if entry != nil {
                Button(role: .destructive) {
                    store.removePlan(day: day, slot: slot)
                } label: {
                    Label("清掉", systemImage: "trash")
                }
            }
        }
    }

    private func dayTitle(_ day: Date) -> String {
        let calendar = Calendar.current
        let prefix: String
        if calendar.isDateInToday(day) {
            prefix = "今天 · "
        } else if calendar.isDateInTomorrow(day) {
            prefix = "明天 · "
        } else {
            prefix = ""
        }
        return prefix + DayFormat.monthDay.string(from: day) + " " + DayFormat.weekday.string(from: day)
    }
}

struct PlanTarget: Identifiable {
    let day: Date
    let slot: String
    var id: String { DayFormat.key.string(from: day) + slot }
}

/// 选菜弹窗：搜索 + 分类，抽签抽烦了可以直接点。
struct RecipePickerSheet: View {
    @Environment(RecipeStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let title: String
    let onSelect: (Recipe) -> Void

    @State private var keyword = ""
    @State private var category = ""

    var body: some View {
        NavigationStack {
            List {
                if results.isEmpty {
                    EmptyHint(title: "没找到", message: "换个关键词试试", systemImage: "magnifyingglass")
                        .listRowBackground(Color.clear)
                }
                ForEach(results) { recipe in
                    RecipeRow(recipe: recipe, isFavorite: store.favorites.contains(recipe.id))
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onSelect(recipe)
                            dismiss()
                        }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $keyword, prompt: "搜菜名或食材")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("全部") { category = "" }
                        ForEach(DishCategory.all) { item in
                            Button(item.name) { category = item.key }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                    .accessibilityLabel("按分类筛选")
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }

    private var results: [Recipe] {
        store.filtered(category: category, keyword: keyword, favoritesOnly: false, sort: .default)
    }
}
