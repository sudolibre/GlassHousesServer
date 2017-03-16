//
//  Device.swift
//  GlassHousesServer
//
//  Created by Jonathon Day on 3/14/17.
//
//

import Foundation
import Vapor
import Fluent

struct Device: Model {
    var id: Node?
    var exists: Bool = false
    let token: String
    func makeNode(context: Context) throws -> Node {
        return try Node(node: [
            "id": id,
            "token": token,
            ])
    }
    static func prepare(_ database: Database) throws {
        try database.create("devices") { devices in
            devices.id()
            devices.string("token")
        }
    }
    static func revert(_ database: Database) throws {
        try database.delete("devices")
    }
    init(node: Node, in: Context) throws {
        id = try node.extract("id")
        token = try node.extract("deviceToken")
    }
    
    init(token: String) {
        self.token = token
    }
}

extension Device {
    func legislators() throws -> Siblings<Legislator> {
        return try siblings()
    }
}
