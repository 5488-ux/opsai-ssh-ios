import Foundation

struct ServerConfigSnapshot: Equatable {
    struct ServiceStatus: Identifiable, Equatable {
        enum State: Equatable {
            case running
            case stopped
            case unknown

            var displayName: String {
                switch self {
                case .running:
                    return "运行中"
                case .stopped:
                    return "未运行"
                case .unknown:
                    return "未知"
                }
            }
        }

        let id: String
        let name: String
        let state: State
        let detail: String
    }

    let scannedAt: Date
    let hostName: String
    let operatingSystem: String
    let uptimeSummary: String
    let memorySummary: String
    let rootDiskSummary: String
    let listeningPorts: [String]
    let services: [ServiceStatus]

    init(
        scannedAt: Date = .now,
        hostName: String,
        operatingSystem: String,
        uptimeSummary: String,
        memorySummary: String,
        rootDiskSummary: String,
        listeningPorts: [String],
        services: [ServiceStatus]
    ) {
        self.scannedAt = scannedAt
        self.hostName = hostName
        self.operatingSystem = operatingSystem
        self.uptimeSummary = uptimeSummary
        self.memorySummary = memorySummary
        self.rootDiskSummary = rootDiskSummary
        self.listeningPorts = listeningPorts
        self.services = services
    }

    var summaryText: String {
        let portSummary = listeningPorts.isEmpty ? "未识别到常见监听端口" : listeningPorts.joined(separator: "、")
        let serviceSummary = services
            .map { "\($0.name)：\($0.state.displayName)（\($0.detail)）" }
            .joined(separator: "\n")

        return """
        主机：\(hostName)
        系统：\(operatingSystem)
        运行时间：\(uptimeSummary)
        内存：\(memorySummary)
        根分区：\(rootDiskSummary)
        监听端口：\(portSummary)
        服务状态：
        \(serviceSummary)
        """
    }
}
