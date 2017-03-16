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
    let publisher: String
    let date: String
    let title: String
    let articleDescription: String
    let imageURL: String
    let link: String
    
    func makeNode(context: Context) throws -> Node {
        return try Node(node: [
            "id": id,
            "publisher": publisher,
            "date": date,
            "title": title,
            "articleDescription": articleDescription,
            "imageURL": imageURL,
            "link": link,
            ])
    }
    static func prepare(_ database: Database) throws {
        try database.create("articles") { articles in
            articles.id()
            articles.string("publisher")
            articles.string("date")
            articles.string("title")
            articles.string("articleDescription")
            articles.string("imageURL")
            articles.string("link")
        }
    }
    static func revert(_ database: Database) throws {
        try database.delete("articles")
    }
    
    init(node: Node, in: Context) throws {
        id = try node.extract("id")
        publisher = try node.extract("publisher")
        date = try node.extract("date")
        title = try node.extract("title")
        articleDescription = try node.extract("articleDescription")
        imageURL = try node.extract("imageURL")
        link = try node.extract("link")
    }
    
    init(publisher: String, date: String, title: String, articleDescription: String, imageURL: String, link: String) {
        self.publisher = publisher
        self.date = date
        self.title = title
        self.articleDescription = articleDescription
        self.imageURL = imageURL
        self.link = link
    }
}

extension Article {
    func legislators() throws -> Siblings<Legislator> {
        return try siblings()
    }
}
