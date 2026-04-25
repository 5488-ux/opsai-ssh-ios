import Combine
import Foundation

@MainActor
final class TerminalSessionViewModel: ObservableObject {
    @Published var terminalOutput = "终端已就绪。"
    @Published var isConnected = false
    @Published var isBusy = false
    @Published var aiPrompt = ""
    @Published var manualCommand = ""
    @Published var selectedAssistant = AIAssistantProfile.operations
    @Published var aiPlan: AIPlan?
    @Published var draftingCommandIDs: Set<UUID> = []
    @Published var errorMessage: String?
    @Published var conversation: [AIOpsChatMessage]

    let server: SSHServer

    var quickPrompts: [String] {
        selectedAssistant.quickPrompts
    }

    var diagnosticTools: [AIDiagnosticTool] {
        AIDiagnosticTool.presets(for: selectedAssistant)
    }

    private let sshService: SSHServiceProtocol
    private let aiService: AIServiceProtocol
    private let appStore: AppStore
    private var conversationsByAssistant: [AIAssistantProfile: [AIOpsChatMessage]]
    private var plansByAssistant: [AIAssistantProfile: AIPlan]

    init(
        server: SSHServer,
        appStore: AppStore,
        sshService: SSHServiceProtocol = RealSSHService(),
        aiService: AIServiceProtocol = AIService()
    ) {
        self.server = server
        self.appStore = appStore
        self.sshService = sshService
        self.aiService = aiService
        let defaultConversation = Self.makeDefaultConversation(for: .operations)
        self.conversation = defaultConversation
        self.conversationsByAssistant = [.operations: defaultConversation]
        self.plansByAssistant = [:]
    }

    func connect() async {
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }

        do {
            let password = appStore.secret(for: server.passwordReference)
            let privateKey = appStore.secret(for: server.privateKeyReference)
            try await sshService.connect(
                using: SSHConnectionRequest(
                    server: server,
                    password: password,
                    privateKey: privateKey
                )
            )
            isConnected = true
            appendOutput("已连接到 \(server.host):\(server.port)，登录用户：\(server.username)。")
        } catch {
            isConnected = false
            errorMessage = error.localizedDescription
        }
    }

    func disconnect() async {
        await sshService.disconnect()
        isConnected = false
        appendOutput("连接已断开。")
    }

    func useQuickPrompt(_ prompt: String) async {
        if prompt == "分析最近的终端输出" {
            await analyzeTerminalOutput()
            return
        }
        aiPrompt = prompt
        await sendAIOpsMessage()
    }

    func selectAssistant(_ assistant: AIAssistantProfile) {
        guard assistant != selectedAssistant else { return }
        selectedAssistant = assistant
        conversation = conversationsByAssistant[assistant] ?? Self.makeDefaultConversation(for: assistant)
        aiPlan = plansByAssistant[assistant]
        errorMessage = nil
        draftingCommandIDs.removeAll()
    }

    func analyzeTerminalOutput() async {
        let excerpt = recentTerminalExcerpt()
        guard !excerpt.isEmpty else {
            errorMessage = "当前还没有可供分析的终端输出。"
            return
        }

        await submitAIOpsPrompt(
            selectedAssistant.makeTerminalAnalysisPrompt(using: excerpt),
            visibleUserText: "请根据最近终端输出继续分析。"
        )
    }

    func runDiagnosticTool(_ tool: AIDiagnosticTool, analyzeAfterRun: Bool) async {
        guard isConnected else {
            errorMessage = "请先连接服务器。"
            return
        }

        isBusy = true
        errorMessage = nil
        defer { isBusy = false }

        var outputs: [String] = []
        var failures: [String] = []

        for command in tool.commands {
            do {
                let output = try await sshService.execute(command)
                outputs.append(output)
            } catch {
                outputs.append("$ \(command)\n\(error.localizedDescription)")
                failures.append("\(command)：\(error.localizedDescription)")
            }
        }

        let combinedOutput = outputs.joined(separator: "\n\n")
        guard !combinedOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "工具没有返回任何结果。"
            return
        }

        appendOutput("## 工具：\(tool.displayName)\n\(combinedOutput)")

        if !failures.isEmpty {
            errorMessage = "工具已运行，但有部分命令失败。"
        }

        guard analyzeAfterRun else { return }

        let prompt = tool.makeAnalysisPrompt(using: combinedOutput)
        await submitAIOpsPrompt(
            prompt,
            visibleUserText: "我刚运行了工具“\(tool.displayName)”，请结合结果继续分析。"
        )
    }

    func sendAIOpsMessage() async {
        await submitAIOpsPrompt(aiPrompt)
        aiPrompt = ""
    }

    func runManualCommand() async {
        let command = manualCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !command.isEmpty else {
            errorMessage = "请输入要执行的命令。"
            return
        }

        guard isConnected else {
            errorMessage = "请先连接服务器。"
            return
        }

        isBusy = true
        errorMessage = nil
        defer { isBusy = false }

        do {
            let output = try await sshService.execute(command)
            appendOutput(output)
            manualCommand = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func approveAndRun(_ commandID: UUID) async {
        guard let plan = aiPlan,
              let index = plan.commands.firstIndex(where: { $0.id == commandID }) else {
            return
        }

        guard isConnected else {
            errorMessage = "请先连接服务器。"
            return
        }

        isBusy = true
        errorMessage = nil
        defer { isBusy = false }

        do {
            var mutablePlan = plan
            mutablePlan.commands[index].approvedAt = .now
            let output = try await sshService.execute(mutablePlan.commands[index].command)
            mutablePlan.commands[index].output = output
            aiPlan = mutablePlan
            plansByAssistant[selectedAssistant] = mutablePlan
            appendOutput(output)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateCommand(_ commandID: UUID, with text: String) {
        guard var plan = aiPlan,
              let index = plan.commands.firstIndex(where: { $0.id == commandID }) else {
            return
        }
        plan.commands[index].command = text
        aiPlan = plan
        plansByAssistant[selectedAssistant] = plan
    }

    private func animateDrafting(for commands: [AIPlan.CommandDraft]) async {
        for command in commands {
            draftingCommandIDs.insert(command.id)
            try? await Task.sleep(for: .milliseconds(220))
            draftingCommandIDs.remove(command.id)
        }
    }

    private func appendConversation(_ message: AIOpsChatMessage, to assistant: AIAssistantProfile) {
        var messages = conversationsByAssistant[assistant] ?? Self.makeDefaultConversation(for: assistant)
        messages.append(message)
        conversationsByAssistant[assistant] = messages

        if assistant == selectedAssistant {
            conversation = messages
        }
    }

    private func appendOutput(_ chunk: String) {
        terminalOutput += terminalOutput.isEmpty ? chunk : "\n\n\(chunk)"
    }

    private func submitAIOpsPrompt(_ prompt: String, visibleUserText: String? = nil) async {
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else {
            errorMessage = "请先输入你要排查的问题。"
            return
        }

        isBusy = true
        errorMessage = nil
        aiPlan = nil
        draftingCommandIDs.removeAll()

        let assistant = selectedAssistant
        let userText = visibleUserText ?? trimmedPrompt

        appendConversation(.init(role: .user, text: userText), to: assistant)

        defer { isBusy = false }

        do {
            let response = try await aiService.askAssistant(
                prompt: trimmedPrompt,
                history: conversationsByAssistant[assistant] ?? Self.makeDefaultConversation(for: assistant),
                server: server,
                assistantProfile: assistant,
                config: appStore.providerConfig,
                apiKey: appStore.providerAPIKey()
            )
            appendConversation(.init(role: .assistant, text: response.reply), to: assistant)

            if let plan = response.plan {
                plansByAssistant[assistant] = plan
            } else {
                plansByAssistant.removeValue(forKey: assistant)
            }

            if assistant == selectedAssistant {
                aiPlan = response.plan
            }

            if let commands = response.plan?.commands {
                await animateDrafting(for: commands)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func recentTerminalExcerpt(limit: Int = 2200) -> String {
        let trimmed = terminalOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "终端已就绪。" else {
            return ""
        }

        if trimmed.count <= limit {
            return trimmed
        }

        let startIndex = trimmed.index(trimmed.endIndex, offsetBy: -limit)
        return "以下是最近终端输出的末尾片段：\n" + String(trimmed[startIndex...])
    }

    private static func makeDefaultConversation(for assistant: AIAssistantProfile) -> [AIOpsChatMessage] {
        [.init(role: .assistant, text: assistant.introMessage)]
    }
}
