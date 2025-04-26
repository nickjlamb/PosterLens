import Foundation

struct ResearchContext: Codable {
    let futureDirections: [String]?
    let literatureContext: [Citation]?
    
    init(futureDirections: [String]? = nil, literatureContext: [Citation]? = nil) {
        self.futureDirections = futureDirections
        self.literatureContext = literatureContext
    }
}
