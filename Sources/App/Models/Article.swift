//
//  Article.swift
//  GlassHousesServer
//
//  Created by Jonathon Day on 3/14/17.
//
//

import Foundation
import Vapor
import Fluent


struct Article: Model {
    var id: Node?
    var exists: Bool = false
    let date: Date
    let description: String
    let url: String
    var publisher: String
    var name: String
    
    
    static func getDateFromString(_ dateString: String) -> Date {
    let dateFormatter1: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return df
    }()
    let dateFormatter2: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()
        if let date = dateFormatter1.date(from: dateString) {
            return date
        } else if let date = dateFormatter2.date(from: dateString) {
            return date
        } else {
            // Assuming we are checking every 24hrs using the current time as the date may be preferable over failing to initialize.
            //TODO: add analytics to identify additional formats that may need to be handled
            return Date()
        }
    }
    
    func makeNode(context: Context) throws -> Node {
        return try Node(node: [
            "id": id,
            "date": date.timeIntervalSince1970,
            "description": description,
            "url": url,
            "name": name,
            "publisher": publisher
            ])
    }
    static func prepare(_ database: Database) throws {
        try database.create("articles") { articles in
            articles.id()
            articles.string("date")
            articles.custom("description", type: "text")
            articles.custom("url", type: "text")
            articles.string("name")
            articles.string("publisher")
       }
    }
    static func revert(_ database: Database) throws {
        try database.delete("articles")
    }
    
    init(node: Node, in: Context) throws {
        id = try node.extract("id")
        description = try node.extract("description")
        url = try node.extract("url")
        name = try node.extract("name")
        publisher = try node.extract("publisher")
        let dateInterval: Double = try node.extract("date")
        date = Date(timeIntervalSince1970: dateInterval)
    }
    
    init?(json: JSON) {
        guard let description = json["description"]?.string,
        let url = json["url"]?.string,
        let name = json["name"]?.string,
        let publisher = json["provider", 0, "name"]?.string,
        let dateString = json["datePublished"]?.string else {
            return nil
        }
        self.description = description
        self.url = url
        self.name = name
        self.publisher = publisher
        self.date = Article.getDateFromString(dateString)
    }
}

extension Article {
    func legislators() throws -> Siblings<Legislator> {
        return try siblings()
    }
}
