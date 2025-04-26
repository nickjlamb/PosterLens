import Foundation

extension String {
    // Remove commas from numeric strings (e.g., "2,025" -> "2025")
    func removingNumericCommas() -> String {
        // Check if the string contains only digits and commas
        let numericAndCommas = CharacterSet(charactersIn: "0123456789,")
        if self.unicodeScalars.allSatisfy({ numericAndCommas.contains($0) }) {
            return self.replacingOccurrences(of: ",", with: "")
        }
        return self
    }
}

extension Citation {
    // Format author names properly - this is a computed property
    var improvedAuthorFormatting: String {
        if authors.isEmpty {
            return "Unknown Author"
        } else if authors.count == 1 {
            let author = authors[0]
            if author.isEmpty || author.lowercased().contains("not specified") {
                return "Unknown Author"
            }
            return formatAuthorName(author)
        } else if authors.count == 2 {
            let author1 = authors[0].isEmpty || authors[0].lowercased().contains("not specified") ? "Unknown Author" : formatAuthorName(authors[0])
            let author2 = authors[1].isEmpty || authors[1].lowercased().contains("not specified") ? "Unknown Author" : formatAuthorName(authors[1])
            return "\(author1) & \(author2)"
        } else {
            let firstAuthor = authors[0].isEmpty || authors[0].lowercased().contains("not specified") ? "Unknown Author" : formatAuthorName(authors[0])
            return "\(firstAuthor) et al."
        }
    }
    
    // Helper to format author names properly
    private func formatAuthorName(_ author: String) -> String {
        // If the author name is already in "Last, First" format, return it
        if author.contains(",") {
            return author
        }
        
        // Split the name into parts
        let parts = author.split(separator: " ").map(String.init)
        
        // If we have at least 2 parts (first and last name)
        if parts.count >= 2 {
            let lastName = parts.last ?? ""
            let firstNameInitials = parts.dropLast().map { name in
                if !name.isEmpty {
                    return String(name.prefix(1)) + "."
                }
                return ""
            }.joined(separator: " ")
            
            return "\(lastName), \(firstNameInitials)"
        }
        
        // If we only have one part, return it as is
        return author
    }
    
    // Returns a formatted citation string in APA style with improved formatting
    var improvedFormattedCitation: String {
        let authorText = improvedAuthorFormatting
        
        // Format year without commas
        let yearText: String
        if let year = year {
            let yearString = String(year)
            yearText = " (\(yearString))"
        } else {
            yearText = ""
        }
        
        let titleText = ". \(title)"
        let journalText = journal != nil ? ". \(journal!)" : ""
        
        return "\(authorText)\(yearText)\(titleText)\(journalText)"
    }
}
