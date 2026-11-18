import Fluent
import Vapor

struct GameController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let games = routes.grouped("games")
        games.get(use: index)
        games.post(use: create)
        
        let game = games.grouped(":gameID")
        game.get(use: show)
        game.put(use: update)
        game.delete(use: delete)
    }

    @Sendable
    func index(req: Request) async throws -> [GameDTO] {
        try GameSearchQuery.validate(query: req)
        let search = try req.query.decode(GameSearchQuery.self)

        var games = try await Game.query(on: req.db)
            .with(\.$loans)
            .all()

        if let q = search.q, !q.isEmpty {
            games = games.filter { $0.title.lowercased().contains(q.lowercased()) }
        }
        if let players = search.players {
            games = games.filter { $0.minPlayers <= players && $0.maxPlayers >= players }
        }
        if let maxDuration = search.maxDuration {
            games = games.filter { $0.durationMinutes <= maxDuration }
        }
        if let available = search.available {
            games = games.filter { $0.isAvailable == available }
        }

        return games.map { $0.toDTO() }
    }

    @Sendable
    func create(req: Request) async throws -> Response {
        try CreateGameDTO.validate(content: req)
        let dto = try req.content.decode(CreateGameDTO.self)
        try dto.ensureConsistentPlayerCount()

        let game = dto.toModel()
        try await game.save(on: req.db)
        return try await game.toDTO().encodeResponse(status: .created, for: req)
    }

    @Sendable
    func show(req: Request) async throws -> GameDTO {
        try await findGame(req).toDTO()
    }
    
    @Sendable
    func update(req: Request) async throws -> GameDTO {
        try CreateGameDTO.validate(content: req)
        let dto = try req.content.decode(CreateGameDTO.self)
        try dto.ensureConsistentPlayerCount()

        let game = try await findGame(req)
        
        game.title = dto.title
        game.minPlayers = dto.minPlayers
        game.maxPlayers = dto.maxPlayers
        game.durationMinutes = dto.durationMinutes
        
        try await game.save(on: req.db)
        return game.toDTO()
    }
    
    @Sendable
    func delete(req: Request) async throws -> HTTPStatus {
        let game = try await findGame(req)
        guard game.loans.isEmpty else {
            throw Abort(.conflict, reason: "A game with loans cannot be deleted")
        }
        try await game.delete(on: req.db)
        return .noContent
    }

    private func findGame(_ req: Request) async throws -> Game {
        guard let gameID = req.parameters.get("gameID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid game id")
        }
        guard let game = try await Game.query(on: req.db)
            .filter(\.$id == gameID)
            .with(\.$loans)
            .first()
        else {
            throw Abort(.notFound, reason: "Game not found")
        }
        return game
    }
}
