import SwiftUI

extension View {
    /// 全项目唯一允许的按钮样式：iOS 26 走官方 Liquid Glass，低版本用系统 bordered，绝不自绘胶囊。
    @ViewBuilder
    func liquidGlassButton() -> some View {
        if #available(iOS 26.0, *) {
            buttonStyle(.glass)
        } else {
            buttonStyle(.bordered)
        }
    }
}

/// 一行小字元信息：时间 · 难度 · 辣度。
struct RecipeMetaLine: View {
    let recipe: Recipe
    var showCategory: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            if showCategory {
                Text(recipe.categoryName)
                Text("·")
            }
            Text("\(recipe.minutes) 分钟")
            Text("·")
            Text(recipe.difficultyLabel)
            Text("·")
            Text(recipe.spicyLabel)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

/// 列表里的一道菜。
struct RecipeRow: View {
    let recipe: Recipe
    let isFavorite: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(recipe.emoji)
                .font(.title2)
                .frame(width: 34, height: 34)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(recipe.name)
                        .font(.body)
                        .lineLimit(1)
                    if isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                            .accessibilityLabel("已收藏")
                    }
                }
                RecipeMetaLine(recipe: recipe)
            }
        }
        .padding(.vertical, 2)
    }
}

/// 空状态统一用系统组件，别自己画插画。
struct EmptyHint: View {
    let title: String
    let message: String
    var systemImage: String = "fork.knife"

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(message)
        }
    }
}

/// 辣度用小图标 + 文字双通道，不靠颜色单独传达信息。
struct SpicyBadge: View {
    let level: Int

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "flame.fill")
                .foregroundStyle(level == 0 ? Color.secondary : Color.orange)
            Text(label)
        }
        .font(.caption)
        .accessibilityLabel(label)
    }

    private var label: String {
        switch level {
        case 0: return "不辣"
        case 1: return "微辣"
        case 2: return "中辣"
        default: return "很辣"
        }
    }
}
