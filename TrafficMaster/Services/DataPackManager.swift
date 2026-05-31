import Foundation

enum DataPackManager {
    private static let configuredPathKey = "solo_export_pack_path"

    static var configuredPath: String? {
        get { UserDefaults.standard.string(forKey: configuredPathKey) }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue, forKey: configuredPathKey)
            } else {
                UserDefaults.standard.removeObject(forKey: configuredPathKey)
            }
        }
    }

    static func defaultMacPath() -> String {
        "/Users/vlad/PizdPDD/ADrive/export_all_questions"
    }

    static func resolvedURL() -> URL? {
        if let path = configuredPath, FileManager.default.fileExists(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        let fallback = defaultMacPath()
        if FileManager.default.fileExists(atPath: fallback) {
            return URL(fileURLWithPath: fallback)
        }
        return nil
    }

    static func importPickedExportFolder(_ sourceURL: URL) throws -> URL {
        let didStart = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didStart {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let destination = documents
            .appendingPathComponent("ExportPack", isDirectory: true)
            .appendingPathComponent("export_all_questions", isDirectory: true)

        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: sourceURL, to: destination)
        configuredPath = destination.path
        return destination
    }
}
