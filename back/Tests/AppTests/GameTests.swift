@testable import App
import XCTVapor

final class GameTests: XCTestCase {
    func testCreateGameReturnsCreated() async throws {
        try await withApp { app in
            try await app.test(.POST, "games", beforeRequest: { req in
                try req.content.encode(CreateGameDTO(
                    title: "Catan", minPlayers: 3, maxPlayers: 4, durationMinutes: 90
                ))
            }, afterResponse: { res async throws in
                XCTAssertEqual(res.status, .created)
                let game = try res.content.decode(GameDTO.self)
                XCTAssertEqual(game.title, "Catan")
                XCTAssertTrue(game.isAvailable)
            })
        }
    }

    func testCreateGameWithEmptyTitleIsRejected() async throws {
        try await withApp { app in
            try await app.test(.POST, "games", beforeRequest: { req in
                try req.content.encode(CreateGameDTO(
                    title: "", minPlayers: 3, maxPlayers: 4, durationMinutes: 90
                ))
            }, afterResponse: { res async throws in
                XCTAssertEqual(res.status, .badRequest)
            })
        }
    }

    func testCreateGameWithInvertedPlayerBoundsIsRejected() async throws {
        try await withApp { app in
            try await app.test(.POST, "games", beforeRequest: { req in
                try req.content.encode(CreateGameDTO(
                    title: "Catan", minPlayers: 5, maxPlayers: 2, durationMinutes: 90
                ))
            }, afterResponse: { res async throws in
                XCTAssertEqual(res.status, .badRequest)
            })
        }
    }

    func testListGames() async throws {
        try await withApp { app in
            _ = try await createGame(app, title: "Catan")
            _ = try await createGame(app, title: "Dixit")

            try await app.test(.GET, "games", afterResponse: { res async throws in
                XCTAssertEqual(res.status, .ok)
                XCTAssertEqual(try res.content.decode([GameDTO].self).count, 2)
            })
        }
    }

    func testShowGame() async throws {
        try await withApp { app in
            let game = try await createGame(app)
            let id = try XCTUnwrap(game.id)

            try await app.test(.GET, "games/\(id)", afterResponse: { res async throws in
                XCTAssertEqual(res.status, .ok)
                XCTAssertEqual(try res.content.decode(GameDTO.self).id, id)
            })
        }
    }

    func testShowUnknownGameReturnsNotFound() async throws {
        try await withApp { app in
            try await app.test(.GET, "games/\(UUID())", afterResponse: { res async throws in
                XCTAssertEqual(res.status, .notFound)
            })
        }
    }

    func testShowGameWithMalformedIDReturnsBadRequest() async throws {
        try await withApp { app in
            try await app.test(.GET, "games/not-a-uuid", afterResponse: { res async throws in
                XCTAssertEqual(res.status, .badRequest)
            })
        }
    }

    func testPreflightRequestFromAnotherOriginIsAllowed() async throws {
        try await withApp { app in
            try await app.test(.OPTIONS, "games", beforeRequest: { req in
                req.headers.replaceOrAdd(name: .origin, value: "http://localhost:8080")
                req.headers.replaceOrAdd(name: .accessControlRequestMethod, value: "POST")
                req.headers.replaceOrAdd(name: .accessControlRequestHeaders, value: "content-type")
            }, afterResponse: { res async throws in
                XCTAssertEqual(res.status, .ok)
                XCTAssertEqual(res.headers.first(name: .accessControlAllowOrigin), "*")
                XCTAssertTrue(res.headers[.accessControlAllowMethods].joined(separator: ",").contains("POST"))
            })
        }
    }

    func testErrorResponsesCarryTheCorsHeaders() async throws {
        try await withApp { app in
            try await app.test(.GET, "games/not-a-uuid", beforeRequest: { req in
                req.headers.replaceOrAdd(name: .origin, value: "http://localhost:8080")
            }, afterResponse: { res async throws in
                XCTAssertEqual(res.status, .badRequest)
                XCTAssertEqual(res.headers.first(name: .accessControlAllowOrigin), "*")
            })
        }
    }
    
    func testUpdateGameReturnsUpdatedGame() async throws {
        try await withApp { app in
            let game = try await createGame(app)
            let id = try XCTUnwrap(game.id)

            try await app.test(.PUT, "games/\(id)", beforeRequest: { req in
                try req.content.encode(CreateGameDTO(
                    title: "Catan 2", minPlayers: 2, maxPlayers: 5, durationMinutes: 60
                ))
            }, afterResponse: { res async throws in
                XCTAssertEqual(res.status, .ok)
                let updated = try res.content.decode(GameDTO.self)
                XCTAssertEqual(updated.title, "Catan 2")
            })
        }
    }
    
    func testUpdateUnknownGameReturnsNotFound() async throws {
        try await withApp { app in
            try await app.test(.PUT, "games/\(UUID())", beforeRequest: { req in
                try req.content.encode(CreateGameDTO(
                    title: "Catan", minPlayers: 3, maxPlayers: 4, durationMinutes: 90
                ))
            }, afterResponse: { res async throws in
                XCTAssertEqual(res.status, .notFound)
            })
        }
    }
    
    func testUpdateGameWithMalformedIDReturnsBadRequest() async throws {
        try await withApp { app in
            try await app.test(.PUT, "games/not-a-uuid", beforeRequest: { req in
                try req.content.encode(CreateGameDTO(
                    title: "Catan", minPlayers: 3, maxPlayers: 4, durationMinutes: 90
                ))
            }, afterResponse: { res async throws in
                XCTAssertEqual(res.status, .badRequest)
            })
        }
    }
    
    func testUpdateGameWithInvertedPlayerBoundsIsRejected() async throws {
        try await withApp { app in
            let game = try await createGame(app)
            let id = try XCTUnwrap(game.id)

            try await app.test(.PUT, "games/\(id)", beforeRequest: { req in
                try req.content.encode(CreateGameDTO(
                    title: "Catan 2", minPlayers: 5, maxPlayers: 2, durationMinutes: 60
                ))
            }, afterResponse: { res async throws in
                XCTAssertEqual(res.status, .badRequest)
            })
        }
    }
    
    func testDeleteGameReturnsNoContent() async throws {
        try await withApp { app in
            let game = try await createGame(app)
            let id = try XCTUnwrap(game.id)

            try await app.test(.DELETE, "games/\(id)", afterResponse: { res async throws in
                XCTAssertEqual(res.status, .noContent)
            })
        }
    }
    
    func testDeleteUnknownGameReturnsNotFound() async throws {
        try await withApp { app in
            try await app.test(.DELETE, "games/\(UUID())", afterResponse: { res async throws in
                XCTAssertEqual(res.status, .notFound)
            })
        }
    }
    
    func testDeleteGameWithLoansReturnsConflict() async throws {
        try await withApp { app in
            let game = try await createGame(app)
            let member = try await createMember(app)
            let gameID = try XCTUnwrap(game.id)
            let memberID = try XCTUnwrap(member.id)
            try await insertLoan(app,
                                 gameID: gameID,
                                 memberID: memberID,
                                 borrowedAt: Date(),
                                 dueAt: Date(),
                                 returnedAt: Date())
            try await app.test(.DELETE, "games/\(gameID)", afterResponse: { res async throws in
                XCTAssertEqual(res.status, .conflict)
            })
        }
    }
    
    func testSearchGamesByTitleIgnoresCase() async throws {
        try await withApp { app in
            _ = try await createGame(app, title: "Catan")
            _ = try await createGame(app, title: "Dixit")

            try await app.test(.GET, "games?q=CAT", afterResponse: { res async throws in
                XCTAssertEqual(res.status, .ok)
                let games = try res.content.decode([GameDTO].self)
                XCTAssertEqual(games.count, 1)
                XCTAssertEqual(games.first?.title, "Catan")
            })
        }
    }

    func testSearchGamesByNumberOfPlayers() async throws {
        try await withApp { app in
            _ = try await createGame(app, title: "Catan", minPlayers: 3, maxPlayers: 4)
            _ = try await createGame(app, title: "7 Wonders Duel", minPlayers: 2, maxPlayers: 2)

            try await app.test(.GET, "games?players=2", afterResponse: { res async throws in
                let games = try res.content.decode([GameDTO].self)
                XCTAssertEqual(games.count, 1)
                XCTAssertEqual(games.first?.title, "7 Wonders Duel")
            })
        }
    }

    func testSearchGamesByMaxDuration() async throws {
        try await withApp { app in
            _ = try await createGame(app, title: "Catan", durationMinutes: 90)
            _ = try await createGame(app, title: "Dixit", durationMinutes: 30)

            try await app.test(.GET, "games?maxDuration=60", afterResponse: { res async throws in
                let games = try res.content.decode([GameDTO].self)
                XCTAssertEqual(games.count, 1)
                XCTAssertEqual(games.first?.title, "Dixit")
            })
        }
    }

    func testSearchFiltersAreCombined() async throws {
        try await withApp { app in
            _ = try await createGame(app, title: "Catan", minPlayers: 3, maxPlayers: 4, durationMinutes: 90)
            _ = try await createGame(app, title: "Dixit", minPlayers: 3, maxPlayers: 6, durationMinutes: 30)
            _ = try await createGame(app, title: "Azul", minPlayers: 2, maxPlayers: 4, durationMinutes: 45)

            try await app.test(.GET, "games?players=5&maxDuration=60", afterResponse: { res async throws in
                let games = try res.content.decode([GameDTO].self)
                XCTAssertEqual(games.count, 1)
                XCTAssertEqual(games.first?.title, "Dixit")
            })
        }
    }

    func testSearchWithZeroPlayersIsRejected() async throws {
        try await withApp { app in
            try await app.test(.GET, "games?players=0", afterResponse: { res async throws in
                XCTAssertEqual(res.status, .badRequest)
            })
        }
    }

    func testSearchWithNonIntegerMaxDurationIsRejected() async throws {
        try await withApp { app in
            try await app.test(.GET, "games?maxDuration=abc", afterResponse: { res async throws in
                XCTAssertEqual(res.status, .badRequest)
            })
        }
    }
    
    func testFilterAvailableGamesOnly() async throws {
        try await withApp { app in
            let catan = try await createGame(app, title: "Catan")
            _ = try await createGame(app, title: "Dixit")
            let member = try await createMember(app)
            let catanID = try XCTUnwrap(catan.id)
            let memberID = try XCTUnwrap(member.id)

            try await insertLoan(app, gameID: catanID, memberID: memberID, borrowedAt: Date(), dueAt: Date())

            try await app.test(.GET, "games?available=true", afterResponse: { res async throws in
                let games = try res.content.decode([GameDTO].self)
                XCTAssertEqual(games.count, 1)
                XCTAssertEqual(games.first?.title, "Dixit")
            })
        }
    }

    func testFilterBorrowedGamesOnly() async throws {
        try await withApp { app in
            let catan = try await createGame(app, title: "Catan")
            _ = try await createGame(app, title: "Dixit")
            let member = try await createMember(app)
            let catanID = try XCTUnwrap(catan.id)
            let memberID = try XCTUnwrap(member.id)

            try await insertLoan(app, gameID: catanID, memberID: memberID, borrowedAt: Date(), dueAt: Date())

            try await app.test(.GET, "games?available=false", afterResponse: { res async throws in
                let games = try res.content.decode([GameDTO].self)
                XCTAssertEqual(games.count, 1)
                XCTAssertEqual(games.first?.title, "Catan")
            })
        }
    }

    func testAvailableFilterIsCombinedWithSearch() async throws {
        try await withApp { app in
            let catan = try await createGame(app, title: "Catan", durationMinutes: 90)
            _ = try await createGame(app, title: "Dixit", durationMinutes: 30)
            _ = try await createGame(app, title: "Azul", durationMinutes: 45)
            let member = try await createMember(app)
            let catanID = try XCTUnwrap(catan.id)
            let memberID = try XCTUnwrap(member.id)

            try await insertLoan(app, gameID: catanID, memberID: memberID, borrowedAt: Date(), dueAt: Date())

            try await app.test(.GET, "games?available=true&maxDuration=40", afterResponse: { res async throws in
                let games = try res.content.decode([GameDTO].self)
                XCTAssertEqual(games.count, 1)
                XCTAssertEqual(games.first?.title, "Dixit")
            })
        }
    }

    func testAvailableFilterWithInvalidValueIsRejected() async throws {
        try await withApp { app in
            try await app.test(.GET, "games?available=maybe", afterResponse: { res async throws in
                XCTAssertEqual(res.status, .badRequest)
            })
        }
    }
}
