import Foundation
import Observation
import SwiftUI

/// 全 App 唯一的数据源。菜谱、收藏、记录、清单、计划、设置都存在同一个 JSON 里。
/// 写盘规则严格按项目规范：Application Support + 收窄 catch + 加载成功才允许写。
@Observable
final class RecipeStore {

    // MARK: 状态

    var recipes: [Recipe] = []
    var favorites: Set<String> = []
    var records: [CookRecord] = []
    var shopping: [ShoppingItem] = []
    var plan: [PlanEntry] = []
    var settings: AppSettings = AppSettings()
    var inventory: [String] = []

    /// 加载失败时的提示，页面顶部会显示一条可重试的提示。
    var loadMessage: String?

    private var loadSucceeded = false
    private var saveTask: Task<Void, Never>?

    // MARK: 路径

    static var folderURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("TodayEat", isDirectory: true)
    }

    static var dataURL: URL { folderURL.appendingPathComponent("data.json") }

    // MARK: 生命周期

    init() {
        load()
    }

    /// 首次启动：用户文件不存在时用内置菜谱建库。
    /// 只有 DecodingError 才判定为“文件损坏”，其它错误一律保留原文件并允许重试。
    func load() {
        let fileManager = FileManager.default
        let url = Self.dataURL

        guard fileManager.fileExists(atPath: url.path) else {
            seedFromBundle()
            return
        }

        do {
            let raw = try Data(contentsOf: url)
            let data = try JSONDecoder().decode(AppData.self, from: raw)
            apply(data)
            loadSucceeded = true
            loadMessage = nil
        } catch let error as DecodingError {
            // 真的解不出来才算损坏：改名留档，再用内置菜谱起一份新的，避免白屏。
            let backup = url.deletingPathExtension().appendingPathExtension("corrupt.json")
            try? fileManager.removeItem(at: backup)
            try? fileManager.moveItem(at: url, to: backup)
            seedFromBundle()
            loadMessage = "数据文件格式异常，已备份为 data.corrupt.json 并载入内置菜谱。"
            _ = error
        } catch {
            // 权限被拒 / IO 失败：绝不能当成损坏，也不许覆盖写。
            loadMessage = "读取本地数据失败：\(error.localizedDescription)。稍后会自动重试。"
        }
    }

    /// 挂在首屏 onAppear 和回到前台时，专门补上“上次没读成功”的情况。
    func retryLoadIfNeeded() {
        guard !loadSucceeded else { return }
        load()
    }

    private func seedFromBundle() {
        guard let url = Bundle.main.url(forResource: "SeedRecipes", withExtension: "json"),
              let raw = try? Data(contentsOf: url),
              let payload = try? JSONDecoder().decode(SeedPayload.self, from: raw) else {
            loadMessage = "内置菜谱读取失败，请重新安装 App。"
            return
        }
        recipes = payload.dishes
        loadSucceeded = true
        loadMessage = nil
        persist()
    }

    // MARK: 保存

    /// 合并短时间内的多次修改，避免每次输入都写盘。
    func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            self?.persist()
        }
    }

    func persist() {
        guard loadSucceeded else { return }
        let data = AppData(
            schemaVersion: 1,
            recipes: recipes,
            favorites: Array(favorites),
            records: records,
            shopping: shopping,
            plan: plan,
            settings: settings,
            inventory: inventory
        )
        do {
            try FileManager.default.createDirectory(at: Self.folderURL, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.withoutEscapingSlashes]
            let raw = try encoder.encode(data)
            try raw.write(to: Self.dataURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            loadMessage = nil
        } catch {
            loadMessage = "保存失败：\(error.localizedDescription)"
        }
    }

    private func apply(_ data: AppData) {
        recipes = data.recipes
        favorites = Set(data.favorites)
        records = data.records
        shopping = data.shopping
        plan = data.plan
        settings = data.settings
        inventory = data.inventory
    }

    // MARK: 查询

    func recipe(id: String) -> Recipe? {
        recipes.first { $0.id == id }
    }

    var favoriteRecipes: [Recipe] {
        recipes.filter { favorites.contains($0.id) }
    }

    func recipes(in category: String) -> [Recipe] {
        recipes.filter { $0.category == category }
    }

    /// 搜索 + 分类 + 只看收藏，菜谱页和选菜弹窗共用。
    func filtered(category: String?, keyword: String, favoritesOnly: Bool, sort: RecipeSort) -> [Recipe] {
        var result = recipes
        if let category, !category.isEmpty {
            result = result.filter { $0.category == category }
        }
        if favoritesOnly {
            result = result.filter { favorites.contains($0.id) }
        }
        if !keyword.isEmpty {
            result = result.filter { $0.matches(keyword: keyword) }
        }
        switch sort {
        case .default:
            result.sort { lhs, rhs in
                if lhs.category != rhs.category {
                    return (DishCategory.all.firstIndex { $0.key == lhs.category } ?? 99)
                        < (DishCategory.all.firstIndex { $0.key == rhs.category } ?? 99)
                }
                return lhs.name < rhs.name
            }
        case .quick:
            result.sort { $0.minutes < $1.minutes }
        case .newest:
            result.sort { $0.updatedAt > $1.updatedAt }
        }
        return result
    }

    // MARK: 菜谱增删改

    func upsert(_ recipe: Recipe) {
        var copy = recipe
        copy.updatedAt = Date()
        if let index = recipes.firstIndex(where: { $0.id == copy.id }) {
            recipes[index] = copy
        } else {
            recipes.append(copy)
        }
        persist()
    }

    func delete(_ recipe: Recipe) {
        recipes.removeAll { $0.id == recipe.id }
        favorites.remove(recipe.id)
        plan.removeAll { $0.recipeID == recipe.id }
        persist()
    }

    func toggleFavorite(_ recipe: Recipe) {
        if favorites.contains(recipe.id) {
            favorites.remove(recipe.id)
        } else {
            favorites.insert(recipe.id)
        }
        persist()
    }

    @discardableResult
    func duplicate(_ recipe: Recipe) -> Recipe {
        var copy = recipe
        copy.id = UUID().uuidString
        copy.name = recipe.name + "（我的版本）"
        copy.source = "手写"
        copy.updatedAt = Date()
        recipes.append(copy)
        persist()
        return copy
    }

    /// 恢复内置菜谱：保留用户自己新增的菜，内置菜回到出厂内容。
    func restoreBuiltInRecipes() {
        guard let url = Bundle.main.url(forResource: "SeedRecipes", withExtension: "json"),
              let raw = try? Data(contentsOf: url),
              let payload = try? JSONDecoder().decode(SeedPayload.self, from: raw) else { return }
        let custom = recipes.filter { $0.source != "内置菜谱" }
        recipes = payload.dishes + custom
        persist()
    }

    // MARK: 抽签

    func pickPool() -> [Recipe] {
        let avoided = recentlyCookedIDs()
        return recipes.filter { recipe in
            if recipe.minutes > settings.maxMinutes { return false }
            if recipe.spicy > settings.maxSpicy { return false }
            if !settings.categoryFilter.isEmpty, recipe.category != settings.categoryFilter { return false }
            if settings.onlyFavorites, !favorites.contains(recipe.id) { return false }
            if settings.avoidRecent, avoided.contains(recipe.id) { return false }
            if settings.dislikes.contains(where: { dislike in
                let word = dislike.trimmingCharacters(in: .whitespaces)
                guard !word.isEmpty else { return false }
                return recipe.ingredients.contains { $0.name.localizedStandardContains(word) }
            }) { return false }
            return true
        }
    }

    func recentlyCookedIDs() -> Set<String> {
        guard settings.avoidDays > 0 else { return [] }
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: -settings.avoidDays, to: Date()) ?? Date()
        return Set(records.filter { $0.date >= cutoff }.map(\.recipeID))
    }

    // MARK: 记录

    func markCooked(_ recipe: Recipe, rating: Int = 0, note: String = "") {
        records.insert(CookRecord(recipeID: recipe.id, recipeName: recipe.name, rating: rating, note: note), at: 0)
        persist()
    }

    func rate(_ record: CookRecord, stars: Int) {
        guard let index = records.firstIndex(where: { $0.id == record.id }) else { return }
        records[index].rating = stars
        persist()
    }

    func deleteRecord(_ record: CookRecord) {
        records.removeAll { $0.id == record.id }
        persist()
    }

    func cookCount(for recipe: Recipe) -> Int {
        records.filter { $0.recipeID == recipe.id }.count
    }

    var averageRating: Double {
        let rated = records.filter { $0.rating > 0 }
        guard !rated.isEmpty else { return 0 }
        return Double(rated.reduce(0) { $0 + $1.rating }) / Double(rated.count)
    }

    // MARK: 冰箱

    func addInventory(_ name: String) {
        let word = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !word.isEmpty, !inventory.contains(word) else { return }
        inventory.append(word)
        persist()
    }

    func removeInventory(_ name: String) {
        inventory.removeAll { $0 == name }
        persist()
    }

    func clearInventory() {
        inventory.removeAll()
        persist()
    }

    func toggleInventory(_ name: String) {
        if inventory.contains(name) {
            removeInventory(name)
        } else {
            addInventory(name)
        }
    }

    // MARK: 常备食材（厨房顶部那一排，可自己编辑）

    func addQuickIngredient(_ name: String) {
        let word = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !word.isEmpty, !settings.quickIngredients.contains(word) else { return }
        settings.quickIngredients.append(word)
        persist()
    }

    func removeQuickIngredient(_ name: String) {
        settings.quickIngredients.removeAll { $0 == name }
        persist()
    }

    func resetQuickIngredients() {
        settings.quickIngredients = AppSettings.defaultQuickIngredients
        persist()
    }

    func moveQuickIngredients(from source: IndexSet, to destination: Int) {
        settings.quickIngredients.move(fromOffsets: source, toOffset: destination)
        persist()
    }

    struct MatchResult: Identifiable {
        let recipe: Recipe
        let matched: [String]
        let missing: [String]

        var id: String { recipe.id }
        var isComplete: Bool { missing.isEmpty }
    }

    /// 只用主料做匹配：调料家家都有，拿调料充数没有意义。
    func matches() -> [MatchResult] {
        let stock = inventory.map { $0.lowercased() }
        guard !stock.isEmpty else { return [] }
        return recipes.compactMap { recipe in
            let main = recipe.mainIngredients
            guard !main.isEmpty else { return nil }
            var matched: [String] = []
            var missing: [String] = []
            for item in main {
                let key = item.name.lowercased()
                let hit = stock.contains { word in
                    key.contains(word) || word.contains(key)
                }
                if hit { matched.append(item.name) } else { missing.append(item.name) }
            }
            guard !matched.isEmpty else { return nil }
            return MatchResult(recipe: recipe, matched: matched, missing: missing)
        }
        .sorted { lhs, rhs in
            if lhs.missing.count != rhs.missing.count { return lhs.missing.count < rhs.missing.count }
            return lhs.matched.count > rhs.matched.count
        }
    }

    // MARK: 购物清单

    func addToShopping(_ recipe: Recipe, servings: Int? = nil) {
        let people = servings ?? settings.servings
        for item in recipe.ingredients {
            let amount = recipe.scaledAmount(item.amount, servings: people)
            if let index = shopping.firstIndex(where: { $0.name == item.name && !$0.done }) {
                shopping[index].amount = mergedAmount(shopping[index].amount, amount)
                shopping[index].fromRecipe = shopping[index].fromRecipe + "、" + recipe.name
            } else {
                shopping.append(ShoppingItem(name: item.name, amount: amount, fromRecipe: recipe.name))
            }
        }
        persist()
    }

    private func mergedAmount(_ lhs: String, _ rhs: String) -> String {
        let left = lhs.trimmingCharacters(in: .whitespaces)
        let right = rhs.trimmingCharacters(in: .whitespaces)
        if left.isEmpty { return right }
        if left == right { return left }
        return left + " + " + right
    }

    func toggleShopping(_ item: ShoppingItem) {
        guard let index = shopping.firstIndex(where: { $0.id == item.id }) else { return }
        shopping[index].done.toggle()
        persist()
    }

    func deleteShopping(_ item: ShoppingItem) {
        shopping.removeAll { $0.id == item.id }
        persist()
    }

    func clearDoneShopping() {
        shopping.removeAll { $0.done }
        persist()
    }

    var pendingShopping: [ShoppingItem] { shopping.filter { !$0.done } }

    // MARK: 周计划

    func planEntry(day: Date, slot: String) -> PlanEntry? {
        let key = DayFormat.key.string(from: day)
        return plan.first { $0.dayKey == key && $0.slot == slot }
    }

    func setPlan(day: Date, slot: String, recipe: Recipe) {
        let key = DayFormat.key.string(from: day)
        if let index = plan.firstIndex(where: { $0.dayKey == key && $0.slot == slot }) {
            plan[index].recipeID = recipe.id
            plan[index].recipeName = recipe.name
        } else {
            plan.append(PlanEntry(dayKey: key, slot: slot, recipeID: recipe.id, recipeName: recipe.name))
        }
        persist()
    }

    func removePlan(day: Date, slot: String) {
        let key = DayFormat.key.string(from: day)
        plan.removeAll { $0.dayKey == key && $0.slot == slot }
        persist()
    }

    func fillEmptyDinners() {
        var pool = recipes
        let existing = Set(plan.map(\.recipeID))
        pool.removeAll { existing.contains($0.id) }
        for day in DayFormat.daysFromToday(7) {
            guard planEntry(day: day, slot: "晚") == nil else { continue }
            guard let pick = pool.randomElement() else { return }
            setPlan(day: day, slot: "晚", recipe: pick)
            pool.removeAll { $0.id == pick.id }
        }
    }

    // MARK: 导入导出

    func exportFile() -> URL? {
        let data = AppData(
            schemaVersion: 1,
            recipes: recipes,
            favorites: Array(favorites),
            records: records,
            shopping: shopping,
            plan: plan,
            settings: settings,
            inventory: inventory
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        guard let raw = try? encoder.encode(data) else { return nil }
        let name = "今晚吃什么-\(DayFormat.key.string(from: Date())).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try raw.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    func importFile(_ url: URL) -> Bool {
        let needsStop = url.startAccessingSecurityScopedResource()
        defer { if needsStop { url.stopAccessingSecurityScopedResource() } }
        do {
            let raw = try Data(contentsOf: url)
            let data = try JSONDecoder().decode(AppData.self, from: raw)
            apply(data)
            loadSucceeded = true
            persist()
            return true
        } catch {
            return false
        }
    }

    func isEmptyHistoryCleanup() {
        records.removeAll()
        persist()
    }
}

enum RecipeSort: String, CaseIterable, Identifiable {
    case `default` = "按分类"
    case quick = "最快能做"
    case newest = "最近修改"

    var id: String { rawValue }
}
