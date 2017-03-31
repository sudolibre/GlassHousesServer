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
    var token: String
    func makeNode(context: Context) throws -> Node {
        return try Node(node: [
            "id": id,
            "token": token,
            ])
    }
    static func fetchOrCreate(json: JSON?) throws -> Device? {
        guard let json = json else {
            return nil
        }
        if let token = json["token"]?.string,
        let device = try Device.query().filter("token", token).first() {
            return device
        } else {
            var device = try Device(node: json)
            try device.save()
            return device
        }
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
        token = try node.extract("token")
    }
}

extension Device {
    func legislators() throws -> Siblings<Legislator> {
        return try siblings()
    }
}
