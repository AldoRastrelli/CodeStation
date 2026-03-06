import Foundation

struct NotificationSettings: Codable, Equatable {
    var enabled: Bool = true
    var notifyWhenDone: Bool = true      // cooking → ready
    var notifyWhenWaiting: Bool = true   // cooking → waiting
    var soundEnabled: Bool = true
    var soundName: String = "Funk"

    static let availableSounds = [
        "Basso", "Blow", "Bottle", "Frog", "Funk",
        "Glass", "Hero", "Morse", "Ping", "Pop",
        "Purr", "Sosumi", "Submarine", "Tink"
    ]
}
