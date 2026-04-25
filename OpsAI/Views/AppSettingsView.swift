import SwiftUI

struct AppSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.4"
    }

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "4"
    }

    var body: some View {
        NavigationStack {
            List {
                Section("公告") {
                    Label("OpsAI v1.4 新增设置中心，可查看公告、更新日志、版本和 GitHub 链接。", systemImage: "megaphone")
                    Text("当前版本仍以本机直连 SSH 为核心，AI 只生成建议和命令草稿，不会自动执行命令。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("更新日志") {
                    updateRow(version: "v1.4", items: [
                        "新增右上角设置入口",
                        "新增公告、更新日志和版本信息",
                        "新增 GitHub 仓库链接和应用介绍"
                    ])

                    updateRow(version: "v1.3", items: [
                        "新增 App 图标",
                        "恢复浅色系统界面",
                        "简化工作台信息层级"
                    ])

                    updateRow(version: "v1.2", items: [
                        "新增服务器配置扫描",
                        "新增绑定域名扫描",
                        "改进命令执行结果分析"
                    ])
                }

                Section("版本") {
                    LabeledContent("当前版本", value: appVersion)
                    LabeledContent("Build", value: buildNumber)
                }

                Section("链接") {
                    Link(destination: URL(string: "https://github.com/5488-ux/opsai-ssh-ios")!) {
                        Label("GitHub 仓库", systemImage: "link")
                    }
                }

                Section("介绍") {
                    Text("OpsAI 是一个 iPhone SSH 运维工具。你可以保存服务器、直接连接终端、让 AI 生成排查计划，并在人工批准后逐条执行命令。")
                        .font(.body)

                    Label("无后端，服务器凭证只保存在本机钥匙串。", systemImage: "lock.shield")
                    Label("AI Provider 可配置，兼容 OpenAI 风格接口。", systemImage: "sparkles")
                    Label("所有 AI 命令草稿都需要人工确认。", systemImage: "checkmark.shield")
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func updateRow(version: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(version)
                .font(.headline)

            ForEach(items, id: \.self) { item in
                Label(item, systemImage: "checkmark.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
