import Foundation
import Observation
import Supabase

struct GameProfile: Codable, Identifiable, Hashable {
    var id: UUID { user_id }
    let user_id: UUID
    let handle: String
    let friend_code: String
}

struct GameRoom: Codable, Identifiable, Hashable {
    let id: UUID
    let invite_code: String
    let host_id: UUID
    let title: String
    let status: String
    let max_players: Int
}

struct GameRoomMember: Codable, Identifiable, Hashable {
    var id: UUID { user_id }
    let room_id: UUID
    let user_id: UUID
    let handle: String
    let seat: Int
}

struct GameFriendRequest: Codable, Identifiable, Hashable {
    let id: UUID
    let sender_id: UUID
    let recipient_id: UUID
    let status: String
}

@MainActor @Observable final class SocialLobby {
    private let client: SupabaseClient?
    var profile: GameProfile?
    var activeRoom: GameRoom?
    var roomMembers: [GameRoomMember] = []
    var openRooms: [GameRoom] = []
    var friends: [GameProfile] = []
    var incomingRequests: [GameFriendRequest] = []
    var errorMessage: String?
    var isConnecting = false
    var isGuest = false
    var pendingRoomCode = ""

    init() {
        guard let urlText = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              let url = URL(string: urlText),
              let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY") as? String,
              key.hasPrefix("sb_publishable_") else {
            client = nil
            errorMessage = "Supabase configuration is missing."
            return
        }
        client = SupabaseClient(supabaseURL: url, supabaseKey: key)
    }

    var npcSlots: Int { max(0, (activeRoom?.max_players ?? 8) - roomMembers.count) }
    var friendCode: String { profile?.friend_code ?? "—" }
    var roomShareText: String? {
        guard let activeRoom else { return nil }
        return "Join my Candy Coil room! Code: \(activeRoom.invite_code)\ncandycoil://join?code=\(activeRoom.invite_code)"
    }

    func beginGoogleSignIn() async {
        if profile == nil { await connect() }
        guard let client else { return }
        do {
            let callback = URL(string: "candycoil://auth-callback")
            if client.auth.currentSession == nil {
                _ = try await client.auth.signInWithOAuth(provider: .google, redirectTo: callback)
                await connect()
            } else if client.auth.currentUser?.isAnonymous == true {
                try await client.auth.linkIdentity(provider: .google, redirectTo: callback)
                errorMessage = "Finish linking your Google account in the browser to keep this profile on other devices."
            } else {
                errorMessage = "Your Google account is already connected."
            }
        } catch { errorMessage = error.localizedDescription }
    }

    func signOut() async {
        guard let client else { return }
        do {
            try await client.auth.signOut()
            profile = nil
            isGuest = false
            activeRoom = nil
            roomMembers = []
            friends = []
            incomingRequests = []
        } catch { errorMessage = error.localizedDescription }
    }

    func handleURL(_ url: URL) {
        guard url.scheme == "candycoil" else { return }
        if url.host == "join", let code = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "code" })?.value {
            pendingRoomCode = code.uppercased()
            Task { await connect() }
        } else if url.host == "auth-callback" {
            client?.auth.handle(url)
            Task {
                try? await Task.sleep(for: .milliseconds(400))
                await connect()
            }
        }
    }

    func connect() async {
        guard let client else { return }
        guard !isConnecting else { return }
        isConnecting = true
        defer { isConnecting = false }
        do {
            guard let user = client.auth.currentUser else {
                errorMessage = "Sign in with Google to create your player profile and join online rooms."
                return
            }
            isGuest = user.isAnonymous
            let existing: [GameProfile] = try await client.from("game_profiles")
                .select("user_id,handle,friend_code")
                .eq("user_id", value: user.id.uuidString)
                .limit(1)
                .execute().value
            if let existingProfile = existing.first {
                profile = existingProfile
            } else {
                let suffix = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(8))
                let created = GameProfile(user_id: user.id, handle: "Coil_\(suffix.prefix(6))", friend_code: suffix)
                try await client.from("game_profiles").insert(created).execute()
                profile = created
            }
            errorMessage = nil
            await refreshSocialData()
            if let activeRoom { await refreshRoom(activeRoom) }
            if !pendingRoomCode.isEmpty {
                let code = pendingRoomCode
                pendingRoomCode = ""
                await joinRoom(code: code)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshSocialData() async {
        guard let client, let profile else { return }
        do {
            let sent: [GameFriendRequest] = try await client.from("game_friend_requests")
                .select("id,sender_id,recipient_id,status")
                .eq("sender_id", value: profile.user_id.uuidString)
                .execute().value
            let received: [GameFriendRequest] = try await client.from("game_friend_requests")
                .select("id,sender_id,recipient_id,status")
                .eq("recipient_id", value: profile.user_id.uuidString)
                .execute().value
            let all = sent + received
            incomingRequests = received.filter { $0.status == "pending" }
            let friendIDs = Set(all.filter { $0.status == "accepted" }.map { $0.sender_id == profile.user_id ? $0.recipient_id : $0.sender_id })
            var loaded: [GameProfile] = []
            for id in friendIDs {
                let result: [GameProfile] = try await client.from("game_profiles")
                    .select("user_id,handle,friend_code")
                    .eq("user_id", value: id.uuidString)
                    .limit(1).execute().value
                loaded.append(contentsOf: result)
            }
            friends = loaded.sorted { $0.handle.localizedCaseInsensitiveCompare($1.handle) == .orderedAscending }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func sendFriendRequest(code: String) async {
        if profile == nil { await connect() }
        guard let client, let profile else { return }
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard normalized.count == 8 else { errorMessage = "Friend codes have 8 characters."; return }
        do {
            let target: [GameProfile] = try await client.from("game_profiles")
                .select("user_id,handle,friend_code")
                .eq("friend_code", value: normalized).limit(1).execute().value
            guard let recipient = target.first, recipient.user_id != profile.user_id else {
                errorMessage = "That friend code was not found."; return
            }
            try await client.from("game_friend_requests").insert(GameFriendRequestInsert(sender_id: profile.user_id, recipient_id: recipient.user_id)).execute()
            errorMessage = "Friend request sent to @\(recipient.handle)."
        } catch { errorMessage = error.localizedDescription }
    }

    func respondToFriendRequest(_ request: GameFriendRequest, accept: Bool) async {
        guard let client else { return }
        do {
            try await client.from("game_friend_requests")
                .update(FriendRequestUpdate(status: accept ? "accepted" : "declined", responded_at: ISO8601DateFormatter().string(from: Date())))
                .eq("id", value: request.id.uuidString).execute()
            await refreshSocialData()
        } catch { errorMessage = error.localizedDescription }
    }

    func refreshOpenRooms() async {
        guard let client else { return }
        do {
            openRooms = try await client.from("game_rooms")
                .select("id,invite_code,host_id,title,status,max_players")
                .eq("status", value: "waiting")
                .order("created_at", ascending: false)
                .limit(20).execute().value
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }

    func createRoom(title: String = "Candy Coil Room", maxPlayers: Int = 8) async {
        if profile == nil { await connect() }
        guard let client, let profile else { return }
        let normalizedTitle = String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(48))
        let room = GameRoom(id: UUID(), invite_code: String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(8)), host_id: profile.user_id, title: normalizedTitle.isEmpty ? "Candy Coil Room" : normalizedTitle, status: "waiting", max_players: min(12, max(2, maxPlayers)))
        do {
            try await client.from("game_rooms").insert(room).execute()
            do {
                try await addMembership(room: room, profile: profile, members: [])
            } catch {
                try? await client.from("game_rooms").delete().eq("id", value: room.id.uuidString).execute()
                throw error
            }
            activeRoom = room
            await refreshRoom(room)
            await refreshOpenRooms()
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }

    func joinRoom(code: String) async {
        if profile == nil { await connect() }
        guard let client, let profile else { return }
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        do {
            let matches: [GameRoom] = try await client.from("game_rooms")
                .select("id,invite_code,host_id,title,status,max_players")
                .eq("invite_code", value: normalized).eq("status", value: "waiting")
                .limit(1).execute().value
            guard let room = matches.first else { errorMessage = "No open room uses that code."; return }
            let members = try await fetchMembers(roomID: room.id)
            guard members.count < room.max_players else { errorMessage = "That room is full."; return }
            if !members.contains(where: { $0.user_id == profile.user_id }) {
                try await addMembership(room: room, profile: profile, members: members)
            }
            activeRoom = room
            if pendingRoomCode.caseInsensitiveCompare(room.invite_code) == .orderedSame { pendingRoomCode = "" }
            await refreshRoom(room)
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }

    func quickMatch() async {
        if profile == nil { await connect() }
        await refreshOpenRooms()
        for room in openRooms where room.host_id != profile?.user_id {
            await joinRoom(code: room.invite_code)
            if activeRoom != nil { return }
        }
        await createRoom()
    }

    func refreshRoom(_ room: GameRoom) async {
        do { roomMembers = try await fetchMembers(roomID: room.id) }
        catch { errorMessage = error.localizedDescription }
    }

    func leaveRoom() async {
        guard let client, let profile, let activeRoom else { return }
        do {
            try await client.from("game_room_members").delete()
                .eq("room_id", value: activeRoom.id.uuidString)
                .eq("user_id", value: profile.user_id.uuidString).execute()
            if activeRoom.host_id == profile.user_id {
                try await client.from("game_rooms").delete().eq("id", value: activeRoom.id.uuidString).execute()
            }
            self.activeRoom = nil
            roomMembers = []
            await refreshOpenRooms()
        } catch { errorMessage = error.localizedDescription }
    }

    private func fetchMembers(roomID: UUID) async throws -> [GameRoomMember] {
        guard let client else { return [] }
        return try await client.from("game_room_members")
            .select("room_id,user_id,handle,seat")
            .eq("room_id", value: roomID.uuidString)
            .order("seat").execute().value
    }

    private func addMembership(room: GameRoom, profile: GameProfile, members: [GameRoomMember]) async throws {
        guard let client else { return }
        let taken = Set(members.map(\.seat))
        guard let seat = (1...room.max_players).first(where: { !taken.contains($0) }) else {
            throw SocialError.roomFull
        }
        try await client.from("game_room_members").insert(GameRoomMemberInsert(room_id: room.id, user_id: profile.user_id, handle: profile.handle, seat: seat)).execute()
    }
}

private struct GameFriendRequestInsert: Encodable { let sender_id: UUID; let recipient_id: UUID }
private struct FriendRequestUpdate: Encodable { let status: String; let responded_at: String }
private struct GameRoomMemberInsert: Encodable { let room_id: UUID; let user_id: UUID; let handle: String; let seat: Int }
private enum SocialError: LocalizedError {
    case roomFull
    var errorDescription: String? { "This room is full." }
}
