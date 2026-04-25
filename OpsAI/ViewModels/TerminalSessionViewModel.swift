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
    @Published var boundDomains: [String]
    @Published var serverConfigSnapshot: ServerConfigSnapshot?
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
        self.boundDomains = server.boundDomainList
        self.serverConfigSnapshot = nil
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
            setError(error.localizedDescription)
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
            setError("当前还没有可供分析的终端输出。")
            return
        }

        await submitAIOpsPrompt(
            selectedAssistant.makeTerminalAnalysisPrompt(using: excerpt),
            visibleUserText: "请根据最近终端输出继续分析。"
        )
    }

    func analyzeExecutionOutput(_ output: String, sourceLabel: String) async {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            setError("当前还没有可供分析的执行结果。")
            return
        }

        await submitAIOpsPrompt(
            """
            请根据下面这段命令执行结果继续分析，先解释结果，再给出下一步值得人工批准的排查命令。

            来源：\(sourceLabel)

            \(trimmed)
            """,
            visibleUserText: "请分析 \(sourceLabel) 的执行结果。"
        )
    }

    func scanBoundDomains() async {
        guard isConnected else {
            setError("请先连接服务器。")
            return
        }

        isBusy = true
        errorMessage = nil
        defer { isBusy = false }

        do {
            let output = try await sshService.execute(domainScanCommand)
            appendOutput("## 域名扫描\n\(output)")

            let domains = parseBoundDomains(from: output)
            guard !domains.isEmpty else {
                setError("未在常见站点配置里扫描到绑定域名。")
                return
            }

            boundDomains = domains
            appStore.updateBoundDomains(for: server.id, domains: domains)
        } catch {
            setError(error.localizedDescription)
        }
    }

    func scanServerConfiguration() async {
        guard isConnected else {
            setError("请先连接服务器。")
            return
        }

        isBusy = true
        errorMessage = nil
        defer { isBusy = false }

        do {
            let output = try await sshService.execute(serverConfigScanCommand)
            appendOutput("## 配置扫描\n\(output)")

            let sections = parseMarkedSections(from: output)
            let snapshot = ServerConfigSnapshot(
                hostName: value(for: "HOST", in: sections, fallback: server.host),
                operatingSystem: value(for: "OS", in: sections, fallback: "未知系统"),
                uptimeSummary: value(for: "UPTIME", in: sections, fallback: "未知"),
                memorySummary: value(for: "MEMORY", in: sections, fallback: "未知"),
                rootDiskSummary: value(for: "DISK", in: sections, fallback: "未知"),
                listeningPorts: parseListeningPorts(from: sections["PORTS"]),
                services: [
                    makeServiceStatus(name: "Nginx", key: "NGINX", sections: sections),
                    makeServiceStatus(name: "MySQL", key: "MYSQL", sections: sections),
                    makeServiceStatus(name: "Redis", key: "REDIS", sections: sections),
                    makeServiceStatus(name: "Docker", key: "DOCKER", sections: sections)
                ]
            )

            serverConfigSnapshot = snapshot
        } catch {
            setError(error.localizedDescription)
        }
    }

    func analyzeServerConfiguration() async {
        guard let snapshot = serverConfigSnapshot else {
            setError("请先扫描服务器配置。")
            return
        }

        await submitAIOpsPrompt(
            """
            请根据下面这份服务器配置概览做分析，先总结当前机器状态，再给出下一步值得人工批准的排查命令。

            \(snapshot.summaryText)
            """,
            visibleUserText: "请分析这台服务器的配置概览。"
        )
    }

    func runDiagnosticTool(_ tool: AIDiagnosticTool, analyzeAfterRun: Bool) async {
        guard isConnected else {
            setError("请先连接服务器。")
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
            setError("工具没有返回任何结果。")
            return
        }

        appendOutput("## 工具：\(tool.displayName)\n\(combinedOutput)")

        if !failures.isEmpty {
            setError("工具已运行，但有部分命令失败。")
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
            setError("请输入要执行的命令。")
            return
        }

        guard isConnected else {
            setError("请先连接服务器。")
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
            setError(error.localizedDescription)
        }
    }

    func approveAndRun(_ commandID: UUID) async {
        guard let plan = aiPlan,
              let index = plan.commands.firstIndex(where: { $0.id == commandID }) else {
            return
        }

        guard isConnected else {
            setError("请先连接服务器。")
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
            setError(error.localizedDescription)
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
            setError("请先输入你要排查的问题。")
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
            setError(error.localizedDescription)
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

    private var serverConfigScanCommand: String {
        #"""
        sh -lc 'echo "__OPS_HOST__"; hostname 2>/dev/null;
        echo "__OPS_OS__"; uname -srmo 2>/dev/null;
        echo "__OPS_UPTIME__"; uptime 2>/dev/null;
        echo "__OPS_MEMORY__"; free -h 2>/dev/null | sed -n "2p";
        echo "__OPS_DISK__"; df -h / 2>/dev/null | tail -n 1;
        echo "__OPS_PORTS__"; ss -lnt 2>/dev/null | awk "NR>1 {print \$4}" | sed "s/.*://" | sort -u | tr "\n" " "; echo;
        echo "__OPS_NGINX__"; (systemctl is-active nginx 2>/dev/null || service nginx status 2>/dev/null | head -n 1 || ps aux | grep "[n]ginx" | head -n 1 || echo "unknown");
        echo "__OPS_MYSQL__"; (systemctl is-active mysqld 2>/dev/null || systemctl is-active mysql 2>/dev/null || service mysqld status 2>/dev/null | head -n 1 || service mysql status 2>/dev/null | head -n 1 || ps aux | grep "[m]ysql" | head -n 1 || echo "unknown");
        echo "__OPS_REDIS__"; (systemctl is-active redis 2>/dev/null || systemctl is-active redis-server 2>/dev/null || service redis status 2>/dev/null | head -n 1 || service redis-server status 2>/dev/null | head -n 1 || ps aux | grep "[r]edis" | head -n 1 || echo "unknown");
        echo "__OPS_DOCKER__"; (systemctl is-active docker 2>/dev/null || service docker status 2>/dev/null | head -n 1 || docker info --format "{{.ServerVersion}}" 2>/dev/null || echo "unknown")'
        """#
    }

    private var domainScanCommand: String {
        #"""
        sh -lc 'for dir in /www/server/panel/vhost/nginx /www/server/panel/vhost/apache /etc/nginx/sites-enabled /etc/nginx/conf.d /usr/local/nginx/conf/vhost /etc/httpd/conf.d /etc/apache2/sites-enabled; do
          if [ -d "$dir" ]; then
            grep -RhoE "server_name[[:space:]]+[^;]+" "$dir" 2>/dev/null | sed -E "s/.*server_name[[:space:]]+//" | tr " " "\n"
            grep -RhoE "ServerName[[:space:]]+[^[:space:]]+" "$dir" 2>/dev/null | awk "{print \$2}"
            grep -RhoE "ServerAlias[[:space:]]+[^[:space:]].*" "$dir" 2>/dev/null | cut -d" " -f2- | tr " " "\n"
          fi
        done | sed "s/[;[:space:]]*$//" | grep -vE "^(default_server|_|\\*|localhost)$" | grep -E "^[A-Za-z0-9.-]+$" | sort -u | head -n 50'
        """#
    }

    private func parseBoundDomains(from output: String) -> [String] {
        output
            .components(separatedBy: .newlines)
            .filter { !$0.hasPrefix("$ ") }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { line in
                !line.isEmpty &&
                line != "(退出码 0)" &&
                !line.contains("server_name[") &&
                !line.contains("ServerName[") &&
                !line.contains("ServerAlias[")
            }
            .filter { line in
                line.range(of: #"^[A-Za-z0-9.-]+$"#, options: .regularExpression) != nil
            }
    }

    private func parseMarkedSections(from output: String) -> [String: String] {
        var sections: [String: [String]] = [:]
        var currentKey: String?

        for rawLine in output.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty, !line.hasPrefix("$ ") else { continue }

            if line.hasPrefix("__OPS_"), line.hasSuffix("__") {
                currentKey = String(line.dropFirst("__OPS_".count).dropLast(2))
                if let currentKey {
                    sections[currentKey, default: []] = []
                }
                continue
            }

            guard let currentKey else { continue }
            sections[currentKey, default: []].append(line)
        }

        return sections.mapValues { $0.joined(separator: " ") }
    }

    private func value(for key: String, in sections: [String: String], fallback: String) -> String {
        let trimmed = sections[key]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? fallback : trimmed
    }

    private func parseListeningPorts(from rawValue: String?) -> [String] {
        let ports = (rawValue ?? "")
            .split(separator: " ")
            .map(String.init)
            .filter { !$0.isEmpty }

        let preferredOrder = ["22", "80", "443", "3306", "6379", "8080"]
        let uniquePorts = Array(Set(ports))

        return uniquePorts.sorted { left, right in
            let leftIndex = preferredOrder.firstIndex(of: left) ?? Int.max
            let rightIndex = preferredOrder.firstIndex(of: right) ?? Int.max
            if leftIndex == rightIndex {
                return left < right
            }
            return leftIndex < rightIndex
        }
    }

    private func makeServiceStatus(name: String, key: String, sections: [String: String]) -> ServerConfigSnapshot.ServiceStatus {
        let detail = value(for: key, in: sections, fallback: "unknown")
        let normalized = detail.lowercased()

        let state: ServerConfigSnapshot.ServiceStatus.State
        if normalized == "active" || normalized.contains("running") || normalized.range(of: #"^\d+(\.\d+)*$"#, options: .regularExpression) != nil {
            state = .running
        } else if normalized == "inactive" || normalized == "failed" || normalized.contains("stopped") || normalized.contains("not running") {
            state = .stopped
        } else {
            state = .unknown
        }

        return .init(id: key, name: name, state: state, detail: detail)
    }

    private func setError(_ message: String) {
        errorMessage = message
        appStore.recordIssue(message, source: "终端 / \(server.displayTitle)")
    }
}
