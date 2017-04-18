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
    if let privateKey = drop.config["APNS", "PrivateKey"]?.string,
        let publicKey = drop.config["APNS", "PublicKey"]?.string {
        let options = try Options(topic: "com.jonday.glasshouses", teamId: "L72L2B36E9", keyId: "QP7Q9VVUHK", rawPrivKey: privateKey, rawPubKey: publicKey)
        let vaporAPNS = try VaporAPNS(options: options)
        let pushMessage = ApplePushMessage(topic: "com.jonday.glasshouses", priority: .immediately, payload: payload, sandbox: true)
        drop.console.info("sending apns message to \(token)...", newLine: true)
        let result = vaporAPNS.send(pushMessage, to: token)

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
                    drop.console.info("Error sending to \(token): \(error.localizedDescription)", newLine: true)
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
            payload.extra = [
                "legislator": legislator.fullName,
                "url": article.url,
            ]
            if let json = try? article.makeJSON() {
                payload.extra["json"] = json
            }
            let devices = try! legislator.devices().all()
            for device in devices {
                try! sendAPNS(payload: payload, token: device.token)
            }
        }
    }
}

func asscoiateMentioned(_ legislators: [Legislator], with article: Article) {
    for legislator in legislators where article.description.localizedCaseInsensitiveContains(legislator.fullName) {
        guard let count = try? Pivot<Article, Legislator>.query().filter("article_id", article.id!).filter("legislator_id", legislator.id!).count(),
            count == 0 else {
                return
        }
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
                let articles = try Article.all()
                for article in articles {
                    let pivots = try Pivot<Article, Legislator>.query().filter("article_id", article.id!)
                    try pivots.all().forEach({try $0.delete()})
                    try article.delete()
                }
                
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
    drop.console.info("update: preparing database servers...", newLine: true)
    
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

drop.post("register") { req in
    guard let legislatorsJSON = req.json?["legislators"]?.pathIndexableArray,
        let legislators = try? legislatorsJSON.flatMap({try Legislator.fetchOrCreate(json: $0)}),
        !legislators.isEmpty else {
            throw Abort.badRequest
    }
    
    let responseNode: [String: JSON] = {
        var dictionary: [String: JSON] = [:]
        legislators.forEach { (legislator) in
            dictionary[legislator.fullName] = try? legislator.articles().all().makeJSON()
        }
        return dictionary
    }()
    
    if let device = try Device.fetchOrCreate(json: req.json) {
        try legislators.forEach{ (legislator) in
            guard let count = try? Pivot<Device, Legislator>.query().filter("device_id", device.id!).filter("legislator_id", legislator.id!).count(),
                count == 0 else {
                    return
            }
            var pivot = Pivot<Device, Legislator>(device, legislator)
            try pivot.save()
        }
    }
    
    return try JSON(node: responseNode)
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


drop.resource("posts", PostController())

drop.run()
