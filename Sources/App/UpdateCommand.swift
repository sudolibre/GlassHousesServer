//
//  UpdateCommand.swift
//  GlassHousesServer
//
//  Created by Jonathon Day on 4/4/17.
//
//

import Foundation

import Vapor
import Console

final class UpdateCommand: Command {
    public let id = "update"
    public let help = ["This command triggers a news update and APNS messages"]
    public let console: ConsoleProtocol
    
    public init(console: ConsoleProtocol) {
        self.console = console
    }
    
    public func run(arguments: [String]) throws {
        console.print("updating...")
        try? updateCommand()
        saveCurrentTime()
    }
}
