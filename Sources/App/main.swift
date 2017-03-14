import Vapor
import VaporPostgreSQL

let drop = Droplet()
drop.preparations.append(Legislator.self)

do {
try drop.addProvider(VaporPostgreSQL.Provider.self)
} catch {
    assertionFailure("Error adding provider \(error)")
}

drop.get("legislators", Int.self) { req, userID in
    guard let legislator = try Legislator.find(userID) else {
        throw Abort.notFound
    }
    return try legislator.makeJSON()
}


drop.get("legislators") { req in
    let legislators = try Legislator.all().makeNode()
    let legislatorsDictionary = ["legislators": legislators]
    return try JSON(node: legislatorsDictionary)
}

drop.get { req in
    return try drop.view.make("welcome", [
    	"message": drop.localization[req.lang, "welcome", "title"]
    ])
}

drop.post("legislator") { (req) in
    var legislator = try Legislator(node: req.json)
    try legislator.save()
    return try legislator.makeJSON()
}


drop.resource("posts", PostController())

drop.run()
