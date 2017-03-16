import Vapor
import VaporPostgreSQL
import Fluent

let drop = Droplet()
drop.preparations.append(Legislator.self)
drop.preparations.append(Article.self)
drop.preparations.append(Device.self)
drop.preparations.append(Pivot<Device, Legislator>.self)

do {
try drop.addProvider(VaporPostgreSQL.Provider.self)
} catch {
    assertionFailure("Error adding provider \(error)")
}

drop.get("articles") { (req) in
    let legislators = try Legislator.all().makeNode()
    let legislatorsDictionary = ["legislators": legislators]
    return try JSON(node: legislatorsDictionary)
}

drop.post("register") { req in
    var device = Device(token: (req.json?["deviceToken"]?.string)!)
    try device.save()
    if let legislatorsJSON = req.json?["legislators"]!.pathIndexableArray {
        for legislatorJSON in legislatorsJSON {
            var legislator = try Legislator(node: legislatorJSON)
            do {
            try legislator.save()
            } catch {
                print(error.localizedDescription)
            }
            var pivot = Pivot<Device, Legislator>(device, legislator)
            try pivot.save()
        }
    }
    return try device.makeJSON()
}

func sendAPNS() {}



drop.get("legislators", Int.self) { req, userID in
    guard let legislator = try Legislator.find(userID) else {
        throw Abort.notFound
    }
    return try legislator.makeJSON()
}



drop.get { req in
    return try drop.view.make("lastupdate", [
    	"message": drop.localization[req.lang, "welcome", "title"]
    ])
}

drop.post("legislator") { (req) in
    var legislator = try Legislator(node: req.json)
    print(legislator.fullName)
    do {
    try legislator.save()
    } catch {
        print(error.localizedDescription)
    }
    return try legislator.makeJSON()
}


drop.resource("posts", PostController())

drop.run()
