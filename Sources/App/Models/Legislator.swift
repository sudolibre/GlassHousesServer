//
//  Legislator.swift
//  GlassHousesServer
//
//  Created by Jonathon Day on 3/2/17.
//
//

import Foundation
import Vapor

struct Legislator: Model {
    var id: Node?
    let name: String
    let age: Int
    let email: String
    
    func makeNode(context: Context) throws -> Node {
        return try Node(node: ["id": id,
                           "name": name,
                           "age": age,
                           "email": email])
    }
    
    static func prepare(_ database: Database) throws {
        try database.create("legislators") { legislators in
            legislators.id()
            legislators.string("name")
            legislators.int("age")
            legislators.string("email")
        }
    }
    
    static func revert(_ database: Database) throws {
        try database.delete("legislators")
    }
    
    init(node: Node, in: Context) throws {
        id = try node.extract("id")
        name = try node.extract("name")
        age = try node.extract("age")
        email = try node.extract("email")
    }
    
    init(name: String, age: Int, email: String) {
        self.name = name
        self.age = age
        self.email = email
    }
}
