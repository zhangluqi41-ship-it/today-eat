import SwiftUI

struct TonightView: View {
    @Environment(RecipeStore.self) private var store

    @State private var rollingName: String?
    @State private var picked: Recipe?
    @State private var isRolling = false
    @State private var showTripleChoice = false
    @State private var detailRecipe: Recipe?
    @State private var feedbackTrigger = 0

    var body: some View {
        @Bindable var store = store

        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let message = store.loadMessage {
                        DataWarningCard(message: message) { store.retryLoadIfNeeded() }
                    }

                    resultCard

                    GroupBox {
                        VStack(spacing: 0) {
                            kindRow
                            Divider().padding(.vertical, 10)

                            Stepper(value: $store.settings.maxMinutes, in: 15...180, step: 15) {
                                HStack {
                                    Text("最多花多少时间")
                                    Spacer()
                                    Text(store.settings.maxMinutes >= 180 ? "不限" : "\(store.settings.maxMinutes) 分钟")
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Divider().padding(.vertical, 10)

                            Stepper(value: $store.settings.maxSpicy, in: 0...3) {
                                HStack {
                                    Text("辣度上限")
                                    Spacer()
                                    Text(spicyText(store.settings.maxSpicy))
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Divider().padding(.vertical, 10)

                            Toggle("跳过最近吃过的", isOn: $store.settings.avoidRecent)

                            if store.settings.avoidRecent {
                                Stepper(value: $store.settings.avoidDays, in: 1...30) {
                                    HStack {
                                        Text("回看天数")
                                        Spacer()
                                        Text("\(store.settings.avoidDays) 天")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.top, 4)
                            }

                            Divider().padding(.vertical, 10)

                            HStack {
                                Text("现在有 \(pool.count) 道可选")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                if !store.settings.dislikes.isEmpty {
                                    Label("忌口 \(store.settings.dislikes.count) 项", systemImage: "nosign")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.top, 4)
                    } label: {
                        Label("抽签范围", systemImage: "slider.horizontal.3")
                            .font(.headline)
                    }

                    GroupBox {
                        VStack(spacing: 10) {
                            Button {
                                showTripleChoice = true
                            } label: {
                                Label("三选一", systemImage: "square.grid.3x1.below.line.grid.1x2")
                                    .frame(maxWidth: .infinity)
                            }
                            .liquidGlassButton()
                            .disabled(pool.isEmpty)

                            Button {
                                store.fillEmptyDinners()
                                feedbackTrigger += 1
                            } label: {
                                Label("把这一周的晚餐排满", systemImage: "calendar.badge.plus")
                                    .frame(maxWidth: .infinity)
                            }
                            .liquidGlassButton()
                        }
                        .padding(.vertical, 2)
                    }

                    if !recentRecords.isEmpty {
                        GroupBox {
                            VStack(spacing: 0) {
                                ForEach(recentRecords) { record in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(record.recipeName)
                                                .lineLimit(1)
                                            Text("\(DayFormat.monthDay.string(from: record.date)) \(DayFormat.time.string(from: record.date))")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        if record.rating > 0 {
                                            Label("\(record.rating)", systemImage: "star.fill")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .labelStyle(.titleAndIcon)
                                        }
                                        Button("再吃") {
                                            if let recipe = store.recipe(id: record.recipeID) {
                                                store.markCooked(recipe)
                                                picked = recipe
                                                detailRecipe = recipe
                                            }
                                        }
                                        .font(.footnote)
                                        .liquidGlassButton()
                                    }
                                    .padding(.vertical, 6)
                                    if record.id != recentRecords.last?.id {
                                        Divider()
                                    }
                                }
                            }
                        } label: {
                            Label("最近吃过", systemImage: "clock.arrow.circlepath")
                                .font(.headline)
                        }
                    }
                }
                .padding(16)
            }
            .navigationTitle("今晚吃什么")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        HistoryView()
                    } label: {
                        Image(systemName: "clock")
                    }
                    .accessibilityLabel("做饭记录")
                }
            }
            .onChange(of: store.settings) { _, _ in
                store.scheduleSave()
            }
            .sheet(isPresented: $showTripleChoice) {
                TripleChoiceView { recipe in
                    showTripleChoice = false
                    picked = recipe
                    store.markCooked(recipe)
                    detailRecipe = recipe
                }
                .environment(store)
            }
            .sheet(item: $detailRecipe) { recipe in
                NavigationStack {
                    RecipeDetailView(recipeID: recipe.id)
                        .environment(store)
                }
            }
            .sensoryFeedback(.success, trigger: feedbackTrigger)
        }
    }

    // MARK: 抽签结果

    private var resultCard: some View {
        GroupBox {
            VStack(spacing: 10) {
                Text(picked?.emoji ?? "🎲")
                    .font(.system(size: 54))
                    .accessibilityHidden(true)

                Text(displayName)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .contentTransition(.opacity)

                if let picked {
                    RecipeMetaLine(recipe: picked)
                    if !picked.tags.isEmpty {
                        Text(picked.tags.prefix(3).joined(separator: " · "))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("不想动脑子的时候，点下面那个按钮")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    Button {
                        roll()
                    } label: {
                        Label(isRolling ? "正在抽" : "抽一个", systemImage: "dice.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .liquidGlassButton()
                    .disabled(isRolling || pool.isEmpty)

                    Button {
                        decide()
                    } label: {
                        Label("就它了", systemImage: "checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .liquidGlassButton()
                    .disabled(picked == nil || isRolling)
                }
                .padding(.top, 4)
            }
            .padding(.vertical, 6)
        } label: {
            Text("今晚这道").font(.headline)
        }
    }

    private var displayName: String {
        if let rollingName { return rollingName }
        return picked?.name ?? "还没抽"
    }

    // MARK: 类型菜单

    private var kindRow: some View {
        @Bindable var store = store
        return HStack {
            Text("只要")
            Spacer()
            Menu {
                Button("不限") { store.settings.kindFilter = "" }
                Button("荤菜") { store.settings.kindFilter = "荤" }
                Button("素菜") { store.settings.kindFilter = "素" }
                Button("汤汤水水") { store.settings.kindFilter = "汤" }
                Button("蛋类") { store.settings.kindFilter = "蛋" }
                Button("豆制品") { store.settings.kindFilter = "豆" }
            } label: {
                HStack(spacing: 4) {
                    Text(store.settings.kindFilter.isEmpty ? "不限" : kindName(store.settings.kindFilter))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                }
            }
        }
    }

    // MARK: 行为

    private var pool: [Recipe] { store.pickPool() }

    private var recentRecords: [CookRecord] { Array(store.records.prefix(3)) }

    private func roll() {
        let candidates = pool
        guard !candidates.isEmpty else { return }
        isRolling = true
        picked = nil

        Task { @MainActor in
            // 老虎机效果：快速掠过菜名，最后停在一个结果上。
            for _ in 0..<16 {
                rollingName = candidates.randomElement()?.name
                try? await Task.sleep(for: .milliseconds(70))
            }
            let result = candidates.randomElement()
            rollingName = nil
            picked = result
            isRolling = false
            feedbackTrigger += 1
        }
    }

    private func decide() {
        guard let picked else { return }
        store.markCooked(picked)
        detailRecipe = picked
        feedbackTrigger += 1
    }

    private func spicyText(_ level: Int) -> String {
        switch level {
        case 0: return "不辣"
        case 1: return "微辣"
        case 2: return "中辣"
        default: return "很辣"
        }
    }

    private func kindName(_ kind: String) -> String {
        switch kind {
        case "荤": return "荤菜"
        case "素": return "素菜"
        case "汤": return "汤汤水水"
        case "蛋": return "蛋类"
        case "豆": return "豆制品"
        default: return kind
        }
    }
}

/// 加载异常时给一条能操作的提示，而不是白屏或全屏转圈。
struct DataWarningCard: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Label("数据状态", systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(message)
                    .font(.footnote)
                Button("重试读取", action: retry)
                    .font(.footnote)
                    .liquidGlassButton()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// 三选一：更省脑子的抽签方式。
struct TripleChoiceView: View {
    @Environment(RecipeStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let onPick: (Recipe) -> Void

    @State private var candidates: [Recipe] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if candidates.isEmpty {
                        EmptyHint(title: "没有符合条件的菜", message: "放宽时间或辣度限制再试试", systemImage: "line.3.horizontal.decrease.circle")
                            .padding(.top, 40)
                    }

                    ForEach(candidates) { recipe in
                        GroupBox {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(recipe.emoji)
                                    Text(recipe.name)
                                        .font(.title3.bold())
                                    Spacer()
                                }
                                RecipeMetaLine(recipe: recipe)
                                Text(recipe.mainIngredients.prefix(4).map(\.name).joined(separator: "、"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                Button {
                                    onPick(recipe)
                                } label: {
                                    Text("就吃这个")
                                        .frame(maxWidth: .infinity)
                                }
                                .liquidGlassButton()
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    Button {
                        reshuffle()
                    } label: {
                        Label("换一批", systemImage: "arrow.triangle.2.circlepath")
                            .frame(maxWidth: .infinity)
                    }
                    .liquidGlassButton()
                    .padding(.top, 4)
                }
                .padding(16)
            }
            .navigationTitle("三选一")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .onAppear(perform: reshuffle)
        }
    }

    private func reshuffle() {
        candidates = Array(store.pickPool().shuffled().prefix(3))
    }
}
