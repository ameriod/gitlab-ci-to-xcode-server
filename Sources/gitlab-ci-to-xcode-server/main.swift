import ArgumentParser
import Foundation

struct SetXCodeIntegrationNumberAndStart: ParsableCommand {

    @Option(help: "The base URL of the Xcode Server")
    var url: String

    @Option(help: "The username od the Xcode Server user")
    var username: String

    @Option(help: "The password of the Xcode Server user")
    var password: String

    @Option(help: "The integration number to set on the bots on the XCode Server")
    var integrationNumber: String

    @Option(help: "The regex to filter the bots out by their names")
    var filter: String?

    func run() throws {
        let decoder = JSONDecoder()

        // Ignore the SSL/TLS certs
        let session = URLSession(configuration: URLSessionConfiguration.default, delegate: SessionDelegate(), delegateQueue: .none)

        var regex: NSRegularExpression?
        if let filter = filter {
            regex = NSRegularExpression(filter)
        }

        // GET all of the bots
        let botsRequest = URLRequest.create(
            url: "https://\(url)/api/bots",
            username: username,
            password: password
        )
        let bots = try! decoder.decode(BotsResponse.self, from: session.synchronousDataTask(with: botsRequest)).results

        // PATCH to update each bot's integration number
        bots.forEach { bot in
            if regex?.matches(bot.name) ?? true {

            var updateRequest = URLRequest.create(
                url: "https://\(url)/api/bots/\(bot._id)",
                username: username,
                password: password
            )
            updateRequest.httpMethod = "PATCH"
            updateRequest.httpBody = try! JSONSerialization.data(withJSONObject: ["integration_counter": integrationNumber])
            let _ = session.synchronousDataTask(with: updateRequest)
            }
        }

        // POST to start the new integration
        bots.forEach { bot in
            if regex?.matches(bot.name) ?? true {
                var startRequest = URLRequest.create(
                    url: "https://\(url)/api/bots/\(bot._id)/integrations",
                    username: username,
                    password: password
                )
                startRequest.httpMethod = "POST"
                startRequest.httpBody = try! JSONSerialization.data(withJSONObject: ["clean": true])
                let _ = session.synchronousDataTask(with: startRequest)
            }
        }
    }
}

SetXCodeIntegrationNumberAndStart.main()

private class SessionDelegate: NSObject, URLSessionDelegate {

    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(Foundation.URLSession.AuthChallengeDisposition.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!))
    }
}
private extension URLRequest {

    static func create(url: String, username: String, password: String) -> URLRequest {
        var request = URLRequest(url: URL(string: url)!)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let loginString = "\(username):\(password)"
        let loginData = loginString.data(using: String.Encoding.utf8)!
        let base64LoginString = loginData.base64EncodedString()
        request.setValue("Basic \(base64LoginString)", forHTTPHeaderField: "Authorization")
        return request
    }
}

private extension URLSession {

    func synchronousDataTask(with request: URLRequest) -> Data {
        var data: Data?
        var error: Error?
        let semaphore = DispatchSemaphore(value: 0)

        let dataTask = self.dataTask(with: request) {
            data = $0
            error = $2

            if let error = error {
                print("URL: \(String(describing: request.url)) ERROR: \(error)")
            }

            semaphore.signal()
        }
        dataTask.resume()

        _ = semaphore.wait(timeout: .distantFuture)

        return data!
    }
}

private extension Data {
    var toJSON: String {
        String(data: self, encoding: .utf8)!
    }
}

struct BotsResponse: Codable {
    var results: [Bot]
}

struct Bot: Codable {
    var _id: String
    var name: String
}

private extension NSRegularExpression {
    convenience init(_ pattern: String) {
        do {
            try self.init(pattern: pattern)
        } catch {
            preconditionFailure("Illegal regular expression: \(pattern).")
        }
    }

    func matches(_ string: String) -> Bool {
        let range = NSRange(location: 0, length: string.utf16.count)
        return firstMatch(in: string, options: [], range: range) != nil
    }
}
