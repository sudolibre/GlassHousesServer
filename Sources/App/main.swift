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
drop.preparations.append(Pivot<Article, Legislator>.self)


do {
try drop.addProvider(VaporPostgreSQL.Provider.self)
} catch {
    assertionFailure("Error adding provider \(error)")
}

func sendAPNS(payload: Payload, token: String) throws {
    let options = try! Options(topic: "com.jonday.glasshouses", teamId: "L72L2B36E9", keyId: "QP7Q9VVUHK", keyPath: "/Users/noj/Code/GlassHouses/APNsAuthKey_QP7Q9VVUHK.p8", port: .p443, debugLogging: true)
    let vaporAPNS = try VaporAPNS(options: options)
    let pushMessage = ApplePushMessage(topic: "com.jonday.glasshouses", priority: .immediately, payload: payload, sandbox: true)
    let result = vaporAPNS.send(pushMessage, to: token)
    print(result)
}

func notifyConstituents() {
    let articles = try! Article.all()
    
    for article in articles {
        guard let legislators = try? article.legislators().all() else {  continue }
        
        for legislator in legislators {
            let payload = Payload(title: "News: \(legislator.fullName)", body: article.description)
            let devices = try! legislator.devices().all()
            
            for device in devices {
                try! sendAPNS(payload: payload, token: device.token)
            }
        }
    }
}


func refreshNews() throws {
    try updateRecentArticles() {
            notifyConstituents()
    }
}

func updateRecentArticles(_ completion: () -> ()) throws {
    let key: String? = nil
    let legislators = try Legislator.all()
    
    let legislatorQuery = legislators.reduce("") { (result, legislator) -> String in
        result + "\"\(legislator.fullName)\" OR "
    }
    
    func getNewsWithKey(_ key: String) throws -> Response {
        let queryParameters = [
            "q": legislatorQuery,
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
                try Article.all().forEach({try $0.delete()})
                for result in results {
                    do {
                        if let article = try Article.fetchOrCreate(json: result) {
                        asscoiateMentioned(legislators, with: article)
                        }
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
    completion()
}

func asscoiateMentioned(_ legislators: [Legislator], with article: Article) {
    for legislator in legislators where article.description.localizedCaseInsensitiveContains(legislator.fullName) {
        var pivot = Pivot<Article, Legislator>(article, legislator)
        try? pivot.save()
    }
    
}


drop.get("forceAPNS") { (req) in
    do {
        try refreshNews()
    } catch {
        print(error.localizedDescription)
    }
    return "forcing APNS"
}


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
    guard let device = try Device.fetchOrCreate(json: req.json),
        let legislatorsJSON = req.json?["legislators"]?.pathIndexableArray else {
            throw Abort.badRequest
    }
    let legislators = try legislatorsJSON.flatMap({try Legislator.fetchOrCreate(json: $0)})
    
    guard !legislators.isEmpty else {
        throw Abort.badRequest
    }
    
    try legislators.forEach{ (legislator) in
        var pivot = Pivot<Device, Legislator>(device, legislator)
        try pivot.save()
    }
    
    return try device.makeJSON()
}

drop.get { req in
    return try drop.view.make("lastupdate", [
        "message": drop.localization[req.lang, "welcome", "title"]
        ])
}

//drop.get("legislators", Int.self) { req, userID in
//    guard let legislator = try Legislator.find(userID) else {
//        throw Abort.notFound
//    }
//    return try legislator.makeJSON()
//}
//
//drop.post("legislator") { (req) in
//    var legislator = try Legislator(node: req.json)
//    print(legislator.fullName)
//    do {
//    try legislator.save()
//    } catch {
//        print(error.localizedDescription)
//    }
//    return try legislator.makeJSON()
//}


drop.resource("posts", PostController())

drop.run()
