import Foundation

struct ResearchContext: Codable {
    var futureDirections: [String]?
    var literatureContext: [Citation]?
    
    init(futureDirections: [String]? = nil, literatureContext: [Citation]? = nil) {
        self.futureDirections = futureDirections
        self.literatureContext = literatureContext
    }
}
