import Foundation
import os

enum AppLog {
    private static let subsystem = "com.jyp.EdgeLauncher"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let weather = Logger(subsystem: subsystem, category: "weather")
    static let event = Logger(subsystem: subsystem, category: "event")
    static let launcher = Logger(subsystem: subsystem, category: "launcher")
    static let monitor = Logger(subsystem: subsystem, category: "monitor")
    static let web = Logger(subsystem: subsystem, category: "web")
}
