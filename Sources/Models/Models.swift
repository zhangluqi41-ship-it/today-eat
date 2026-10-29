import Foundation
import Observation

// MARK: - 分类

struct DishCategory: Identifiable, Hashable {
    let key: String
    let name: String
    let emoji: String

    var id: String { key }

    static let all: [DishCategory] = [
        DishCategory(key: "pork", name: "猪肉", emoji: "🍖"),
        DishCategory(key: "poultry", name: "禽类", emoji: "🍗"),
        DishCategory(key: "beef", name: "牛肉", emoji: "🥩"),
        DishCategory(key: "veggie", name: "蔬菜", emoji: "🥬"),
        DishCategory(key: "tofu", name: "豆制品", emoji: "🫘"),
        DishCategory(key: "egg", name: "蛋类", emoji: "🥚")
    ]

    static func name(for key: String) -> String {
        all.first { $0.key == key }?.name ?? "其他"
    }

    static func emoji(for key: String) -> String {
        all.first { $0.key == key }?.emoji ?? "🍽️"
    }
}

// MARK: - 菜谱

struct Ingredient: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var amount: String
    var group: String = "主料"

    private enum CodingKeys: String, CodingKey {
        case id, name, amount, group
    }

    init(id: UUID = UUID(), name: String, amount: String, group: String = "主料") {
        self.id = id
        self.name = name
        self.amount = amount
        self.group = group
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        amount = try container.decode(String.self, forKey: .amount)
        group = try container.decodeIfPresent(String.self, forKey: .group) ?? "主料"
    }
}

struct Recipe: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var category: String
    var kind: String
    var minutes: Int
    var difficulty: Int
    var spicy: Int
    var tags: [String]
    var ingredients: [Ingredient]
    var steps: [String]
    var tips: String
    var source: String
    var baseServings: Int
    var updatedAt: Date

    private enum CodingKeys: String, CodingKey {
        case id, name, category, kind, minutes, difficulty, spicy
        case tags, ingredients, steps, tips, source, baseServings, updatedAt
    }

    init(
        id: String = UUID().uuidString,
        name: String,
        category: String,
        kind: String,
        minutes: Int,
        difficulty: Int,
        spicy: Int,
        tags: [String] = [],
        ingredients: [Ingredient] = [],
        steps: [String] = [],
        tips: String = "",
        source: String = "手写",
        baseServings: Int = 2,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.kind = kind
        self.minutes = minutes
        self.difficulty = difficulty
        self.spicy = spicy
        self.tags = tags
        self.ingredients = ingredients
        self.steps = steps
        self.tips = tips
        self.source = source
        self.baseServings = baseServings
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        category = try container.decode(String.self, forKey: .category)
        kind = try container.decode(String.self, forKey: .kind)
        minutes = try container.decode(Int.self, forKey: .minutes)
        difficulty = try container.decode(Int.self, forKey: .difficulty)
        spicy = try container.decode(Int.self, forKey: .spicy)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        ingredients = try container.decodeIfPresent([Ingredient].self, forKey: .ingredients) ?? []
        steps = try container.decodeIfPresent([String].self, forKey: .steps) ?? []
        tips = try container.decodeIfPresent(String.self, forKey: .tips) ?? ""
        source = try container.decodeIfPresent(String.self, forKey: .source) ?? "内置菜谱"
        baseServings = try container.decodeIfPresent(Int.self, forKey: .baseServings) ?? 2
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }

    var categoryName: String { DishCategory.name(for: category) }
    var emoji: String { DishCategory.emoji(for: category) }

    var kindLabel: String { kind }

    var difficultyLabel: String {
        switch difficulty {
        case 1: return "简单"
        case 2: return "中等"
        default: return "有点讲究"
        }
    }

    var spicyLabel: String {
        switch spicy {
        case 0: return "不辣"
        case 1: return "微辣"
        case 2: return "中辣"
        default: return "很辣"
        }
    }

    var mainIngredients: [Ingredient] { ingredients.filter { $0.group == "主料" } }
    var seasonings: [Ingredient] { ingredients.filter { $0.group != "主料" } }

    /// 按人数换算用量：只换算以数字开头的用量，其余原样返回。
    func scaledAmount(_ amount: String, servings: Int) -> String {
        guard baseServings > 0, servings != baseServings else { return amount }
        guard let range = amount.range(of: #"^\d+(\.\d+)?"#, options: .regularExpression),
              let value = Double(amount[range]) else { return amount }
        let scaled = value * Double(servings) / Double(baseServings)
        let text: String
        if abs(scaled - scaled.rounded()) < 0.05 {
            text = String(Int(scaled.rounded()))
        } else {
            text = String(format: "%.1f", scaled)
        }
        return text + amount[range.upperBound...]
    }

    func matches(keyword: String) -> Bool {
        let text = keyword.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return true }
        if name.localizedStandardContains(text) { return true }
        if tags.contains(where: { $0.localizedStandardContains(text) }) { return true }
        if ingredients.contains(where: { $0.name.localizedStandardContains(text) }) { return true }
        return false
    }
}

// MARK: - 用户数据

struct AppSettings: Codable, Equatable {
    var servings: Int = 2
    var maxMinutes: Int = 90
    var maxSpicy: Int = 3
    var avoidDays: Int = 3
    var avoidRecent: Bool = true
    var onlyFavorites: Bool = false
    var categoryFilter: String = ""      // 分类 key，空字符串表示全部分类
    var dislikes: [String] = []
    var hapticsEnabled: Bool = true
    var quickIngredients: [String] = AppSettings.defaultQuickIngredients

    static let defaultQuickIngredients = [
        "鸡蛋", "番茄", "土豆", "豆腐", "五花肉", "鸡腿",
        "牛腩", "青椒", "洋葱", "香菇", "白菜", "粉丝"
    ]

    private enum CodingKeys: String, CodingKey {
        case servings, maxMinutes, maxSpicy, avoidDays, avoidRecent, onlyFavorites
        case categoryFilter, kindFilter, dislikes, hapticsEnabled, quickIngredients
    }

    init() {}

    /// 手写解码：老版本存下的数据没有新字段，缺一个就必须回落默认值，
    /// 否则整个 data.json 会被判成损坏（用户会以为数据丢了）。
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        servings = try container.decodeIfPresent(Int.self, forKey: .servings) ?? 2
        maxMinutes = try container.decodeIfPresent(Int.self, forKey: .maxMinutes) ?? 90
        maxSpicy = try container.decodeIfPresent(Int.self, forKey: .maxSpicy) ?? 3
        avoidDays = try container.decodeIfPresent(Int.self, forKey: .avoidDays) ?? 3
        avoidRecent = try container.decodeIfPresent(Bool.self, forKey: .avoidRecent) ?? true
        onlyFavorites = try container.decodeIfPresent(Bool.self, forKey: .onlyFavorites) ?? false
        categoryFilter = try container.decodeIfPresent(String.self, forKey: .categoryFilter)
            ?? container.decodeIfPresent(String.self, forKey: .kindFilter)
            ?? ""
        dislikes = try container.decodeIfPresent([String].self, forKey: .dislikes) ?? []
        hapticsEnabled = try container.decodeIfPresent(Bool.self, forKey: .hapticsEnabled) ?? true
        let quick = try container.decodeIfPresent([String].self, forKey: .quickIngredients)
        if let quick, !quick.isEmpty {
            quickIngredients = quick
        } else {
            quickIngredients = AppSettings.defaultQuickIngredients
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(servings, forKey: .servings)
        try container.encode(maxMinutes, forKey: .maxMinutes)
        try container.encode(maxSpicy, forKey: .maxSpicy)
        try container.encode(avoidDays, forKey: .avoidDays)
        try container.encode(avoidRecent, forKey: .avoidRecent)
        try container.encode(onlyFavorites, forKey: .onlyFavorites)
        try container.encode(categoryFilter, forKey: .categoryFilter)
        try container.encode(dislikes, forKey: .dislikes)
        try container.encode(hapticsEnabled, forKey: .hapticsEnabled)
        try container.encode(quickIngredients, forKey: .quickIngredients)
    }
}

struct CookRecord: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var recipeID: String
    var recipeName: String
    var date: Date = Date()
    var rating: Int = 0                  // 0 表示还没评
    var note: String = ""
}

struct ShoppingItem: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var amount: String
    var done: Bool = false
    var fromRecipe: String = ""
    var createdAt: Date = Date()
}

struct PlanEntry: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var dayKey: String                   // yyyy-MM-dd
    var slot: String                     // 午 / 晚
    var recipeID: String
    var recipeName: String
}

struct AppData: Codable {
    var schemaVersion: Int = 1
    var recipes: [Recipe] = []
    var favorites: [String] = []
    var records: [CookRecord] = []
    var shopping: [ShoppingItem] = []
    var plan: [PlanEntry] = []
    var settings: AppSettings = AppSettings()
    var inventory: [String] = []
}

// MARK: - 内置数据文件结构

struct SeedPayload: Codable {
    var version: Int
    var generatedAt: String?
    var categories: [SeedCategory]
    var dishes: [Recipe]
}

struct SeedCategory: Codable {
    var key: String
    var name: String
    var emoji: String
    var order: Int
}

// MARK: - 小工具

enum DayFormat {
    /// data.json 里的日期是 ISO8601 字符串（写入时用的就是它），解码必须对得上。
    static let iso: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static let isoFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let key: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static let weekday: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "EEE"
        return formatter
    }()

    static let monthDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日"
        return formatter
    }()

    static let time: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    static func daysFromToday(_ count: Int) -> [Date] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        return (0..<count).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }
}
