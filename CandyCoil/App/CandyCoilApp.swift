import SwiftUI
import SpriteKit

private let ink = Color(red: 0.035, green: 0.045, blue: 0.09)
private let aqua = Color(red: 0.32, green: 0.98, blue: 0.88)
private let muted = Color(red: 0.56, green: 0.61, blue: 0.72)

@main struct CandyCoilApp: App { var body: some Scene { WindowGroup { RootView().preferredColorScheme(.dark) } } }

struct RootView: View {
    @State private var session = GameSession()
    @Environment(\.scenePhase) private var phase
    var body: some View {
        Group { if session.playing { GameView(session: session) } else { LobbyView(session: session) } }
            .tint(aqua)
            .onOpenURL { session.social.handleURL($0) }
            .onChange(of: phase) { _, value in if value != .active && session.playing { session.touchBoosting = false; session.controllerBoosting = false; session.paused = true } }
    }
}

struct LobbyView: View {
    let session: GameSession
    @State private var collection = false
    @State private var account = false
    @State private var social = false
    @State private var appearance = false
    private func t(_ key: Copy) -> String { session.language.text(key) }

    var body: some View {
        ZStack {
            ink.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        Image(systemName: "circle.hexagongrid.fill").font(.title).foregroundStyle(aqua)
                        VStack(alignment: .leading, spacing: 2) { Text("CANDY COIL").font(.system(size: 17, weight: .black, design: .rounded)); Text(t(.tagline)).font(.system(size: 8, weight: .bold, design: .monospaced)).tracking(1.5).foregroundStyle(muted) }
                        Spacer()
                        Button { account = true } label: { AppearancePreview(appearance: session.appearance, size: 38).padding(7).background(.white.opacity(0.05), in: Circle()) }.accessibilityLabel(t(.account))
                    }
                    HStack { Label(t(.bestScore), systemImage: "crown.fill").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(muted); Spacer(); Text("\(session.best)").font(.system(size: 22, weight: .black, design: .rounded)).foregroundStyle(aqua) }
                        .padding(16).background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 20))
                    VStack(alignment: .leading, spacing: 0) {
                        HStack { Label(t(.arena), systemImage: "sparkle"); Spacer(); Text("01 / WILD") }.font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(1.5).foregroundStyle(aqua)
                        Text(title).font(.system(size: 38, weight: .black, design: .rounded)).tracking(-1.5).lineSpacing(-3).padding(.top, 18)
                        SnakeArtwork(appearance: session.appearance).frame(height: 235)
                        HStack(alignment: .bottom) { VStack(alignment: .leading, spacing: 5) { Text("COIL").font(.system(size: 11, weight: .black, design: .monospaced)).tracking(2); Text(subtitle).font(.system(size: 11)).foregroundStyle(muted) }; Spacer(); Text("🍬").font(.title2).padding(10).background(.white.opacity(0.05), in: Circle()) }
                    }.padding(22).background(LinearGradient(colors: [Color(red: 0.08, green: 0.15, blue: 0.2), Color(red: 0.09, green: 0.07, blue: 0.18)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 28)).overlay(RoundedRectangle(cornerRadius: 28).stroke(aqua.opacity(0.16)))
                    VStack(spacing: 7) {
                        Button(action: session.start) { HStack { Image(systemName: "play.fill"); Text(t(.play)); Spacer(); Image(systemName: "arrow.up.right") }.font(.system(size: 18, weight: .black, design: .rounded)).foregroundStyle(ink).padding(22).background(aqua, in: RoundedRectangle(cornerRadius: 20)) }.accessibilityIdentifier("play")
                        Text(t(.bots)).font(.system(size: 8, weight: .bold, design: .monospaced)).tracking(1.3).foregroundStyle(muted)
                        Button { social = true } label: { Label(t(.onlineMatch), systemImage: "person.3.fill").font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundStyle(aqua).padding(.vertical, 8) }
                    }
                    HStack(spacing: 12) { infoCard("arrow.up.left.and.arrow.down.right", t(.bigWorld), t(.worldSize)); Button { collection = true } label: { infoCard("birthday.cake.fill", t(.sweets), "\(session.discovered.count) \(t(.discovered))") }.buttonStyle(.plain) }
                    RadiantCard(t: t)
                    Button { appearance = true } label: { HStack { AppearancePreview(appearance: session.appearance, size: 44); VStack(alignment: .leading) { Text(t(.customise)).font(.system(size: 13, weight: .black)); Text(t(.appearance)).font(.system(size: 10)).foregroundStyle(muted) }; Spacer(); Image(systemName: "chevron.right").foregroundStyle(muted) }.padding(16).background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 20)) }.buttonStyle(.plain)
                    VStack(alignment: .leading, spacing: 12) { Text(t(.rules)).font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(2).foregroundStyle(muted); rule("01", t(.ruleEatTitle), t(.ruleEatBody)); rule("02", t(.ruleSelfTitle), t(.ruleSelfBody)); rule("03", t(.ruleDangerTitle), t(.ruleDangerBody)) }
                    Label(session.controllerName.map { "\($0) · \(t(.controller))" } ?? t(.controller), systemImage: "gamecontroller").font(.system(size: 11)).foregroundStyle(muted).padding(.bottom, 15)
                }.padding(.horizontal, 22).padding(.top, 16)
            }
        }
        .sheet(isPresented: $collection) { CollectionView(session: session) }
        .sheet(isPresented: $account) { AccountView(session: session) }
        .sheet(isPresented: $appearance) { AppearanceView(session: session) }
        .sheet(isPresented: $social) { SocialView(session: session) }
    }
    private var title: String { switch session.language { case .english: "One more sweet.\nOne more turn."; case .spanish: "Un dulce más.\nUna vuelta más."; case .french: "Un bonbon de plus.\nUn tour de plus." } }
    private var subtitle: String { switch session.language { case .english: "Small snake. Infinite appetite."; case .spanish: "Pequeña culebra. Hambre infinita."; case .french: "Petit serpent. Appétit infini." } }
    private func infoCard(_ icon: String, _ title: String, _ subtitle: String) -> some View { VStack(alignment: .leading, spacing: 8) { Image(systemName: icon).foregroundStyle(aqua); Text(title).font(.system(size: 13, weight: .bold)); Text(subtitle).font(.system(size: 10)).foregroundStyle(muted) }.frame(maxWidth: .infinity, alignment: .leading).padding(17).background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 20)) }
    private func rule(_ number: String, _ title: String, _ subtitle: String) -> some View { HStack(alignment: .top, spacing: 13) { Text(number).font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundStyle(aqua).padding(.top, 2); VStack(alignment: .leading, spacing: 3) { Text(title).font(.system(size: 13, weight: .bold)); Text(subtitle).font(.system(size: 11)).foregroundStyle(muted) } } }
}

struct RadiantCard: View { let t: (Copy) -> String; var body: some View { HStack(spacing: 14) { Text("🍭").font(.system(size: 34)).shadow(color: .yellow, radius: 12); VStack(alignment: .leading, spacing: 4) { Text(t(.radiant)).font(.system(size: 12, weight: .black, design: .monospaced)).foregroundStyle(.yellow); Text(t(.radiantDetail)).font(.system(size: 11)).foregroundStyle(muted) }; Spacer(); Text("×3").font(.title2.bold()).foregroundStyle(.yellow) }.padding(16).background(.yellow.opacity(0.10), in: RoundedRectangle(cornerRadius: 20)).overlay(RoundedRectangle(cornerRadius: 20).stroke(.yellow.opacity(0.35))) } }

struct SnakeArtwork: View {
    let appearance: SnakeAppearance
    var body: some View { Canvas { context, size in
        for x in stride(from: 0.0, to: size.width, by: 20) { for y in stride(from: 0.0, to: size.height, by: 20) { context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.5, height: 1.5)), with: .color(.white.opacity(0.10))) } }
        var path = Path(); path.move(to: CGPoint(x: size.width * 0.18, y: 175)); path.addCurve(to: CGPoint(x: size.width * 0.65, y: 125), control1: CGPoint(x: -5, y: 65), control2: CGPoint(x: size.width * 0.85, y: 230)); path.addCurve(to: CGPoint(x: size.width * 0.68, y: 60), control1: CGPoint(x: size.width * 0.39, y: 50), control2: CGPoint(x: size.width * 0.45, y: 42))
        context.stroke(path, with: .color(appearance.colour.colour.opacity(0.08)), style: StrokeStyle(lineWidth: 66, lineCap: .round)); context.stroke(path, with: .color(appearance.colour.colour.opacity(0.65)), style: StrokeStyle(lineWidth: 36, lineCap: .round)); context.stroke(path, with: .color(appearance.colour.colour), style: StrokeStyle(lineWidth: 24, lineCap: .round)); context.stroke(path, with: .color(.white.opacity(0.35)), style: StrokeStyle(lineWidth: 7, lineCap: .round, dash: [1, 16]))
        let x = size.width * 0.68; context.fill(Path(ellipseIn: CGRect(x: x - 20, y: 38, width: 42, height: 40)), with: .color(appearance.colour.colour)); context.draw(Text(appearance.face.icon).font(.system(size: 25)), at: CGPoint(x: x + 4, y: 58)); context.draw(Text("🍭").font(.system(size: 44)), at: CGPoint(x: size.width * 0.91, y: 43)); context.draw(Text("🍬").font(.system(size: 28)), at: CGPoint(x: size.width * 0.17, y: 58)); context.draw(Text("🍩").font(.system(size: 34)), at: CGPoint(x: size.width * 0.87, y: 185)); context.draw(Text("✦").foregroundStyle(.yellow).font(.title2), at: CGPoint(x: size.width * 0.44, y: 195))
    } }
}

struct AppearancePreview: View {
    let appearance: SnakeAppearance
    let size: CGFloat

    @ViewBuilder private var patternMarks: some View {
        switch appearance.pattern {
        case .racingStripes:
            VStack(spacing: size * 0.11) { Capsule().fill(.white.opacity(0.8)); Capsule().fill(.white.opacity(0.8)) }
                .frame(width: size * 0.62, height: size * 0.24).rotationEffect(.degrees(-35))
        case .bubbleSpots:
            HStack(spacing: size * 0.12) { Circle().fill(.white.opacity(0.78)); Circle().fill(.white.opacity(0.55)) }
                .frame(width: size * 0.44, height: size * 0.18)
        case .starTrail:
            Text("✦  ✦").font(.system(size: size * 0.22, weight: .black)).foregroundStyle(.white.opacity(0.8))
        case .confetti:
            HStack(spacing: size * 0.1) {
                Capsule().fill(.white.opacity(0.82)).frame(width: size * 0.1, height: size * 0.27).rotationEffect(.degrees(35))
                Circle().fill(.white.opacity(0.7)).frame(width: size * 0.11)
                Capsule().fill(.white.opacity(0.75)).frame(width: size * 0.1, height: size * 0.25).rotationEffect(.degrees(-30))
            }
        case .checkerboard:
            LazyVGrid(columns: [GridItem(.fixed(size * 0.18)), GridItem(.fixed(size * 0.18))], spacing: 2) { ForEach(0..<4) { i in Rectangle().fill(i.isMultiple(of: 2) ? .white.opacity(0.85) : .white.opacity(0.3)) } }.frame(width: size * 0.4, height: size * 0.4).rotationEffect(.degrees(45))
        case .scales:
            HStack(spacing: size * 0.04) { ForEach(0..<3) { _ in Circle().fill(.white.opacity(0.78)).frame(width: size * 0.16, height: size * 0.16) } }
        case .hearts:
            Text("♥  ♥").font(.system(size: size * 0.2, weight: .black)).foregroundStyle(.white.opacity(0.85))
        case .neonRings:
            HStack(spacing: size * 0.06) { ForEach(0..<2) { _ in Circle().stroke(.white.opacity(0.9), lineWidth: size * 0.055).frame(width: size * 0.25, height: size * 0.25).shadow(color: .white, radius: 3) } }
        case .lightning:
            Text("ϟ ϟ").font(.system(size: size * 0.3, weight: .black)).foregroundStyle(.white.opacity(0.92))
        }
    }

    var body: some View {
        ZStack {
            Circle().fill(appearance.colour.colour)
            patternMarks.frame(width: size * 0.9, height: size * 0.9).clipShape(Circle())
            Text(appearance.face.icon).font(.system(size: size * 0.5)).shadow(color: .black.opacity(0.2), radius: 3, y: 1)
        }.frame(width: size, height: size)
    }
}

struct AccountView: View {
    let session: GameSession
    @Environment(\.dismiss) private var dismiss
    private func t(_ key: Copy) -> String { session.language.text(key) }
    var body: some View {
        @Bindable var session = session
        NavigationStack {
            Form {
                Section(t(.accountTitle)) {
                    HStack {
                        AppearancePreview(appearance: session.appearance, size: 46)
                        VStack(alignment: .leading) {
                            Text(session.social.profile?.handle ?? session.account.displayName).fontWeight(.bold)
                            Text(session.social.profile != nil ? t(.signedIn) : t(.signIn)).font(.caption).foregroundStyle(muted)
                        }
                    }
                    if session.social.profile == nil || session.social.isGuest {
                        Button { Task { await session.social.beginGoogleSignIn() } } label: { Label(t(.googleButton), systemImage: "g.circle.fill") }
                    }
                    if let message = session.social.errorMessage { Text(message).font(.footnote).foregroundStyle(muted) }
                    if session.social.profile != nil { Button(t(.signOut), role: .destructive) { Task { await session.social.signOut() } } }
                }
                Section(t(.language)) {
                    Picker(t(.language), selection: $session.language) { ForEach(GameLanguage.allCases) { Text($0.title).tag($0) } }.pickerStyle(.segmented)
                }
            }
            .scrollContentBackground(.hidden).background(ink).navigationTitle(t(.account))
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }.tint(aqua)
    }
}

struct AppearanceView: View {
    let session: GameSession
    @Environment(\.dismiss) private var dismiss
    private func t(_ key: Copy) -> String { session.language.text(key) }
    var body: some View {
        @Bindable var session = session
        NavigationStack {
            VStack(spacing: 24) {
                AppearancePreview(appearance: session.appearance, size: 130)
                    .shadow(color: session.appearance.colour.colour, radius: 18)
                Picker(t(.colour), selection: $session.appearance.colour) {
                    ForEach(SnakeColour.allCases) { colour in Text(colour.rawValue.capitalized).tag(colour) }
                }.pickerStyle(.palette)
                Picker(t(.face), selection: $session.appearance.face) {
                    ForEach(SnakeFace.allCases) { face in Text(face.icon).tag(face) }
                }.pickerStyle(.segmented)
                VStack(alignment: .leading, spacing: 11) {
                    Text(t(.pattern)).font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1.5).foregroundStyle(muted)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(SnakePattern.allCases) { pattern in
                            let selected = session.appearance.pattern == pattern
                            Button { session.appearance.pattern = pattern } label: {
                                HStack(spacing: 8) {
                                    Text(pattern.icon).font(.system(size: 17, weight: .bold))
                                    Text(t(patternCopy(for: pattern))).font(.system(size: 11, weight: .bold)).lineLimit(1)
                                    Spacer(minLength: 0)
                                }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
                                    .background(selected ? aqua.opacity(0.16) : .white.opacity(0.045), in: RoundedRectangle(cornerRadius: 13))
                                    .overlay(RoundedRectangle(cornerRadius: 13).stroke(selected ? aqua.opacity(0.5) : .white.opacity(0.06)))
                            }.buttonStyle(.plain).foregroundStyle(selected ? aqua : .white)
                        }
                    }
                }
                Spacer(minLength: 0)
                Button(t(.save)) { dismiss() }.font(.headline).frame(maxWidth: .infinity).padding()
                    .background(aqua, in: RoundedRectangle(cornerRadius: 16)).foregroundStyle(ink)
            }.padding(24).background(ink).navigationTitle(t(.customise))
        }.tint(aqua)
    }

    private func patternCopy(for pattern: SnakePattern) -> Copy {
        switch pattern {
        case .racingStripes: .racingStripes
        case .bubbleSpots: .bubbleSpots
        case .starTrail: .starTrail
        case .confetti: .confetti
        case .checkerboard: .checkerboard
        case .scales: .scales
        case .hearts: .hearts
        case .neonRings: .neonRings
        case .lightning: .lightning
        }
    }
}

struct SocialView: View {
    let session: GameSession
    @Environment(\.dismiss) private var dismiss
    @State private var friendCode = ""
    private func t(_ key: Copy) -> String { session.language.text(key) }
    var body: some View {
        @Bindable var social = session.social
        NavigationStack {
            List {
                Section(t(.onlineTitle)) {
                    Text(t(.onlineDetail)).font(.footnote).foregroundStyle(muted)
                    if social.isGuest || social.profile == nil {
                        Button { Task { await social.beginGoogleSignIn() } } label: { Label(t(.googleButton), systemImage: "g.circle.fill") }
                    }
                    if social.isConnecting { ProgressView().tint(aqua) }
                    if let message = social.errorMessage {
                        Label(message, systemImage: "exclamationmark.circle.fill").font(.caption).foregroundStyle(.orange).textSelection(.enabled)
                    }
                }

                if let room = social.activeRoom {
                    Section(room.title) {
                        HStack {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(t(.roomCode)).font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(muted)
                                Text(room.invite_code).font(.system(size: 27, weight: .black, design: .rounded)).tracking(4).foregroundStyle(aqua).textSelection(.enabled)
                            }
                            Spacer()
                            ShareLink(item: social.roomShareText ?? "Join my Candy Coil room with code \(room.invite_code)") {
                                Label(t(.shareInvite), systemImage: "square.and.arrow.up").labelStyle(.iconOnly).font(.title2).padding(13).background(aqua.opacity(0.13), in: Circle())
                            }.accessibilityLabel(t(.shareInvite))
                        }
                        Text("\(social.roomMembers.count)/\(room.max_players) · \(t(.roomPlayers))").font(.caption).foregroundStyle(muted)
                        ForEach(social.roomMembers) { member in
                            HStack {
                                Image(systemName: member.user_id == room.host_id ? "crown.fill" : "person.fill").foregroundStyle(member.user_id == room.host_id ? .yellow : aqua)
                                Text(member.handle).fontWeight(.semibold)
                                if member.user_id == social.profile?.user_id { Text("YOU").font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(aqua) }
                                Spacer()
                                Text("#\(member.seat)").font(.caption.monospaced()).foregroundStyle(muted)
                            }
                        }
                        ForEach(0..<social.npcSlots, id: \.self) { index in
                            HStack {
                                Image(systemName: "cpu.fill").foregroundStyle(muted)
                                Text("NPC \(index + 1)").fontWeight(.medium).foregroundStyle(muted)
                                Spacer()
                                Text("BOT · #\(social.roomMembers.count + index + 1)").font(.caption.monospaced()).foregroundStyle(muted)
                            }
                        }
                        if social.npcSlots > 0 {
                            Label(t(.npcFill), systemImage: "cpu.fill").font(.caption).foregroundStyle(muted)
                        }
                        Button(role: .destructive) { Task { await social.leaveRoom() } } label: { Label(t(.leaveRoom), systemImage: "rectangle.portrait.and.arrow.right") }
                    }
                } else {
                    Section(t(.roomCode)) {
                        HStack(spacing: 9) {
                            TextField(t(.roomCodeHint), text: $social.pendingRoomCode).textInputAutocapitalization(.characters).autocorrectionDisabled().textFieldStyle(.roundedBorder)
                            Button(t(.join)) { Task { await social.joinRoom(code: social.pendingRoomCode) } }.buttonStyle(.borderedProminent).disabled(social.pendingRoomCode.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                        Button { Task { await social.createRoom() } } label: { Label(t(.createRoom), systemImage: "plus.app.fill") }
                        Button { Task { await social.quickMatch() } } label: { Label(t(.quickMatch), systemImage: "sparkles") }
                        if !social.openRooms.isEmpty {
                            ForEach(social.openRooms) { room in
                                Button { Task { await social.joinRoom(code: room.invite_code) } } label: {
                                    HStack { VStack(alignment: .leading) { Text(room.title).fontWeight(.semibold); Text("\(room.invite_code) · \(room.max_players) max").font(.caption.monospaced()).foregroundStyle(muted) }; Spacer(); Image(systemName: "arrow.right.circle.fill").foregroundStyle(aqua) }
                                }.foregroundStyle(.white)
                            }
                        }
                    }
                }

                Section(t(.friendsTitle)) {
                    if let profile = social.profile {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) { Text(t(.myFriendCode)).font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(muted); Text(profile.friend_code).font(.system(.title2, design: .monospaced, weight: .black)).tracking(2).foregroundStyle(aqua).textSelection(.enabled) }
                            Spacer()
                            ShareLink(item: "Add me on Candy Coil: \(profile.friend_code)") { Image(systemName: "square.and.arrow.up").font(.title3).padding(12).background(aqua.opacity(0.13), in: Circle()) }.accessibilityLabel(t(.shareInvite))
                        }
                    }
                    HStack(spacing: 9) {
                        TextField(t(.friendCode), text: $friendCode).textInputAutocapitalization(.characters).autocorrectionDisabled().textFieldStyle(.roundedBorder)
                        Button(t(.sendRequest)) { Task { await social.sendFriendRequest(code: friendCode); friendCode = "" } }.buttonStyle(.bordered).disabled(friendCode.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    if !social.incomingRequests.isEmpty {
                        Text(t(.pendingRequests)).font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(muted)
                        ForEach(social.incomingRequests) { request in
                            HStack {
                                Text(String(request.sender_id.uuidString.prefix(8))).font(.caption.monospaced())
                                Spacer()
                                Button(t(.acceptFriend)) { Task { await social.respondToFriendRequest(request, accept: true) } }.buttonStyle(.borderedProminent)
                                Button(t(.declineFriend)) { Task { await social.respondToFriendRequest(request, accept: false) } }.buttonStyle(.bordered)
                            }
                        }
                    }
                    if social.friends.isEmpty { Text(t(.noFriends)).foregroundStyle(muted) }
                    ForEach(social.friends) { friend in Label(friend.handle, systemImage: "heart.fill").foregroundStyle(.pink) }
                }
            }
            .scrollContentBackground(.hidden)
            .background(ink)
            .navigationTitle(t(.friends))
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .task { await social.connect(); await social.refreshOpenRooms() }
            .task(id: social.activeRoom?.id) {
                guard let room = social.activeRoom else { return }
                while !Task.isCancelled {
                    await social.refreshRoom(room)
                    try? await Task.sleep(for: .seconds(2))
                }
            }
            .task(id: social.profile?.user_id) {
                while !Task.isCancelled {
                    await social.refreshSocialData()
                    await social.refreshOpenRooms()
                    try? await Task.sleep(for: .seconds(12))
                }
            }
        }
        .tint(aqua)
    }
}

struct GameView: View {
    let session: GameSession
    private func t(_ key: Copy) -> String { session.language.text(key) }
    var body: some View {
        GeometryReader { geometry in
            let landscape = geometry.size.width > geometry.size.height
            let controlSize: CGFloat = landscape ? 104 : 132
            ZStack {
                ink.ignoresSafeArea()
                if let scene = session.scene { SpriteView(scene: scene).ignoresSafeArea() }
                VStack {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("CANDY COIL").font(.system(size: 10, weight: .black, design: .monospaced)).tracking(2).foregroundStyle(aqua)
                            Text("\(session.score)").font(.system(size: 32, weight: .black, design: .rounded))
                            Text("\(session.eaten) \(t(.candies)) · #\(session.rank)").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(muted)
                        }.padding(15).background(ink.opacity(0.85), in: RoundedRectangle(cornerRadius: 18))
                        Spacer()
                        Button { session.paused = true } label: { Image(systemName: "pause.fill").font(.title3).padding(16).background(ink.opacity(0.85), in: Circle()) }.accessibilityLabel(t(.pause))
                    }
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 7) {
                                Text(t(.leaderboard)).foregroundStyle(muted).font(.system(size: 8, weight: .bold, design: .monospaced))
                                ForEach(Array(session.leaderboard.enumerated()), id: \.offset) { index, entry in
                                    HStack { Text("\(index + 1)  \(entry.0)"); Spacer(); Text("\(entry.1)") }
                                        .font(.system(size: 10, weight: .semibold)).foregroundStyle(entry.0 == "You" ? aqua : .white)
                                }
                            }.frame(width: 112).padding(12).background(ink.opacity(0.8), in: RoundedRectangle(cornerRadius: 15))
                            Radar(points: session.radar, size: landscape ? 48 : 64)
                        }
                    }
                    Spacer(minLength: 8)
                    HStack(alignment: .bottom, spacing: landscape ? 16 : 12) {
                        Joystick(size: controlSize) { x, y in session.steer(x: x, y: y) }
                        Spacer(minLength: 0)
                        BoostButton(language: session.language, isActive: session.boosting) { session.touchBoosting = $0 }
                    }.padding(.bottom, 8)
                }.padding(landscape ? 12 : 20).allowsHitTesting(!session.gameOver && !session.paused)
                if session.paused || session.gameOver { PauseCard(session: session) }
            }
        }.persistentSystemOverlays(.hidden)
    }
}

struct Radar: View { let points: [CGPoint]; var size: CGFloat = 78; var body: some View { VStack(spacing: 5) { Canvas { context, size in context.stroke(Path(CGRect(origin: .zero, size: size)), with: .color(aqua.opacity(0.4)), lineWidth: 2); for (i, point) in points.enumerated() { let p = CGRect(x: point.x * size.width - 2, y: point.y * size.height - 2, width: i == 0 ? 5 : 3, height: i == 0 ? 5 : 3); context.fill(Path(ellipseIn: p), with: .color(i == 0 ? aqua : .pink)) } }.frame(width: size, height: size).padding(6).background(ink.opacity(0.85), in: RoundedRectangle(cornerRadius: 12)); Text("RADAR").font(.system(size: 8, weight: .bold, design: .monospaced)).tracking(2).foregroundStyle(muted) } } }

struct PauseCard: View { let session: GameSession; private func t(_ key: Copy) -> String { session.language.text(key) }; var body: some View { ZStack { Color.black.opacity(0.65).ignoresSafeArea(); VStack(spacing: 18) { Text(session.gameOver ? "🍬" : "☕️").font(.system(size: 52)); Text(session.gameOver ? t(.gameOver) : t(.pause)).font(.system(size: 29, weight: .black, design: .rounded)); Text(session.gameOver ? session.reason + "\n" + t(.gameOverDetail) : "").font(.system(size: 14)).foregroundStyle(muted).multilineTextAlignment(.center); if session.gameOver { Text("\(session.score) \(t(.score)) · \(session.eaten) \(t(.candies))").font(.headline).foregroundStyle(aqua) }; Button { if session.gameOver { session.retry() } else { session.paused = false } } label: { Text(session.gameOver ? t(.retry) : t(.resume)).font(.system(size: 13, weight: .black)).frame(maxWidth: .infinity).padding(19).background(aqua, in: RoundedRectangle(cornerRadius: 15)).foregroundStyle(ink) }; Button(t(.home), action: session.leave).font(.system(size: 13)).foregroundStyle(muted).padding(8) }.padding(28).background(ink, in: RoundedRectangle(cornerRadius: 28)).overlay(RoundedRectangle(cornerRadius: 28).stroke(aqua.opacity(0.18))).padding(24) } } }

struct Joystick: View { var size: CGFloat = 132; var onMove: (Double, Double) -> Void; @State private var offset = CGSize.zero; var body: some View { let center = size / 2; let knob = size * 0.36; ZStack { Circle().fill(ink.opacity(0.7)).overlay(Circle().stroke(aqua.opacity(0.25), lineWidth: 1)); Circle().stroke(.white.opacity(0.06), lineWidth: 1).padding(size * 0.12); Image(systemName: "plus").font(.system(size: size * 0.34, weight: .ultraLight)).foregroundStyle(.white.opacity(0.1)); Circle().fill(aqua).frame(width: knob, height: knob).overlay(Image(systemName: "circle.grid.2x2.fill").font(.system(size: knob * 0.38)).foregroundStyle(ink.opacity(0.5))).offset(offset) }.frame(width: size, height: size).contentShape(Circle()).gesture(DragGesture(minimumDistance: 0).onChanged { value in let x = value.location.x - center, y = value.location.y - center, distance = max(1, hypot(x, y)), scale = min(1, size * 0.32 / distance); offset = CGSize(width: x * scale, height: y * scale); onMove(x, y) }.onEnded { _ in offset = .zero }) } }

struct BoostButton: View {
    let language: GameLanguage
    let isActive: Bool
    let setActive: (Bool) -> Void
    private var title: String { language.text(.boost) }
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "bolt.fill").font(.system(size: 23, weight: .black))
            Text(title).font(.system(size: 9, weight: .black, design: .monospaced)).tracking(0.8)
        }.foregroundStyle(isActive ? ink : .white)
            .frame(width: 74, height: 74)
            .background(isActive ? aqua : Color.orange.opacity(0.78), in: Circle())
            .overlay(Circle().stroke(.white.opacity(isActive ? 0.8 : 0.25), lineWidth: 2))
            .shadow(color: (isActive ? aqua : .orange).opacity(0.5), radius: isActive ? 14 : 7)
            .contentShape(Circle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { _ in setActive(true) }.onEnded { _ in setActive(false) })
            .accessibilityElement().accessibilityLabel(title).accessibilityAddTraits(.isButton)
    }
}

struct CollectionView: View { let session: GameSession; @Environment(\.dismiss) private var dismiss; private func t(_ key: Copy) -> String { session.language.text(key) }; var body: some View { NavigationStack { ScrollView { VStack(alignment: .leading, spacing: 15) { Text(t(.sweets)).font(.system(size: 29, weight: .black, design: .rounded)); Text("\(session.discovered.count) / 50 \(t(.discovered))").font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(aqua); LazyVGrid(columns: [GridItem(.adaptive(minimum: 95))], spacing: 12) { ForEach(CandyKind.all) { kind in VStack(spacing: 8) { Text(kind.emoji).font(.system(size: CGFloat(25 + kind.tier * 4))).frame(height: 50); Text(kind.localizedName(session.language.rawValue)).font(.system(size: 10, weight: .semibold)).multilineTextAlignment(.center).frame(height: 28); Text("+\(kind.growth)").font(.system(size: 9, weight: .bold)).foregroundStyle(aqua); Image(systemName: session.discovered.contains(kind.id) ? "checkmark.circle.fill" : "circle.dotted").font(.caption).foregroundStyle(session.discovered.contains(kind.id) ? aqua : muted) }.frame(maxWidth: .infinity).padding(.vertical, 12).background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 16)) } } }.padding(20) }.background(ink).navigationTitle(t(.sweets)).toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } } }.tint(aqua) } }
