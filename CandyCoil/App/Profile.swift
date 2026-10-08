import SwiftUI
import Observation

enum SnakeColour: String, CaseIterable, Identifiable, Codable {
    case mint, bubblegum, lemon, violet, tangerine
    var id: String { rawValue }
    var colour: Color {
        switch self {
        case .mint: .mint; case .bubblegum: .pink; case .lemon: .yellow; case .violet: .purple; case .tangerine: .orange
        }
    }
}

enum SnakeFace: String, CaseIterable, Identifiable, Codable {
    case classic, wink, star, sleepy
    var id: String { rawValue }
    var icon: String {
        switch self { case .classic: "👀"; case .wink: "😉"; case .star: "🤩"; case .sleepy: "😴" }
    }
}

struct SnakeAppearance: Codable, Equatable {
    var colour: SnakeColour = .mint
    var face: SnakeFace = .classic
    var pattern: SnakePattern = .racingStripes
}

extension SnakePattern {
    func localizedName(_ language: GameLanguage) -> String {
        switch (self, language) {
        case (.racingStripes, .english): "Racing stripes"
        case (.racingStripes, .spanish): "Rayas veloces"
        case (.racingStripes, .french): "Rayures rapides"
        case (.bubbleSpots, .english): "Bubble spots"
        case (.bubbleSpots, .spanish): "Lunares burbuja"
        case (.bubbleSpots, .french): "Pois bulles"
        case (.starTrail, .english): "Star trail"
        case (.starTrail, .spanish): "Rastro de estrellas"
        case (.starTrail, .french): "Traînée d'étoiles"
        case (.confetti, .english): "Confetti"
        case (.confetti, .spanish): "Confeti"
        case (.confetti, .french): "Confettis"
        case (.checkerboard, .english): "Checkerboard"
        case (.checkerboard, .spanish): "Cuadros"
        case (.checkerboard, .french): "Damier"
        case (.scales, .english): "Dragon scales"
        case (.scales, .spanish): "Escamas"
        case (.scales, .french): "Écailles"
        case (.hearts, .english): "Heart trail"
        case (.hearts, .spanish): "Rastro de corazones"
        case (.hearts, .french): "Traînée de cœurs"
        case (.neonRings, .english): "Neon rings"
        case (.neonRings, .spanish): "Aros de neón"
        case (.neonRings, .french): "Anneaux néon"
        case (.lightning, .english): "Lightning"
        case (.lightning, .spanish): "Relámpagos"
        case (.lightning, .french): "Éclairs"
        }
    }
}

struct OnlinePlayer: Identifiable, Equatable {
    let id: UUID
    let name: String
    let score: Int
    let colour: SnakeColour
    var isFriend: Bool
}

@Observable final class AccountSession {
    var displayName = "Guest Coil"
    var isSignedIn = false
    var googleSetupRequired = false

    func beginGoogleSignIn() {
        // Google OAuth needs a real provider/client configuration. Keeping this state explicit
        // avoids pretending that a local prototype has authenticated a person.
        googleSetupRequired = true
    }

    func signOut() { isSignedIn = false; displayName = "Guest Coil" }
}
