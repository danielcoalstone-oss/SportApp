import Foundation

enum AuditLogger {
    static func log(action: String, actorId: UUID?, objectId: UUID, metadata: [String: String] = [:]) {
        var payload: [String: String] = metadata
        payload["action"] = action
        payload["actorId"] = actorId?.uuidString ?? "anonymous"
        payload["objectId"] = objectId.uuidString
        payload["timestamp"] = ISO8601DateFormatter().string(from: Date())
        print("[AUDIT] \(payload)")
    }
}
