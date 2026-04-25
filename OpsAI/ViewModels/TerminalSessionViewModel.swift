import Combine
import Foundation

@MainActor
final class TerminalSessionViewModel: ObservableObject {
    @Published var terminalOutput = "终端已就绪。"
    @Published var isConnected = false
    @Published var isBusy = false
    @Published var aiPrompt = ""
    @Published var manualCommand = ""
    @Published var aiPlan: AIPlan?
    @Published var draftingCommandIDs: Set<UUID> = []
    @Published var errorMessage: String?
    @Published var conversation: [AIOpsChatMessage] = [
        .init(role: .assistant, text: "我是你的运维助手。你可以直接描述问题，我会先给出判断，再生成可批准执行的命令计划。")
    ]

    let server: SSHServer
    let quickPrompts = [
        "检查服务器负载为什么变高",
        "看看磁盘空间是否快满了",
        "排查 nginx 返回 502 的原因",
        "检查 Docker 容器状态"
    ]

    private let sshService: SSHServiceProtocol
    private let aiService: AIServiceProtocol
    private let appStore: AppStore

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
            errorMessage = error.localizedDescription
        }
    }

    func disconnect() async {
        await sshService.disconnect()
        isConnected = false
        appendOutput("连接已断开。")
    }

    func useQuickPrompt(_ prompt: String) async {
        aiPrompt = prompt
        await sendAIOpsMessage()
    }

    func sendAIOpsMessage() async {
        let trimmedPrompt = aiPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else {
            errorMessage = "请先输入你要排查的问题。"
            return
        }

        isBusy = true
        errorMessage = nil
        aiPlan = nil

        let userMessage = AIOpsChatMessage(role: .user, text: trimmedPrompt)
        conversation.append(userMessage)
        aiPrompt = ""

        defer { isBusy = false }

        do {
            let response = try await aiService.askAssistant(
                prompt: trimmedPrompt,
                history: conversation,
                server: server,
                config: appStore.providerConfig,
                apiKey: appStore.providerAPIKey()
            )
            conversation.append(.init(role: .assistant, text: response.reply))
            aiPlan = response.plan
            await animateDrafting(for: response.plan.commands)
        } catch {
            errorMessage = error.localizedDescription
        }
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
    }

    private func animateDrafting(for commands: [AIPlan.CommandDraft]) async {
        for command in commands {
            draftingCommandIDs.insert(command.id)
            try? await Task.sleep(for: .milliseconds(220))
            draftingCommandIDs.remove(command.id)
        }
    }

    private func appendOutput(_ chunk: String) {
        terminalOutput += terminalOutput.isEmpty ? chunk : "\n\n\(chunk)"
    }
}
