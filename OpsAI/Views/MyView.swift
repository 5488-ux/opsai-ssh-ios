import SwiftUI
import UIKit

struct MyView: View {
    @EnvironmentObject private var appStore: AppStore
    @State private var copiedEntryID: UUID?
    @State private var copiedAll = false

    var body: some View {
        NavigationStack {
            List {
                Section("概览") {
                    LabeledContent("已保存服务器", value: "\(appStore.servers.count)")
                    LabeledContent("最近报错", value: "\(appStore.issueEntries.count)")
                }

                Section("报错提示") {
                    if appStore.issueEntries.isEmpty {
                        ContentUnavailableView(
                            "还没有报错记录",
                            systemImage: "checkmark.seal",
                            description: Text("终端、AI 设置和服务器编辑里的错误会显示在这里。")
                        )
                    } else {
                        Button(copiedAll ? "已复制全部" : "复制全部") {
                            UIPasteboard.general.string = appStore.issueEntries
                                .map(\.copyText)
                                .joined(separator: "\n\n")
                            copiedAll = true
                        }
                        .disabled(appStore.issueEntries.isEmpty)

                        ForEach(appStore.issueEntries) { entry in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(entry.source)
                                            .font(.subheadline.weight(.semibold))
                                        Text(entry.createdAt, style: .time)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Button(copiedEntryID == entry.id ? "已复制" : "复制") {
                                        UIPasteboard.general.string = entry.copyText
                                        copiedEntryID = entry.id
                                    }
                                    .buttonStyle(.bordered)
                                    .font(.footnote)
                                }

                                Text(entry.message)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("我的")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !appStore.issueEntries.isEmpty {
                        Button("清空") {
                            appStore.clearIssueEntries()
                            copiedEntryID = nil
                            copiedAll = false
                        }
                    }
                }
            }
            .onChange(of: appStore.issueEntries) { _, _ in
                copiedAll = false
            }
        }
    }
}
