import Vapor
import VaporPostgreSQL
import Fluent
import Foundation
import HTTP
import VaporAPNS

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

func sendAPNS() throws {
    let options = try! Options(topic: "com.jonday.glasshouses", teamId: "L72L2B36E9", keyId: "QP7Q9VVUHK", keyPath: "/Users/noj/Code/GlassHouses/APNsAuthKey_QP7Q9VVUHK.p8", port: .p443, debugLogging: true)
    let vaporAPNS = try VaporAPNS(options: options)
    let payload = Payload(title: "JON APNS", body: "It's working if you see this!")
    let pushMessage = ApplePushMessage(topic: "com.jonday.glasshouses", priority: .immediately, payload: payload, sandbox: true)
    let result = vaporAPNS.send(pushMessage, to: "318EC25079DFD9D1B1D61846826B726C6849E8E648B0B1742E5FAB69BDAC45DA")
    print(result)
}


func checkNews() throws {
    //TODO: remove hardcoded legislator
    let legislator = "Elena Parent"
    let key: String? = nil
    
    func getNewsWithKey(_ key: String) throws -> Response {
        let queryParameters = [
            "q": legislator,
            "count": "10",
            "offset": "0",
            "mkt": "en-us",
            "safeSearch": "Moderate",
            "freshness": "Month"
        ]
        let uri = "https://api.cognitive.microsoft.com/bing/v5.0/news/search"
        let headers = [HeaderKey("Ocp-Apim-Subscription-Key"): key]
        return try drop.client.get(uri, headers: headers, query: queryParameters)
    }
    
   if let config = drop.config["API"]?.object,
        let key = config["BingKey"]?.string {
        do {
            let response = try getNewsWithKey(key)
            if let results = response.json?["value"]?.pathIndexableArray {
                for result in results {
                    var article = try Article(node: result.node)
                    do {
                        try article.save()
                    } catch {
                        print(error.localizedDescription)
                    }
                }
            }
        } catch {
            print(error.localizedDescription)
        }
    } else {
        fatalError("Failed to retrieve news API key")
    }
}

//drop.get("forceAPNS") { (req) in
//    
//}

//drop.get("articles") { (req) in
//    do{
//        try sendAPNS()
//    } catch {
//        print(error.localizedDescription)
//    }
//    //                                                                      a;lskjf;alskjf;asldjfk;alsfj;asldfjk;slkfja;sldfja;sdfja;sdf
//    let legislators = try Legislator.all().makeNode()
//    let legislatorsDictionary = ["legislators": legislators]
//    try checkNews()
//    return try JSON(node: node)
//}

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
