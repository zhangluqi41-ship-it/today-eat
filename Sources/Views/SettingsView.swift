import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(RecipeStore.self) private var store

    @State private var newDislike = ""
    @State private var exportURL: URL?
    @State private var showImporter = false
    @State private var showRestoreConfirm = false
    @State private var showClearHistoryConfirm = false
    @State private var showImportResult = false
    @State private var importSucceeded = false

    var body: some View {
        @Bindable var store = store

        Form {
            Section {
                Stepper(value: $store.settings.servings, in: 1...8) {
                    HStack {
                        Text("默认份量")
                        Spacer()
                        Text("\(store.settings.servings) 人")
                            .foregroundStyle(.secondary)
                    }
                }

                Picker("辣度上限", selection: $store.settings.maxSpicy) {
                    Text("不辣").tag(0)
                    Text("微辣").tag(1)
                    Text("中辣").tag(2)
                    Text("都可以").tag(3)
                }
            } header: {
                Text("份量与口味")
            } footer: {
                Text("份量决定菜谱里配料的换算基准，辣度上限会过滤掉太辣的菜。")
            }

            Section {
                Stepper(value: $store.settings.maxMinutes, in: 15...180, step: 15) {
                    HStack {
                        Text("时间上限")
                        Spacer()
                        Text(store.settings.maxMinutes >= 180 ? "不限" : "\(store.settings.maxMinutes) 分钟")
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle("跳过最近吃过的", isOn: $store.settings.avoidRecent)

                if store.settings.avoidRecent {
                    Stepper(value: $store.settings.avoidDays, in: 1...30) {
                        HStack {
                            Text("回看")
                            Spacer()
                            Text("\(store.settings.avoidDays) 天")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Toggle("只从收藏里抽", isOn: $store.settings.onlyFavorites)

                HStack {
                    Text("符合条件")
                    Spacer()
                    Text("\(store.pickPool().count) 道")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("抽签规则")
            }

            Section {
                HStack {
                    TextField("不吃的食材，比如香菜", text: $newDislike)
                        .submitLabel(.done)
                        .onSubmit(addDislike)
                    Button("加入", action: addDislike)
                        .disabled(newDislike.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                ForEach(store.settings.dislikes, id: \.self) { word in
                    Label(word, systemImage: "nosign")
                }
                .onDelete { offsets in
                    store.settings.dislikes.remove(atOffsets: offsets)
                }
            } header: {
                Text("忌口")
            } footer: {
                Text("配料里出现这些词，这道菜就不会被抽到。左滑可以删掉。")
            }

            Section {
                if let exportURL {
                    ShareLink(item: exportURL) {
                        Label("导出备份", systemImage: "square.and.arrow.up")
                    }
                }

                Button {
                    showImporter = true
                } label: {
                    Label("从备份恢复", systemImage: "square.and.arrow.down")
                }

                Button {
                    showRestoreConfirm = true
                } label: {
                    Label("恢复内置菜谱", systemImage: "arrow.counterclockwise")
                }

                Button(role: .destructive) {
                    showClearHistoryConfirm = true
                } label: {
                    Label("清空做饭记录", systemImage: "trash")
                }
                .disabled(store.records.isEmpty)
            } header: {
                Text("数据")
            } footer: {
                Text("导出文件包含全部菜谱、收藏、记录、清单和设置。恢复内置菜谱只重置内置的菜，自己写的会保留。")
            }

            Section {
                HStack {
                    Text("菜谱总数")
                    Spacer()
                    Text("\(store.recipes.count) 道")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("数据文件")
                    Spacer()
                    Text("Application Support/data.json")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("关于")
            } footer: {
                Text("所有数据只存在这台手机上。卸载 App 会一起删掉，重要内容记得导出。")
            }
        }
        .navigationTitle("设置")
        .onAppear {
            exportURL = store.exportFile()
        }
        .onChange(of: store.settings) { _, _ in
            store.scheduleSave()
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    importSucceeded = store.importFile(url)
                    showImportResult = true
                }
            case .failure:
                importSucceeded = false
                showImportResult = true
            }
        }
        .alert(importSucceeded ? "导入成功" : "导入失败", isPresented: $showImportResult) {
            Button("好", role: .cancel) {}
        } message: {
            Text(importSucceeded ? "菜谱和记录已经替换成本地备份里的内容。" : "这个文件读不出来，确认是「今晚吃什么」导出的备份再试。")
        }
        .confirmationDialog("恢复内置菜谱？", isPresented: $showRestoreConfirm, titleVisibility: .visible) {
            Button("恢复", role: .destructive) {
                store.restoreBuiltInRecipes()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("内置菜会回到最初的内容，你对它们的修改会被覆盖；自己新增的菜保留。")
        }
        .confirmationDialog("清空所有做饭记录？", isPresented: $showClearHistoryConfirm, titleVisibility: .visible) {
            Button("清空", role: .destructive) {
                store.isEmptyHistoryCleanup()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("「跳过最近吃过的」会因此失去依据。")
        }
    }

    private func addDislike() {
        let word = newDislike.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !word.isEmpty else { return }
        if !store.settings.dislikes.contains(word) {
            store.settings.dislikes.append(word)
            store.persist()
        }
        newDislike = ""
    }
}
