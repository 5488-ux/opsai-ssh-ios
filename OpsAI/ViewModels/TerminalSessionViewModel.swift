import Combine
import Foundation

@MainActor
final class TerminalSessionViewModel: ObservableObject {
    @Published var terminalOutput = "Ready."
    @Published var isConnected = false
    @Published var isBusy = false
    @Published var aiPrompt = ""
    @Published var aiPlan: AIPlan?
    @Published var draftingCommandIDs: Set<UUID> = []
    @Published var errorMessage: String?

    let server: SSHServer

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
            appendOutput("Connected to \(server.host):\(server.port) as \(server.username).")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func disconnect() async {
        await sshService.disconnect()
        isConnected = false
        appendOutput("Disconnected.")
    }

    func generatePlan() async {
        let trimmedGoal = aiPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedGoal.isEmpty else { return }

        isBusy = true
        errorMessage = nil
        aiPlan = nil
        defer { isBusy = false }

        do {
            let plan = try await aiService.buildPlan(
                goal: trimmedGoal,
                server: server,
                config: appStore.providerConfig,
                apiKey: appStore.providerAPIKey()
            )
            aiPlan = plan
            await animateDrafting(for: plan.commands)
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
            errorMessage = "Connect to the server first."
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
