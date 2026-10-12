import SwiftUI

enum GameLanguage: String, CaseIterable, Identifiable {
    case english
    case spanish
    case french

    var id: String { rawValue }
    var title: String {
        switch self { case .english: "English"; case .spanish: "Español"; case .french: "Français" }
    }

    func text(_ key: Copy) -> String { key.values[self] ?? key.values[.english] ?? key.rawValue }
}

enum Copy: String {
    case tagline, bestScore, arena, play, localMatch, onlineMatch, worldSize, sweets, discovered
    case rules, ruleEatTitle, ruleEatBody, ruleSelfTitle, ruleSelfBody, ruleDangerTitle, ruleDangerBody
    case controller, signIn, signedIn, account, customise, friends, onlinePlayers, join, invite
    case accountTitle, googleButton, googleSetup, language, appearance, colour, face, save
    case radiant, radiantDetail, onlineTitle, onlineDetail, friendsTitle, friendsDetail
    case leaderboard, pause, resume, boost, gameOver, gameOverDetail, retry, home, score, candies, rank
    case bigWorld, ready, signOut, noFriends, addFriend, onlineStatus, bots, botDemo, practiceBots
    case roomCode, roomCodeHint, createRoom, quickMatch, friendCode, myFriendCode, sendRequest
    case pendingRequests, acceptFriend, declineFriend, roomPlayers, npcFill, shareInvite, leaveRoom
    case findPlayers, roomFull, startRoomGame, roomGameNote
    case pattern, racingStripes, bubbleSpots, starTrail, confetti, checkerboard, scales, hearts, neonRings, lightning, deathBorder, deathSnake

    var values: [GameLanguage: String] {
        switch self {
        case .tagline: [.english: "A LITTLE SNAKE. A BIG APPETITE.", .spanish: "UNA PEQUEÑA CULEBRA. UN GRAN APETITO.", .french: "UN PETIT SERPENT. UN GRAND APPÉTIT."]
        case .bestScore: [.english: "YOUR BEST SCORE", .spanish: "TU MEJOR MARCA", .french: "VOTRE MEILLEUR SCORE"]
        case .arena: [.english: "CANDY WILDS", .spanish: "TIERRAS DE DULCES", .french: "TERRES DE BONBONS"]
        case .play: [.english: "PLAY NOW", .spanish: "JUGAR AHORA", .french: "JOUER"]
        case .localMatch: [.english: "PRACTICE WITH BOTS", .spanish: "PRACTICAR CON BOTS", .french: "S'ENTRAÎNER AVEC DES BOTS"]
        case .onlineMatch: [.english: "FIND AN ONLINE ROOM", .spanish: "BUSCAR SALA ONLINE", .french: "TROUVER UNE SALLE EN LIGNE"]
        case .worldSize: [.english: "12,000 × 12,000 world", .spanish: "mundo de 12.000 × 12.000", .french: "monde de 12 000 × 12 000"]
        case .sweets: [.english: "50 SWEETS", .spanish: "50 DULCES", .french: "50 BONBONS"]
        case .discovered: [.english: "discovered", .spanish: "descubiertos", .french: "découverts"]
        case .rules: [.english: "HOW IT WORKS", .spanish: "CÓMO FUNCIONA", .french: "COMMENT JOUER"]
        case .ruleEatTitle: [.english: "Eat and grow", .spanish: "Come y crece", .french: "Mange et grandis"]
        case .ruleEatBody: [.english: "Bigger sweets make your Coil grow farther.", .spanish: "Los dulces grandes hacen crecer más a Coil.", .french: "Les gros bonbons font davantage grandir Coil."]
        case .ruleSelfTitle: [.english: "Find your own path", .spanish: "Encuentra tu camino", .french: "Trace ton chemin"]
        case .ruleSelfBody: [.english: "You can glide over your own body.", .spanish: "Puedes pasar sobre tu propio cuerpo.", .french: "Tu peux passer sur ton propre corps."]
        case .ruleDangerTitle: [.english: "Dodge rivals and edges", .spanish: "Evita rivales y bordes", .french: "Évite les rivaux et les bords"]
        case .ruleDangerBody: [.english: "Your eaten sweets drop where you lose.", .spanish: "Los dulces que comiste caen donde pierdes.", .french: "Tes bonbons tombent là où tu perds."]
        case .controller: [.english: "Touch joystick or connected game controller", .spanish: "Joystick táctil o mando USB/Bluetooth", .french: "Joystick tactile ou manette USB/Bluetooth"]
        case .signIn: [.english: "SIGN IN", .spanish: "INICIAR SESIÓN", .french: "SE CONNECTER"]
        case .signedIn: [.english: "SIGNED IN", .spanish: "SESIÓN INICIADA", .french: "CONNECTÉ"]
        case .account: [.english: "ACCOUNT", .spanish: "CUENTA", .french: "COMPTE"]
        case .customise: [.english: "CUSTOMISE COIL", .spanish: "PERSONALIZAR COIL", .french: "PERSONNALISER COIL"]
        case .friends: [.english: "FRIENDS", .spanish: "AMIGOS", .french: "AMIS"]
        case .onlinePlayers: [.english: "PRACTICE NPCS", .spanish: "NPC DE PRÁCTICA", .french: "PNJ D'ENTRAÎNEMENT"]
        case .join: [.english: "JOIN", .spanish: "ENTRAR", .french: "REJOINDRE"]
        case .invite: [.english: "ADD FRIEND", .spanish: "AÑADIR AMIGO", .french: "AJOUTER UN AMI"]
        case .accountTitle: [.english: "Your Coil account", .spanish: "Tu cuenta de Coil", .french: "Ton compte Coil"]
        case .googleButton: [.english: "CONTINUE WITH GOOGLE", .spanish: "CONTINUAR CON GOOGLE", .french: "CONTINUER AVEC GOOGLE"]
        case .googleSetup: [.english: "Google sign-in is in testing and limited to approved test accounts.", .spanish: "El inicio de sesión con Google está en pruebas y limitado a cuentas autorizadas.", .french: "La connexion Google est en test et réservée aux comptes autorisés."]
        case .language: [.english: "LANGUAGE", .spanish: "IDIOMA", .french: "LANGUE"]
        case .appearance: [.english: "APPEARANCE", .spanish: "APARIENCIA", .french: "APPARENCE"]
        case .colour: [.english: "COLOUR", .spanish: "COLOR", .french: "COULEUR"]
        case .face: [.english: "FACE", .spanish: "CARA", .french: "VISAGE"]
        case .save: [.english: "SAVE LOOK", .spanish: "GUARDAR ESTILO", .french: "ENREGISTRER LE STYLE"]
        case .radiant: [.english: "RADIANT SWEET", .spanish: "DULCE RADIANTE", .french: "BONBON RAYONNANT"]
        case .radiantDetail: [.english: "Shines brightly · 3× growth", .spanish: "Brilla intensamente · 3× crecimiento", .french: "Brille intensément · croissance ×3"]
        case .onlineTitle: [.english: "Online rooms", .spanish: "Salas en línea", .french: "Salles en ligne"]
        case .onlineDetail: [.english: "Create a room and share its code, join a friend, or find an open room.", .spanish: "Crea una sala y comparte el código, únete a un amigo o busca una sala abierta.", .french: "Crée une salle et partage son code, rejoins un ami ou trouve une salle ouverte."]
        case .friendsTitle: [.english: "Your friends", .spanish: "Tus amigos", .french: "Tes amis"]
        case .friendsDetail: [.english: "Invite people you meet in the wilds.", .spanish: "Invita a las personas que encuentres en las tierras.", .french: "Invite les joueurs rencontrés dans les terres."]
        case .leaderboard: [.english: "TOP · BOTS", .spanish: "TOP · BOTS", .french: "TOP · BOTS"]
        case .pause: [.english: "PAUSE", .spanish: "PAUSA", .french: "PAUSE"]
        case .resume: [.english: "KEEP PLAYING", .spanish: "SEGUIR JUGANDO", .french: "CONTINUER"]
        case .boost: [.english: "BOOST", .spanish: "ACELERAR", .french: "ACCÉLÉRER"]
        case .gameOver: [.english: "A sweet ending.", .spanish: "Un final dulce.", .french: "Une fin sucrée."]
        case .gameOverDetail: [.english: "Your sweets are still in the wilds.", .spanish: "Tus dulces siguen en las tierras.", .french: "Tes bonbons sont encore dans les terres."]
        case .retry: [.english: "RETURN TO THE WILDS", .spanish: "VOLVER A LAS TIERRAS", .french: "RETOURNER AUX TERRES"]
        case .home: [.english: "Back to home", .spanish: "Volver al inicio", .french: "Retour à l'accueil"]
        case .score: [.english: "SCORE", .spanish: "PUNTOS", .french: "SCORE"]
        case .candies: [.english: "SWEETS", .spanish: "DULCES", .french: "BONBONS"]
        case .rank: [.english: "RANK", .spanish: "RANGO", .french: "RANG"]
        case .bigWorld: [.english: "A bigger world", .spanish: "Un mundo más grande", .french: "Un monde plus grand"]
        case .ready: [.english: "READY", .spanish: "LISTO", .french: "PRÊT"]
        case .signOut: [.english: "SIGN OUT", .spanish: "CERRAR SESIÓN", .french: "SE DÉCONNECTER"]
        case .noFriends: [.english: "No friends yet", .spanish: "Aún no tienes amigos", .french: "Pas encore d'amis"]
        case .addFriend: [.english: "Friend request sent", .spanish: "Solicitud enviada", .french: "Demande envoyée"]
        case .onlineStatus: [.english: "ONLINE", .spanish: "EN LÍNEA", .french: "EN LIGNE"]
        case .botDemo: [.english: "NPC · PRACTICE ONLY", .spanish: "NPC · SOLO PRÁCTICA", .french: "PNJ · ENTRAÎNEMENT"]
        case .practiceBots: [.english: "PRACTICE", .spanish: "PRACTICAR", .french: "S'ENTRAÎNER"]
        case .roomCode: [.english: "ROOM CODE", .spanish: "CÓDIGO DE SALA", .french: "CODE DE SALLE"]
        case .roomCodeHint: [.english: "Enter an invite code", .spanish: "Escribe un código de invitación", .french: "Saisis un code d'invitation"]
        case .createRoom: [.english: "CREATE ROOM", .spanish: "CREAR SALA", .french: "CRÉER UNE SALLE"]
        case .quickMatch: [.english: "FIND A ROOM", .spanish: "BUSCAR SALA", .french: "TROUVER UNE SALLE"]
        case .friendCode: [.english: "FRIEND CODE", .spanish: "CÓDIGO DE AMIGO", .french: "CODE AMI"]
        case .myFriendCode: [.english: "YOUR FRIEND CODE", .spanish: "TU CÓDIGO DE AMIGO", .french: "VOTRE CODE AMI"]
        case .sendRequest: [.english: "SEND REQUEST", .spanish: "ENVIAR SOLICITUD", .french: "ENVOYER UNE DEMANDE"]
        case .pendingRequests: [.english: "FRIEND REQUESTS", .spanish: "SOLICITUDES DE AMISTAD", .french: "DEMANDES D'AMITIÉ"]
        case .acceptFriend: [.english: "ACCEPT", .spanish: "ACEPTAR", .french: "ACCEPTER"]
        case .declineFriend: [.english: "DECLINE", .spanish: "RECHAZAR", .french: "REFUSER"]
        case .roomPlayers: [.english: "PLAYERS IN ROOM", .spanish: "JUGADORES EN LA SALA", .french: "JOUEURS DANS LA SALLE"]
        case .npcFill: [.english: "NPCs will fill the remaining spots", .spanish: "Los NPC ocuparán los espacios vacíos", .french: "Des PNJ rempliront les places libres"]
        case .shareInvite: [.english: "SHARE INVITE", .spanish: "COMPARTIR INVITACIÓN", .french: "PARTAGER L'INVITATION"]
        case .leaveRoom: [.english: "LEAVE ROOM", .spanish: "SALIR DE LA SALA", .french: "QUITTER LA SALLE"]
        case .findPlayers: [.english: "No open rooms right now. We created one for you.", .spanish: "No hay salas abiertas. Creamos una para ti.", .french: "Aucune salle ouverte. Nous en avons créé une pour vous."]
        case .roomFull: [.english: "This room is full.", .spanish: "La sala está llena.", .french: "Cette salle est complète."]
        case .startRoomGame: [.english: "START PRACTICE GAME", .spanish: "INICIAR PARTIDA DE PRÁCTICA", .french: "LANCER UNE PARTIE D’ENTRAÎNEMENT"]
        case .roomGameNote: [.english: "Your invite room is ready. This build starts a local game with bots; room members are not yet connected inside the match.", .spanish: "Tu sala de invitación está lista. Esta versión inicia una partida local con bots; los miembros todavía no se conectan dentro del juego.", .french: "Votre salon d’invitation est prêt. Cette version lance une partie locale avec des bots ; les membres ne sont pas encore connectés dans la partie."]
        case .bots: [.english: "48 RIVALS · OFFLINE", .spanish: "48 RIVALES · SIN CONEXIÓN", .french: "48 RIVAUX · HORS LIGNE"]
        case .pattern: [.english: "BODY PATTERN", .spanish: "PATRÓN DEL CUERPO", .french: "MOTIF DU CORPS"]
        case .racingStripes: [.english: "Stripes", .spanish: "Rayas", .french: "Rayures"]
        case .bubbleSpots: [.english: "Spots", .spanish: "Lunares", .french: "Pois"]
        case .starTrail: [.english: "Stars", .spanish: "Estrellas", .french: "Étoiles"]
        case .confetti: [.english: "Confetti", .spanish: "Confeti", .french: "Confettis"]
        case .checkerboard: [.english: "Checkerboard", .spanish: "Cuadros", .french: "Damier"]
        case .scales: [.english: "Scales", .spanish: "Escamas", .french: "Écailles"]
        case .hearts: [.english: "Heart trail", .spanish: "Corazones", .french: "Cœurs"]
        case .neonRings: [.english: "Neon rings", .spanish: "Aros de neón", .french: "Anneaux néon"]
        case .lightning: [.english: "Lightning", .spanish: "Relámpagos", .french: "Éclairs"]
        case .deathBorder: [.english: "You reached the edge of the wilds.", .spanish: "Llegaste al borde de las tierras.", .french: "Tu as atteint la limite des terres."]
        case .deathSnake: [.english: "You ran into another snake.", .spanish: "Chocaste con otra serpiente.", .french: "Tu as percuté un autre serpent."]
        }
    }
}
