import SwiftUI

/// 做饭模式：一步一屏，大字，能直接计时。
struct CookingModeView: View {
    @Environment(\.dismiss) private var dismiss

    let recipe: Recipe
    let servings: Int

    @State private var index = 0
    @State private var remaining: Int = 0
    @State private var totalSeconds: Int = 0
    @State private var timerTask: Task<Void, Never>?
    @State private var finishedAlert = false
    @State private var tick = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                if !recipe.tags.isEmpty {
                    Text(recipe.name)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }

                ScrollView {
                    VStack(spacing: 16) {
                        Text(recipe.steps[safe: index] ?? "")
                            .font(.title2)
                            .lineSpacing(6)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)

                        if let minutes = detectedMinutes, index < recipe.steps.count {
                            timerBlock(minutes: minutes)
                        }
                    }
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity, minHeight: 220)
                }

                HStack(spacing: 10) {
                    Button {
                        if index > 0 {
                            index -= 1
                            stopTimer()
                        }
                    } label: {
                        Label("上一步", systemImage: "chevron.left")
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 44)
                    }
                    .liquidGlassButton()
                    .disabled(index == 0)

                    Button {
                        if index < recipe.steps.count - 1 {
                            index += 1
                            stopTimer()
                        } else {
                            dismiss()
                        }
                    } label: {
                        Label(index == recipe.steps.count - 1 ? "做完了" : "下一步",
                              systemImage: index == recipe.steps.count - 1 ? "checkmark" : "chevron.right")
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 44)
                    }
                    .liquidGlassButton()
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .navigationTitle("第 \(index + 1) 步 / 共 \(recipe.steps.count) 步")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("退出") { dismiss() }
                }
            }
            .onDisappear { stopTimer() }
            .alert("时间到", isPresented: $finishedAlert) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text("这一步计时的 \(totalSeconds / 60) 分钟到了。")
            }
            .sensoryFeedback(.success, trigger: tick)
        }
    }

    private func timerBlock(minutes: Int) -> some View {
        VStack(spacing: 8) {
            if remaining > 0 {
                Gauge(value: Double(remaining), in: 0...Double(max(totalSeconds, 1))) {
                    Text("倒计时")
                } currentValueLabel: {
                    Text(clockText)
                        .monospacedDigit()
                }
                .gaugeStyle(.accessoryLinearCapacity)
                .tint(Color.accentColor)

                Button("取消计时") {
                    stopTimer()
                }
                .font(.footnote)
                .liquidGlassButton()
            } else {
                Button {
                    startTimer(minutes: minutes)
                } label: {
                    Label("计时 \(minutes) 分钟", systemImage: "timer")
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                }
                .liquidGlassButton()
            }
        }
        .padding(.top, 4)
    }

    private var clockText: String {
        String(format: "%02d:%02d", remaining / 60, remaining % 60)
    }

    /// 从步骤文字里认出“5 分钟”，让计时一键可用。
    private var detectedMinutes: Int? {
        guard let step = recipe.steps[safe: index] else { return nil }
        guard let range = step.range(of: #"(\d+)\s*分钟"#, options: .regularExpression) else { return nil }
        let digits = step[range].prefix { $0.isNumber }
        guard let value = Int(digits), value > 0, value <= 180 else { return nil }
        return value
    }

    private func startTimer(minutes: Int) {
        stopTimer()
        totalSeconds = minutes * 60
        remaining = totalSeconds
        timerTask = Task { @MainActor in
            while remaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                remaining -= 1
            }
            tick += 1
            finishedAlert = true
        }
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
        remaining = 0
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
