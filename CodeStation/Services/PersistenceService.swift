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
}
