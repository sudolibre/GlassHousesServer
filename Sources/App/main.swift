import Vapor
import VaporPostgreSQL
import Fluent
import Foundation
import HTTP
import VaporAPNS
import Jobs

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
    drop.console.info("apns function executing...", newLine: true)
    if let privateKey = drop.config["APNS", "PrivateKey"]?.string,
        let publicKey = drop.config["APNS", "PublicKey"]?.string {
        let options = try Options(topic: "com.jonday.glasshouses", teamId: "L72L2B36E9", keyId: "QP7Q9VVUHK", rawPrivKey: privateKey, rawPubKey: publicKey)
        drop.console.info("options created...", newLine: true)
        let vaporAPNS = try VaporAPNS(options: options)
        let pushMessage = ApplePushMessage(topic: "com.jonday.glasshouses", priority: .immediately, payload: payload, sandbox: true)
        drop.console.info("about to send...", newLine: true)
        let result = vaporAPNS.send(pushMessage, to: token)
        drop.console.info("should have result here...", newLine: true)

          switch result {
          case .error(_,let deviceToken, let error):
            if case APNSError.unregistered = error {
                do {
                    if let device = try Device.query().filter("token", deviceToken).first() {
                        let pivots = try Pivot<Device, Legislator>.query().filter("device_id", device.id!)
                        try pivots.all().forEach({try $0.delete()})
                        try device.delete()
                    }
                } catch {
                    drop.console.info(error.localizedDescription, newLine: true)
                }
            }
          case .networkError(let error):
            drop.console.info(error.localizedDescription, newLine: true)
          case.success(_, _, let error):
            drop.console.info(error.localizedDescription, newLine: true)
        }
    }
}

func notifyConstituents() {
    drop.console.info("notify function executing...", newLine: true)

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

func asscoiateMentioned(_ legislators: [Legislator], with article: Article) {
    for legislator in legislators where article.description.localizedCaseInsensitiveContains(legislator.fullName) {
        var pivot = Pivot<Article, Legislator>(article, legislator)
        try? pivot.save()
    }
    
}

func updateRecentArticles(_ completion: () -> ()) throws {
    drop.console.info("update function executing...", newLine: true)
    
    var legislators: [Legislator] = []

    let key: String? = nil
    do {
        legislators = try Legislator.all()
    } catch {
        print(error)
    }
    
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
    
    if let key = drop.config["API", "BingKey"]?.string {
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
        drop.console.info("failed to retrieve API Key...", newLine: true)

        fatalError("Failed to retrieve news API key")
    }
    completion()
}

func refreshNews() throws {
    drop.console.info("refresh function executing...", newLine: true)
    do {
        try updateRecentArticles() {
            notifyConstituents()
        }
    } catch {
        print(error)
    }
}

func updateCommand() throws -> () {
    drop.console.info("update function executing...", newLine: true)
    try drop.startServers()
    drop.console.info("update: starting servers...", newLine: true)
    let prepare = drop.commands.first(where: {$0 is Prepare})
    try prepare?.run(arguments: [])
    drop.console.info("update: preparing databnase servers...", newLine: true)
    
    try refreshNews()
}

Jobs.add(interval: .days(1)) {
    try? updateCommand()
}

func saveCurrentTime() {
    drop.console.info("save time function executing...", newLine: true)
    let directory = drop.resourcesDir
    let time = Date()
    let timeInterval = String(time.timeIntervalSince1970)
    try? timeInterval.write(toFile: directory.appending("/lastUpdate"), atomically: true, encoding: .utf8)
}

func getLastUpdateTime() -> String {
    let directory = drop.resourcesDir
    if let timeIntervalString = try? String(contentsOfFile: directory.appending("/lastUpdate")),
        let timeInterval = Double(timeIntervalString) {
        let time = Date(timeIntervalSince1970: timeInterval)
        return time.description
    }
    return "unknown"
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

drop.get("update") { request in
    let updateTime = getLastUpdateTime()
    return "The server was last updated \(updateTime)!"
}

drop.get("legislators", Int.self) { req, userID in
    guard let legislator = try Legislator.find(userID) else {
        throw Abort.notFound
    }
    return try legislator.makeJSON()
}
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
