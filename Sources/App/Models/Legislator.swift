//
//  Legislator.swift
//  GlassHousesServer
//
//  Created by Jonathon Day on 3/2/17.
//
//

import Foundation
import Vapor
import Fluent

struct Legislator: Model {
    var id: Node?
    var exists: Bool = false
    let fullName: String
    let chamber: String
    
    func makeNode(context: Context) throws -> Node {
        return try Node(node: ["id": id,
                           "fullname": fullName,
                           "chamber": chamber])
    }
    
    static func prepare(_ database: Database) throws {
        try database.create("legislators") { legislators in
            legislators.id()
            legislators.string("fullname")
            legislators.string("chamber")
        }
    }
    
    static func revert(_ database: Database) throws {
        try database.delete("legislators")
    }
    
    init(node: Node, in: Context) throws {
        id = try node.extract("id")
        fullName = try node.extract("fullname")
        chamber = try node.extract("chamber")
    }
    
    init(fullName: String, chamber: String) {
        self.fullName = fullName
        self.chamber = chamber
    }
}

extension Legislator {
    func articles() throws -> Siblings<Article> {
        return try siblings()
    }
    func devices() throws -> Siblings<Device> {
        return try siblings()
    }
}
