import Foundation

enum AIAssistantProfile: String, CaseIterable, Identifiable, Codable {
    case operations
    case security
    case database
    case container
    case website

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .operations:
            return "运维助手"
        case .security:
            return "安全助手"
        case .database:
            return "数据库助手"
        case .container:
            return "容器助手"
        case .website:
            return "网站助手"
        }
    }

    var shortDescription: String {
        switch self {
        case .operations:
            return "资源、服务与日志排查"
        case .security:
            return "风险、入侵与加固建议"
        case .database:
            return "MySQL / Redis 等诊断"
        case .container:
            return "Docker 容器与镜像排查"
        case .website:
            return "站点、SSL 与访问分析"
        }
    }

    var introMessage: String {
        switch self {
        case .operations:
            return "我是你的运维助手。你可以直接描述问题，我会先给出判断，再生成可批准执行的命令计划。"
        case .security:
            return "我是安全助手。你可以让我排查异常登录、端口暴露、权限风险或加固建议，我会优先给出只读检查方案。"
        case .database:
            return "我是数据库助手。你可以问我 MySQL、Redis、MongoDB 的连接、性能、主从或容量问题，我会按诊断步骤起草命令。"
        case .container:
            return "我是容器助手。你可以让我分析 Docker 容器状态、镜像、网络或日志问题，我会给出逐步排查命令。"
        case .website:
            return "我是网站助手。你可以让我分析 Nginx、SSL、站点访问和 502/504 等问题，我会先判断，再给出可审批的命令计划。"
        }
    }

    var promptPlaceholder: String {
        switch self {
        case .operations:
            return "例如：为什么这台机器今天 CPU 一直很高？"
        case .security:
            return "例如：帮我检查这台机器有没有异常登录风险"
        case .database:
            return "例如：为什么 MySQL 最近响应很慢？"
        case .container:
            return "例如：为什么 Docker 容器总是自动退出？"
        case .website:
            return "例如：为什么站点今天频繁出现 502？"
        }
    }

    var quickPrompts: [String] {
        switch self {
        case .operations:
            return [
                "检查服务器负载为什么变高",
                "看看磁盘空间是否快满了",
                "生成一份系统体检思路",
                "分析最近的终端输出"
            ]
        case .security:
            return [
                "检查最近是否有异常登录痕迹",
                "看看高危端口和暴露面",
                "帮我做一轮基础安全体检",
                "分析这台机器的权限风险"
            ]
        case .database:
            return [
                "排查 MySQL 无法启动的原因",
                "分析 Redis 内存为什么持续增长",
                "看看数据库连接数是否异常",
                "检查慢查询排查思路"
            ]
        case .container:
            return [
                "检查 Docker 容器状态",
                "为什么容器一直重启",
                "看看镜像和磁盘占用",
                "分析容器日志排查思路"
            ]
        case .website:
            return [
                "排查 nginx 返回 502 的原因",
                "检查 SSL 证书和续签状态",
                "看看站点访问日志异常",
                "分析反向代理配置问题"
            ]
        }
    }

    var systemPrompt: String {
        switch self {
        case .operations:
            return "当前角色：运维助手。重点关注系统负载、进程、磁盘、网络、服务状态与日志。"
        case .security:
            return "当前角色：安全助手。重点关注登录审计、权限、暴露端口、异常进程、安全配置与风险分级。"
        case .database:
            return "当前角色：数据库助手。重点关注 MySQL、Redis、MongoDB 等数据库服务的状态、性能、连接、容量与复制问题。"
        case .container:
            return "当前角色：容器助手。重点关注 Docker 容器状态、镜像、卷、网络、日志和编排相关问题。"
        case .website:
            return "当前角色：网站助手。重点关注网站访问、Nginx、反向代理、SSL、证书和站点日志。"
        }
    }

    func makeTerminalAnalysisPrompt(using terminalOutput: String) -> String {
        let label: String
        switch self {
        case .operations:
            label = "根据下面这段终端输出继续做运维分析，先解释现象，再给出需要人工批准的下一步命令："
        case .security:
            label = "根据下面这段终端输出继续做安全分析，先说明风险判断，再给出需要人工批准的检查命令："
        case .database:
            label = "根据下面这段终端输出继续做数据库分析，先判断问题方向，再给出需要人工批准的诊断命令："
        case .container:
            label = "根据下面这段终端输出继续做容器分析，先解释异常，再给出需要人工批准的排查命令："
        case .website:
            label = "根据下面这段终端输出继续做网站分析，先说明可能原因，再给出需要人工批准的排查命令："
        }

        return "\(label)\n\n\(terminalOutput)"
    }
}
