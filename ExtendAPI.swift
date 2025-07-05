import Foundation

extension ViewModel {
    func readBulkVCC(messageId: UUID,
                     accessToken: String,
                     sourceAccountId: String,
                     readCount: Int,
                     completion: @escaping ([ExtendVCC]) -> Void) {
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if let idx = self.messages.firstIndex(where: { $0.id == messageId }) {
                let currMessage = self.messages[idx].vccBuildMessage
            
                if currMessage == "This may take a while..." || currMessage == "Please wait a few seconds..." {
                    self.messages[idx].vccBuildMessage = "Fetching active VCC..."
                }
            }
        }
        
        getBulkVccIds(accessToken: accessToken, sourceAccountId: sourceAccountId, readCount: readCount) { ids in
            if ids.isEmpty {
                completion([])
                return
            } else {
                if let idx = self.messages.firstIndex(where: { $0.id == messageId }) {
                    DispatchQueue.main.async {
                        self.messages[idx].vccBuildMessage = "Found \(ids.count) active VCC, building..."
                    }
                }
                
                fetchAllVCCDetails(vccIDs: ids, accessToken: accessToken) { cards in
                    completion(cards)
                }
            }
        }
    }
    func createAndFetchBulkVCC(messageId: UUID,
                               shouldCreate: Bool,
                               accessToken: String,
                               sourceAccountId: String,
                               limit: Int,
                               reccurStatus: RecurenceFrequency,
                               genCount: Int,
                               email: String,
                               completion: @escaping ([ExtendVCC]) -> Void) {
        
        if !shouldCreate {
            readBulkVCC(messageId: messageId, accessToken: accessToken, sourceAccountId: sourceAccountId, readCount: genCount) { vcc in
                completion(vcc)
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if let idx = self.messages.firstIndex(where: { $0.id == messageId }) {
                    let currMessage = self.messages[idx].vccBuildMessage
                
                    if currMessage == "This may take a while..." || currMessage == "Please wait a few seconds..." {
                        self.messages[idx].vccBuildMessage = "Creating VCC..."
                    }
                }
            }
            
            createBulkVCC(messageId: messageId, accessToken: accessToken, sourceAccountId: sourceAccountId, limit: limit, reccurStatus: reccurStatus, genCount: genCount, email: email) { vIds in
                
                if vIds.isEmpty {
                    completion([])
                    return
                }
                
                if let idx = self.messages.firstIndex(where: { $0.id == messageId }) {
                    DispatchQueue.main.async {
                        self.messages[idx].vccBuildMessage = "Created \(vIds.count) VCC, reading..."
                    }
                }
                
                fetchAllVCCDetails(vccIDs: vIds, accessToken: accessToken) { vcc in
                    completion(vcc)
                }
            }
        }
    }
    func createBulkVCC(
        messageId: UUID,
        accessToken: String,
        sourceAccountId: String,
        limit: Int,
        reccurStatus: RecurenceFrequency,
        genCount: Int,
        email: String,
        accumulatedVccIds: [String] = [],
        completion: @escaping ([String]) -> Void
    ) {
        guard genCount > 0 else {
            completion(accumulatedVccIds)
            return
        }
        
        let currentBatchCount = min(genCount, 100)
        
        guard let url = URL(string: "https://api.paywithextend.com/creditcards/\(sourceAccountId)/bulkvirtualcardpush") else {
            completion(accumulatedVccIds)
            return
        }
        
        let boundary = "----WebKitFormBoundary\(randomBoundaryString(of: 16))"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        var csvText = """
        Card Type,en-US,Virtual Card User Email,Card Name,Credit Limit,Reset Period,"Reset Period Interval (Number of days, weeks, or months between resets)",Reset End Type,Reset Count,Reset Until Date (MM/DD/YYYY),Weekly Reset Day,Monthly Reset Day,Notes
        """
        csvText += "\n"
        
        var batchNames: [String] = []
        
        for i in 0..<currentBatchCount {
            let firstName = commonFirstNames.randomElement() ?? "Jack"
            let lastName  = commonLastNames.randomElement() ?? "Miller"
            let name      = "\(firstName)\(i)\(lastName)"
            batchNames.append(name)
            
            let weeklyResetDay = (reccurStatus == .week) ? nameOfYesterday() : ""
            let monthlyResetDay = (reccurStatus == .month) ? "\(dayIn29Days())" : ""
            let cardType = "Refill"
            
            let row = """
            \(cardType),en-US,\(email),\(name),\(limit),\(reccurStatus.rawValue),1,Does not end,,,\(weeklyResetDay),\(monthlyResetDay),
            """
            
            csvText += row + "\n"
        }
        
        guard let csvData = csvText.data(using: .utf8) else {
            completion(accumulatedVccIds)
            return
        }
        
        var body = Data()
        let x = accumulatedVccIds.count
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"virtual_c\(x).csv\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: text/csv\r\n\r\n".data(using: .utf8)!)
        body.append(csvData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/vnd.paywithextend.v2021-03-12+json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("\(String(data: body, encoding: .utf8)?.count ?? csvText.count)", forHTTPHeaderField: "Content-Length")
        request.setValue("same-site", forHTTPHeaderField: "Sec-Fetch-Site")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("cors", forHTTPHeaderField: "Sec-Fetch-Mode")
        request.setValue("https://app.paywithextend.com", forHTTPHeaderField: "Origin")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0.1 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
        request.setValue("https://app.paywithextend.com/", forHTTPHeaderField: "Referer")
        request.setValue("empty", forHTTPHeaderField: "Sec-Fetch-Dest")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0.1 Safari/605.1.15", forHTTPHeaderField: "X-Extend-Platform-Version")
        request.setValue("br_2F0trP1UmE59x1ZkNIAqsg", forHTTPHeaderField: "X-Extend-Brand")
        request.setValue("u=3, i", forHTTPHeaderField: "Priority")
        request.setValue("app.paywithextend.com", forHTTPHeaderField: "X-Extend-App-ID")
        request.setValue("web", forHTTPHeaderField: "X-Extend-Platform")
            
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error: \(error)")
                completion(accumulatedVccIds)
                return
            }
            
            if let idx = self.messages.firstIndex(where: { $0.id == messageId }) {
                DispatchQueue.main.async {
                    self.messages[idx].vccBuildMessage = "VCC batch created..."
                }
            }
            
            let dict = Dictionary(uniqueKeysWithValues: batchNames.map { ($0, nil as String?) })
            
            self.recursiveCollectNewCards(totalToGen: genCount + accumulatedVccIds.count, previousTotal: accumulatedVccIds.count, messageId: messageId, accessToken: accessToken, sourceAccountId: sourceAccountId, nameToIdMap: dict, iteration: 0) { vccIds in
                let collectTotal = vccIds + accumulatedVccIds
                
                if collectTotal.count >= (genCount - 15) {
                    completion(collectTotal)
                } else {
                    self.createBulkVCC(messageId: messageId, accessToken: accessToken, sourceAccountId: sourceAccountId, limit: limit, reccurStatus: reccurStatus, genCount: genCount - collectTotal.count, email: email, accumulatedVccIds: collectTotal, completion: completion)
                }
            }
        }
        
        task.resume()
    }
    func recursiveCollectNewCards (
        totalToGen: Int,
        previousTotal: Int,
        messageId: UUID,
        accessToken: String,
        sourceAccountId: String,
        nameToIdMap: [String: String?],
        iteration: Int,
        completion: @escaping ([String]) -> Void
    ) {
        var nameToIds = nameToIdMap
        
        let urlString = "https://api.paywithextend.com/virtualcards?count=\(50)&creditCardId=\(sourceAccountId)&issued=true&page=\(0)&sortDirection=ASC&sortField=activeClosedUpdatedAt&statuses=ACTIVE"
        
        guard let url = URL(string: urlString) else {
            completion(nameToIds.compactMap({ $0.value }))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/vnd.paywithextend.v2021-03-12+json", forHTTPHeaderField: "Accept")
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.addValue("same-site", forHTTPHeaderField: "Sec-Fetch-Site")
        request.addValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.addValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
        request.addValue("cors", forHTTPHeaderField: "Sec-Fetch-Mode")
        request.addValue("https://app.paywithextend.com", forHTTPHeaderField: "Origin")
        request.addValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0.1 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
        request.addValue("https://app.paywithextend.com/", forHTTPHeaderField: "Referer")
        request.addValue("keep-alive", forHTTPHeaderField: "Connection")
        request.addValue("empty", forHTTPHeaderField: "Sec-Fetch-Dest")
        request.addValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0.1 Safari/605.1.15", forHTTPHeaderField: "X-Extend-Platform-Version")
        request.addValue("br_2F0trP1UmE59x1ZkNIAqsg", forHTTPHeaderField: "X-Extend-Brand")
        request.addValue("u=3, i", forHTTPHeaderField: "Priority")
        request.addValue("app.paywithextend.com", forHTTPHeaderField: "X-Extend-App-ID")
        request.addValue("web", forHTTPHeaderField: "X-Extend-Platform")

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                completion(nameToIds.compactMap({ $0.value }))
                return
            }
            
            do {
                if let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let virtualCards = jsonObject["virtualCards"] as? [[String: Any]] {
                    
                    for cardDict in virtualCards {
                        if let id = cardDict["id"] as? String, let displayName = cardDict["displayName"] as? String {
                            if nameToIds.contains(where: { $0.key == displayName }) {
                                nameToIds[displayName] = id
                            }
                        }
                    }
                    
                    let vccIds = nameToIds.compactMap({ $0.value })
                    
                    if (!vccIds.isEmpty && (vccIds.count + 5) >= nameToIds.count) || (vccIds.isEmpty && iteration > 4) {
                        completion(vccIds)
                    } else {
                        let total = previousTotal + vccIds.count
                        if let idx = self.messages.firstIndex(where: { $0.id == messageId }) {
                            let eta = max(5, Int(CGFloat(totalToGen - total) * 0.9))
                            DispatchQueue.main.async {
                                self.messages[idx].vccBuildMessage = "Collected \(total) VCC. ETA \(eta) seconds"
                            }
                        } else {
                            completion([])
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
                            self.recursiveCollectNewCards(totalToGen: totalToGen, previousTotal: previousTotal, messageId: messageId, accessToken: accessToken, sourceAccountId: sourceAccountId, nameToIdMap: nameToIds, iteration: iteration + 1, completion: completion)
                        }
                    }
                } else {
                    completion(nameToIds.compactMap({ $0.value }))
                }
            } catch {
                completion(nameToIds.compactMap({ $0.value }))
            }
        }.resume()
    }
}

func getAccounts(accessToken: String, completion: @escaping ([ExtendAccounts]) -> Void) {
    let urlString = "https://api.paywithextend.com/creditcards?count=10&page=0&sortField=userPendingActiveFirst&statuses=ACTIVE&type=SOURCE"
    guard let url = URL(string: urlString) else {
        completion([])
        return
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.addValue("application/vnd.paywithextend.v2021-03-12+json", forHTTPHeaderField: "Accept")
    request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    request.addValue("same-site", forHTTPHeaderField: "Sec-Fetch-Site")
    request.addValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
    request.addValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
    request.addValue("cors", forHTTPHeaderField: "Sec-Fetch-Mode")
    request.addValue("https://app.paywithextend.com", forHTTPHeaderField: "Origin")
    request.addValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0.1 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
    request.addValue("https://app.paywithextend.com/", forHTTPHeaderField: "Referer")
    request.addValue("empty", forHTTPHeaderField: "Sec-Fetch-Dest")
    request.addValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0.1 Safari/605.1.15", forHTTPHeaderField: "X-Extend-Platform-Version")
    request.addValue("br_2F0trP1UmE59x1ZkNIAqsg", forHTTPHeaderField: "X-Extend-Brand")
    request.addValue("u=3, i", forHTTPHeaderField: "Priority")
    request.addValue("app.paywithextend.com", forHTTPHeaderField: "X-Extend-App-ID")
    request.addValue("web", forHTTPHeaderField: "X-Extend-Platform")
    
    URLSession.shared.dataTask(with: request) { data, response, error in
        guard let data = data, error == nil else {
            completion([])
            return
        }
        
        do {
            let decoder = JSONDecoder()
            let response = try decoder.decode(CreditCardsResponse.self, from: data)
            let accounts = response.creditCards.map { card in
                ExtendAccounts(
                    id: card.id,
                    displayName: card.displayName,
                    companyName: card.companyName,
                    photo: card.cardImage.urls.small,
                    email: card.user.email
                )
            }
            completion(accounts)
        } catch {
            print("Failed to decode JSON: \(error)")
            completion([])
        }
    }.resume()
}

func fetchAllVCCDetails(vccIDs: [String],
                        accessToken: String,
                        completion: @escaping ([ExtendVCC]) -> Void) {
    let queue = DispatchQueue(label: "com.companyname.vccFetchQueue", attributes: .concurrent)
    let semaphore = DispatchSemaphore(value: 20)
    let dispatchGroup = DispatchGroup()
    var results = Array<ExtendVCC?>(repeating: nil, count: vccIDs.count)
    
    queue.async {
        for (index, vccID) in vccIDs.enumerated() {
            semaphore.wait()
            dispatchGroup.enter()
            
            queue.async {
                getSingleVCC(vccID: vccID, accessToken: accessToken) { detail in
                    defer {
                        semaphore.signal()
                        dispatchGroup.leave()
                    }
                    if let detail = detail {
                        results[index] = detail
                    }
                }
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            completion(results.compactMap { $0 })
        }
    }
}

func getSingleVCC(vccID: String, accessToken: String, completion: @escaping (ExtendVCC?) -> Void) {
    let urlString = "https://v.paywithextend.com/virtualcards/\(vccID)"
    guard let url = URL(string: urlString) else {
        completion(nil)
        return
    }

    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.addValue("application/vnd.paywithextend.v2021-03-12+json", forHTTPHeaderField: "Accept")
    request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    request.addValue("same-site", forHTTPHeaderField: "Sec-Fetch-Site")
    request.addValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
    request.addValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
    request.addValue("cors", forHTTPHeaderField: "Sec-Fetch-Mode")
    request.addValue("https://app.paywithextend.com", forHTTPHeaderField: "Origin")
    request.addValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0.1 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
    request.addValue("https://app.paywithextend.com/", forHTTPHeaderField: "Referer")
    request.addValue("keep-alive", forHTTPHeaderField: "Connection")
    request.addValue("empty", forHTTPHeaderField: "Sec-Fetch-Dest")
    request.addValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0.1 Safari/605.1.15", forHTTPHeaderField: "X-Extend-Platform-Version")
    request.addValue("br_2F0trP1UmE59x1ZkNIAqsg", forHTTPHeaderField: "X-Extend-Brand")
    request.addValue("u=3, i", forHTTPHeaderField: "Priority")
    request.addValue("app.paywithextend.com", forHTTPHeaderField: "X-Extend-App-ID")
    request.addValue("web", forHTTPHeaderField: "X-Extend-Platform")

    URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            print("Error during URLSession data task: \(error.localizedDescription)")
            completion(nil)
            return
        }

        guard let data = data else {
            print("Error: Data is nil.")
            completion(nil)
            return
        }

        do {
            let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            guard let virtualCard = json?["virtualCard"] as? [String: Any] else {
                completion(nil)
                return
            }

            let id = virtualCard["id"] as? String ?? ""
            let ccNum = virtualCard["vcn"] as? String ?? ""
            let securityCode = virtualCard["securityCode"] as? String ?? ""
            let expires = virtualCard["expires"] as? String ?? ""

            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            guard let expiryDate = dateFormatter.date(from: expires) else {
                completion(nil)
                return
            }

            var calendar = Calendar.current
            calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
            let ccMonth = String(format: "%02d", calendar.component(.month, from: expiryDate))
            let ccYear = String(calendar.component(.year, from: expiryDate)).suffix(2)

            let vcc = ExtendVCC(id: id, ccNum: ccNum, ccMonth: ccMonth, ccYear: String(ccYear), cvv: securityCode)
            completion(vcc)
        } catch {
            completion(nil)
        }
    }.resume()
}

func getBulkVccIds(accessToken: String,
                   sourceAccountId: String,
                   readCount: Int,
                   page: Int = 0,
                   accumulatedIds: [String] = [],
                   completion: @escaping ([String]) -> Void) {

    let maxCountPerRequest = 50
    let count = min(readCount - accumulatedIds.count, maxCountPerRequest)
    if count <= 0 {
        completion(accumulatedIds)
        return
    }

    let urlString = "https://api.paywithextend.com/virtualcards?count=\(count)&creditCardId=\(sourceAccountId)&issued=true&page=\(page)&sortDirection=ASC&sortField=activeClosedUpdatedAt&statuses=ACTIVE"
    
    guard let url = URL(string: urlString) else {
        completion(accumulatedIds)
        return
    }

    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.addValue("application/vnd.paywithextend.v2021-03-12+json", forHTTPHeaderField: "Accept")
    request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    request.addValue("same-site", forHTTPHeaderField: "Sec-Fetch-Site")
    request.addValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
    request.addValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
    request.addValue("cors", forHTTPHeaderField: "Sec-Fetch-Mode")
    request.addValue("https://app.paywithextend.com", forHTTPHeaderField: "Origin")
    request.addValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0.1 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
    request.addValue("https://app.paywithextend.com/", forHTTPHeaderField: "Referer")
    request.addValue("keep-alive", forHTTPHeaderField: "Connection")
    request.addValue("empty", forHTTPHeaderField: "Sec-Fetch-Dest")
    request.addValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0.1 Safari/605.1.15", forHTTPHeaderField: "X-Extend-Platform-Version")
    request.addValue("br_2F0trP1UmE59x1ZkNIAqsg", forHTTPHeaderField: "X-Extend-Brand")
    request.addValue("u=3, i", forHTTPHeaderField: "Priority")
    request.addValue("app.paywithextend.com", forHTTPHeaderField: "X-Extend-App-ID")
    request.addValue("web", forHTTPHeaderField: "X-Extend-Platform")

    URLSession.shared.dataTask(with: request) { data, response, error in
        guard let data = data, error == nil else {
            completion(accumulatedIds)
            return
        }
        
        do {
            if let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let virtualCards = jsonObject["virtualCards"] as? [[String: Any]],
               let pagination = jsonObject["pagination"] as? [String: Int] {
                
                let newIds = virtualCards.compactMap { $0["id"] as? String }
                var allIds = accumulatedIds + newIds
                let currentPage = pagination["page"] ?? 0
                let numberOfPages = pagination["numberOfPages"] ?? 0
                
                let hasMorePages = currentPage < (numberOfPages - 1)
                
                if hasMorePages && allIds.count < readCount {
                    getBulkVccIds(accessToken: accessToken, sourceAccountId: sourceAccountId, readCount: readCount, page: currentPage + 1, accumulatedIds: allIds, completion: completion)
                } else {
                    allIds = Array(allIds.prefix(readCount))
                    completion(allIds)
                }
            } else {
                completion(accumulatedIds)
            }
        } catch {
            completion(accumulatedIds)
        }
    }.resume()
}

func nameOfYesterday() -> String {
    let calendar = Calendar.current
    
    guard let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()) else {
        return "Friday"
    }
    
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "EEEE"
    let dayName = dateFormatter.string(from: yesterday)
    
    return dayName
}

func dayIn29Days() -> Int {
    let currentDay = Calendar.current.component(.day, from: Date())
    
    guard currentDay >= 1 && currentDay <= 30 else {
        return 1
    }

    let futureDay = (currentDay + 29) % 30

    return futureDay == 0 ? 30 : futureDay
}

func randomBoundaryString(of length: Int = 16) -> String {
    let allowedChars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    return String((0..<length).compactMap { _ in allowedChars.randomElement() })
}
