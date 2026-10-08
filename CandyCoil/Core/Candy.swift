import Foundation

struct CandyKind: Identifiable, Equatable {
    let id: Int
    let name: String
    let emoji: String
    let tier: Int
    var growth: Int { [2, 4, 7, 12, 20][tier] }
    var radius: Double { Double(7 + tier * 3) }
    static let all: [CandyKind] = {
        let families: [(String, String)] = [("Candy", "🍬"), ("Lollipop", "🍭"), ("Chocolate", "🍫"), ("Cookie", "🍪"), ("Donut", "🍩"), ("Cupcake", "🧁"), ("Ice Cream", "🍦"), ("Cake", "🍰"), ("Mochi", "🍡"), ("Flan", "🍮")]
        let sizes = ["mini", "classic", "large", "giant", "cosmic"]
        return families.enumerated().flatMap { index, family in
            sizes.enumerated().map { tier, size in CandyKind(id: index * 5 + tier, name: "\(family.0) \(size)", emoji: family.1, tier: tier) }
        }
    }()

    func localizedName(_ language: String) -> String {
        let families: [String: [String]] = [
            "spanish": ["Caramelo", "Piruleta", "Chocolate", "Galleta", "Donut", "Cupcake", "Helado", "Pastel", "Mochi", "Flan"],
            "french": ["Bonbon", "Sucette", "Chocolat", "Cookie", "Donut", "Cupcake", "Glace", "Gâteau", "Mochi", "Flan"],
        ]
        let sizes: [String: [String]] = [
            "spanish": ["mini", "clásico", "grande", "gigante", "cósmico"],
            "french": ["mini", "classique", "grand", "géant", "cosmique"],
        ]
        guard let names = families[language], let variants = sizes[language] else { return name }
        return "\(names[id / 5]) \(variants[tier])"
    }
}

enum CandyPower: Int, Codable, CaseIterable {
    case normal
    case radiant

    var multiplier: Int { self == .radiant ? 3 : 1 }
}

struct Point: Equatable {
    var x: Double
    var y: Double
    func distance(to other: Point) -> Double { hypot(x - other.x, y - other.y) }
    func distanceSquared(to other: Point) -> Double { (x - other.x) * (x - other.x) + (y - other.y) * (y - other.y) }
}

struct Candy: Identifiable {
    let id: UUID
    let kindID: Int
    var position: Point
    let dropped: Bool
    let power: CandyPower
    var kind: CandyKind { CandyKind.all[kindID] }
    var growth: Int { kind.growth * power.multiplier }
    init(kindID: Int, position: Point, dropped: Bool = false, power: CandyPower = .normal) {
        self.id = UUID(); self.kindID = kindID; self.position = position; self.dropped = dropped; self.power = power
    }
}

struct CandyReward: Equatable, Codable {
    let kindID: Int
    let power: CandyPower
    var growth: Int { CandyKind.all[kindID].growth * power.multiplier }
}

struct Serpent: Identifiable {
    let id: Int
    var name: String
    var body: [Point]
    var angle: Double
    var pattern: SnakePattern = .racingStripes
    var inventory: [CandyReward] = []
    var alive = true
    var grace: Double = 2
    var score: Int { inventory.reduce(0) { $0 + $1.growth } }
    var length: Int { 24 + score }
    /// Young snakes stay nimble; a high score gradually thickens the whole trail.
    var bodyWidth: Double { 22 + min(32, sqrt(Double(score)) * 3.5) }
    var aiTarget: Point?
    var aiTargetCandyID: UUID?
    var aiRetargetIn = 0.0
    var aiIgnoreCandyIn = 0.0
    var aiSampleIn = 0.0
    var aiRecentHeads: [Point] = []
    var head: Point { body[0] }
}
