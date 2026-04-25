import Foundation

struct AIDiagnosticTool: Identifiable, Hashable {
    let id: String
    let displayName: String
    let shortDescription: String
    let commands: [String]
    let assistantProfiles: Set<AIAssistantProfile>
    let analysisPromptPrefix: String

    static func presets(for assistant: AIAssistantProfile) -> [AIDiagnosticTool] {
        all.filter { $0.assistantProfiles.contains(assistant) }
    }

    func makeAnalysisPrompt(using output: String) -> String {
        "\(analysisPromptPrefix)\n\n\(output)"
    }

    private static let all: [AIDiagnosticTool] = [
        AIDiagnosticTool(
            id: "ops-overview",
            displayName: "系统概览",
            shortDescription: "查看主机、负载、内存和根分区占用",
            commands: [
                "hostname",
                "uptime",
                "free -h",
                "df -h /"
            ],
            assistantProfiles: [.operations],
            analysisPromptPrefix: "我刚运行了“系统概览”工具。请根据下面结果总结机器当前状态，并给出接下来值得人工批准的排查命令。"
        ),
        AIDiagnosticTool(
            id: "ops-process",
            displayName: "进程速览",
            shortDescription: "查看 CPU 与内存占用靠前的进程",
            commands: [
                "ps aux --sort=-%cpu | head -n 12",
                "ps aux --sort=-%mem | head -n 12"
            ],
            assistantProfiles: [.operations],
            analysisPromptPrefix: "我刚运行了“进程速览”工具。请根据下面结果判断资源异常方向，并给出下一步只读排查命令。"
        ),
        AIDiagnosticTool(
            id: "security-login",
            displayName: "登录审计",
            shortDescription: "查看最近登录与失败登录记录",
            commands: [
                "last -n 10",
                "lastb -n 10"
            ],
            assistantProfiles: [.security],
            analysisPromptPrefix: "我刚运行了“登录审计”工具。请根据结果判断是否存在异常登录风险，并给出下一步检查命令。"
        ),
        AIDiagnosticTool(
            id: "security-network",
            displayName: "暴露面检查",
            shortDescription: "查看监听端口与网络连接概况",
            commands: [
                "ss -lntp",
                "ss -ant | head -n 30"
            ],
            assistantProfiles: [.security],
            analysisPromptPrefix: "我刚运行了“暴露面检查”工具。请根据结果判断当前暴露面和可疑连接，并给出下一步只读检查命令。"
        ),
        AIDiagnosticTool(
            id: "db-mysql",
            displayName: "MySQL 状态",
            shortDescription: "检查 MySQL 进程与监听状态",
            commands: [
                "ps aux | grep '[m]ysql'",
                "ss -lntp | grep 3306"
            ],
            assistantProfiles: [.database],
            analysisPromptPrefix: "我刚运行了“MySQL 状态”工具。请根据结果判断数据库服务是否异常，并给出下一步诊断命令。"
        ),
        AIDiagnosticTool(
            id: "db-redis",
            displayName: "Redis 状态",
            shortDescription: "检查 Redis 进程与监听状态",
            commands: [
                "ps aux | grep '[r]edis'",
                "ss -lntp | grep 6379"
            ],
            assistantProfiles: [.database],
            analysisPromptPrefix: "我刚运行了“Redis 状态”工具。请根据结果判断 Redis 是否异常，并给出下一步只读诊断命令。"
        ),
        AIDiagnosticTool(
            id: "container-ps",
            displayName: "容器状态",
            shortDescription: "查看容器列表与运行状态",
            commands: [
                "docker ps -a --format 'table {{.Names}}\\t{{.Status}}\\t{{.Image}}'"
            ],
            assistantProfiles: [.container],
            analysisPromptPrefix: "我刚运行了“容器状态”工具。请根据结果判断容器异常点，并给出下一步排查命令。"
        ),
        AIDiagnosticTool(
            id: "container-space",
            displayName: "容器占用",
            shortDescription: "查看镜像、容器和卷的磁盘占用",
            commands: [
                "docker system df"
            ],
            assistantProfiles: [.container],
            analysisPromptPrefix: "我刚运行了“容器占用”工具。请根据结果判断磁盘占用问题，并给出下一步排查命令。"
        ),
        AIDiagnosticTool(
            id: "site-nginx",
            displayName: "Nginx 状态",
            shortDescription: "检查 Nginx 进程和监听端口",
            commands: [
                "ps aux | grep '[n]ginx'",
                "ss -lntp | grep ':80\\|:443'"
            ],
            assistantProfiles: [.website],
            analysisPromptPrefix: "我刚运行了“Nginx 状态”工具。请根据结果判断站点服务状态，并给出下一步排查命令。"
        ),
        AIDiagnosticTool(
            id: "site-errors",
            displayName: "站点错误日志",
            shortDescription: "查看常见 Nginx 错误日志尾部",
            commands: [
                "tail -n 80 /www/wwwlogs/error.log"
            ],
            assistantProfiles: [.website],
            analysisPromptPrefix: "我刚运行了“站点错误日志”工具。请根据日志判断问题方向，并给出下一步排查命令。"
        )
    ]
}
