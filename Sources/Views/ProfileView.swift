import SwiftUI

struct ProfileView: View {
    @Environment(RecipeStore.self) private var store

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        Text("🍚")
                            .font(.system(size: 40))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("今晚吃什么")
                                .font(.headline)
                            Text("\(store.recipes.count) 道菜 · 已做 \(store.records.count) 次 · \(store.plan.count) 顿有安排")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("我的") {
                    NavigationLink {
                        FavoritesView()
                    } label: {
                        HStack {
                            Label("收藏的菜", systemImage: "star")
                            Spacer()
                            Text("\(store.favorites.count)")
                                .foregroundStyle(.secondary)
                        }
                    }

                    NavigationLink {
                        HistoryView()
                    } label: {
                        HStack {
                            Label("做饭记录", systemImage: "clock.arrow.circlepath")
                            Spacer()
                            Text("\(store.records.count) 次")
                                .foregroundStyle(.secondary)
                        }
                    }

                    NavigationLink {
                        MyRecipesView()
                    } label: {
                        Label("自己写的菜", systemImage: "square.and.pencil")
                    }
                }

                Section {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("设置", systemImage: "gearshape")
                    }
                }

                Section {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("菜谱来源")
                        Spacer()
                        Text("内置家庭菜谱")
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("菜谱和你的修改都存在手机本地，不上传任何服务器。")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("我的")
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

struct FavoritesView: View {
    @Environment(RecipeStore.self) private var store

    var body: some View {
        List {
            if store.favoriteRecipes.isEmpty {
                EmptyHint(title: "还没有收藏", message: "在菜谱上左滑，或者进详情页点星标。", systemImage: "star")
                    .listRowBackground(Color.clear)
            }
            ForEach(store.favoriteRecipes) { recipe in
                NavigationLink {
                    RecipeDetailView(recipeID: recipe.id)
                } label: {
                    RecipeRow(recipe: recipe, isFavorite: true)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        store.toggleFavorite(recipe)
                    } label: {
                        Label("取消收藏", systemImage: "star.slash")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("收藏")
    }
}

struct MyRecipesView: View {
    @Environment(RecipeStore.self) private var store

    private var mine: [Recipe] {
        store.recipes.filter { $0.source != "内置菜谱" }
    }

    var body: some View {
        List {
            if mine.isEmpty {
                EmptyHint(title: "还没有自己写的菜", message: "菜谱页右上角的加号，随时加一道自己的。", systemImage: "square.and.pencil")
                    .listRowBackground(Color.clear)
            }
            ForEach(mine) { recipe in
                NavigationLink {
                    RecipeDetailView(recipeID: recipe.id)
                } label: {
                    RecipeRow(recipe: recipe, isFavorite: store.favorites.contains(recipe.id))
                }
            }
            .onDelete { offsets in
                offsets.map { mine[$0] }.forEach(store.delete)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("自己写的菜")
    }
}

struct HistoryView: View {
    @Environment(RecipeStore.self) private var store

    private struct DayGroup: Identifiable {
        let key: String
        let records: [CookRecord]
        var id: String { key }
    }

    private var groups: [DayGroup] {
        let grouped = Dictionary(grouping: store.records) { DayFormat.key.string(from: $0.date) }
        return grouped
            .map { DayGroup(key: $0.key, records: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.key > $1.key }
    }

    var body: some View {
        List {
            if store.records.isEmpty {
                EmptyHint(title: "还没有做饭记录", message: "每次抽中一道菜并确认，就会记一笔。", systemImage: "clock")
                    .listRowBackground(Color.clear)
            }

            ForEach(groups) { group in
                Section {
                    ForEach(group.records) { record in
                        HStack {
                            NavigationLink {
                                RecipeDetailView(recipeID: record.recipeID)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(record.recipeName)
                                    HStack(spacing: 8) {
                                        Text(DayFormat.time.string(from: record.date))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        if record.rating > 0 {
                                            Label("\(record.rating)", systemImage: "star.fill")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        } else {
                                            Text("还没打分")
                                                .font(.caption2)
                                                .foregroundStyle(.tertiary)
                                        }
                                        if !record.note.isEmpty {
                                            Text(record.note)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                }
                                .padding(.vertical, 2)
                            }

                            Menu {
                                ForEach(1...5, id: \.self) { star in
                                    Button("\(star) 星") {
                                        store.rate(record, stars: star)
                                    }
                                }
                                if record.rating > 0 {
                                    Divider()
                                    Button("清掉评分") {
                                        store.rate(record, stars: 0)
                                    }
                                }
                            } label: {
                                Image(systemName: record.rating > 0 ? "star.circle.fill" : "star.circle")
                                    .foregroundStyle(record.rating > 0 ? Color.orange : Color.secondary)
                            }
                            .accessibilityLabel("给这道菜打分")
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                store.deleteRecord(record)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    Text(dayTitle(group.key))
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("做饭记录")
    }

    private func dayTitle(_ key: String) -> String {
        guard let date = DayFormat.key.date(from: key) else { return key }
        let prefix = Calendar.current.isDateInToday(date) ? "今天 · " : ""
        return prefix + DayFormat.monthDay.string(from: date)
    }
}

/// 详情页里“排进这周菜单”的弹窗。
struct PlanSlotPicker: View {
    @Environment(RecipeStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let recipe: Recipe
    let onSelect: (Date, String) -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(DayFormat.daysFromToday(7), id: \.self) { day in
                    Section {
                        ForEach(["午", "晚"], id: \.self) { slot in
                            let entry = store.planEntry(day: day, slot: slot)
                            HStack {
                                Text(slot)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20)
                                Text(entry.map { "\($0.recipeName)" } ?? "空着")
                                    .foregroundStyle(entry == nil ? .secondary : .primary)
                                Spacer()
                                Image(systemName: "plus.circle")
                                    .foregroundStyle(.tertiary)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onSelect(day, slot)
                                dismiss()
                            }
                        }
                    } header: {
                        Text(DayFormat.monthDay.string(from: day) + " " + DayFormat.weekday.string(from: day))
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("排到哪一顿")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}
