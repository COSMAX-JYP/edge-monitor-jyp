import Foundation

enum OutlookConfig {
    static let clientId = "95c855eb-c2dd-4319-833a-b9caffaae41a"
    static let tenantId = "88c3e3b5-abdd-4476-b47a-f563a26aae99"
    static let redirectUri = "msauth.com.jyp.EdgeLauncher://auth"
    static let authority = "https://login.microsoftonline.com/\(tenantId)"
    static let graphBase = "https://graph.microsoft.com/v1.0"

    static let scopes: [String] = [
        "User.Read",
        "Calendars.ReadWrite",
        "Calendars.ReadWrite.Shared",
        "People.Read"
    ]
}
