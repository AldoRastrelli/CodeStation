import Foundation

enum PersistenceService {
    static let saveURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent(Strings.Persistence.appSupportDir)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(Strings.Persistence.filename)
    }()

    static func save(snapshot: StoreSnapshot) {
        do {
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: saveURL, options: .atomic)
        } catch {
            print("\(Strings.Persistence.saveFailed) \(error)")
        }
    }

    static func load() -> StoreSnapshot? {
        guard FileManager.default.fileExists(atPath: saveURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: saveURL)
            return try JSONDecoder().decode(StoreSnapshot.self, from: data)
        } catch {
            print("\(Strings.Persistence.loadFailed) \(error)")
            return nil
        }
    }

    // Writes a snapshot to an arbitrary location as human-readable JSON so the
    // user can keep a portable backup of their configuration.
    static func exportSnapshot(_ snapshot: StoreSnapshot, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(snapshot)
        try data.write(to: url, options: .atomic)
    }

    static func importSnapshot(from url: URL) throws -> StoreSnapshot {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(StoreSnapshot.self, from: data)
    }
}
