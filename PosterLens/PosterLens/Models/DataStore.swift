import Foundation
import Combine
import UIKit

// PERFORMANCE: @MainActor ensures all @Published property updates happen on main thread
@MainActor
class DataStore: ObservableObject {
    @Published var savedScans: [PosterScan] = []
    @Published var conversations: [Conversation] = []
    
    private let saveKey = "savedPosterScans"
    private let conversationsKey = "savedConversations"
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadSavedScans()
        loadConversations()
        
        // Set up automatic saving when savedScans changes
        $savedScans
            .debounce(for: 0.5, scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.saveScans()
            }
            .store(in: &cancellables)
            
        // Set up automatic saving when conversations change
        $conversations
            .debounce(for: 0.5, scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.saveConversations()
            }
            .store(in: &cancellables)
    }
    
    func saveScan(_ scan: PosterScan) {
        // Check if scan already exists (by ID)
        if let index = savedScans.firstIndex(where: { $0.id == scan.id }) {
            savedScans[index] = scan
        } else {
            savedScans.append(scan)
        }
        
        // Force a UI update by modifying the array
        objectWillChange.send()
    }
    
    func deleteScan(at offsets: IndexSet) {
        savedScans.remove(atOffsets: offsets)
    }
    
    func deleteScan(withID id: UUID) {
        if let index = savedScans.firstIndex(where: { $0.id == id }) {
            savedScans.remove(at: index)
        }
    }
    
    // Delete multiple scans by their IDs
    func deleteScans(withIDs ids: [UUID]) {
        for id in ids {
            deleteScan(withID: id)
        }
    }
    
    func getScan(withID id: UUID) -> PosterScan? {
        return savedScans.first(where: { $0.id == id })
    }
    
    // nonisolated allows this to be called from background queues
    nonisolated private func getScansFileURL() -> URL {
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDirectory.appendingPathComponent("PosterLensScans.json")
    }
    
    // PERFORMANCE: Save scans to file on background queue
    private func saveScans() {
        let scansToSave = savedScans  // Copy to avoid capturing self

        // PERFORMANCE OPTIMIZATION: Move file I/O to background queue
        DispatchQueue.global(qos: .utility).async {
            do {
                let encoder = JSONEncoder()
                let data = try encoder.encode(scansToSave)

                // Save to file instead of UserDefaults to avoid size limit
                try data.write(to: self.getScansFileURL())

                // Store a flag in UserDefaults to indicate data has been migrated
                UserDefaults.standard.set(true, forKey: "scansSavedToFile")

                // Remove large data from UserDefaults if it exists
                if UserDefaults.standard.object(forKey: self.saveKey) != nil {
                    UserDefaults.standard.removeObject(forKey: self.saveKey)
                    print("Removed large scan data from UserDefaults")
                }
            } catch {
                print("Failed to save scans: \(error.localizedDescription)")
            }
        }
    }
    
    // PERFORMANCE: Load scans from file on background queue
    private func loadSavedScans() {
        let fileURL = getScansFileURL()

        // PERFORMANCE OPTIMIZATION: Move file I/O to background queue
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let fileManager = FileManager.default  // Create inside closure to satisfy Sendable

            // First, try to load from file
            if fileManager.fileExists(atPath: fileURL.path) {
                do {
                    let data = try Data(contentsOf: fileURL)
                    let decoder = JSONDecoder()
                    let loadedScans = try decoder.decode([PosterScan].self, from: data)

                    // Update on main thread
                    DispatchQueue.main.async {
                        self.savedScans = loadedScans
                        print("Successfully loaded scans from file")
                    }
                    return
                } catch {
                    print("Failed to load saved scans from file: \(error.localizedDescription)")
                }
            }

            // If file doesn't exist or loading failed, try to load from UserDefaults (migration path)
            if let data = UserDefaults.standard.data(forKey: self.saveKey) {
                do {
                    let decoder = JSONDecoder()
                    let loadedScans = try decoder.decode([PosterScan].self, from: data)

                    // Update on main thread
                    DispatchQueue.main.async {
                        self.savedScans = loadedScans
                        print("Successfully loaded scans from UserDefaults, will migrate to file")

                        // Migrate to file storage
                        self.saveScans()
                    }
                } catch {
                    print("Failed to load saved scans from UserDefaults: \(error.localizedDescription)")

                    // If loading fails, reset the saved data
                    UserDefaults.standard.removeObject(forKey: self.saveKey)
                }
            }
        }
    }
    
    // Export all scans as a JSON file
    func exportScans() -> URL? {
        return exportScansAsJSON(savedScans)
    }
    
    // Export specific scans by their IDs
    func exportScans(withIDs ids: [UUID]) -> URL? {
        let scansToExport = savedScans.filter { scan in
            ids.contains(scan.id)
        }
        return exportScansAsJSON(scansToExport)
    }
    
    // Export all scans as PDF files
    func exportScansAsPDF() -> [URL]? {
        return exportScansAsPDF(savedScans)
    }
    
    // Export specific scans as PDF files by their IDs
    func exportScansAsPDF(withIDs ids: [UUID]) -> [URL]? {
        let scansToExport = savedScans.filter { scan in
            ids.contains(scan.id)
        }
        return exportScansAsPDF(scansToExport)
    }
    
    // Helper method to export an array of scans as JSON
    private func exportScansAsJSON(_ scans: [PosterScan]) -> URL? {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(scans)
            
            let fileManager = FileManager.default
            let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            let fileURL = documentsDirectory.appendingPathComponent("PosterLens_Scans.json")
            
            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("Failed to export scans as JSON: \(error.localizedDescription)")
            return nil
        }
    }
    
    // Helper method to export an array of scans as PDF files
    private func exportScansAsPDF(_ scans: [PosterScan]) -> [URL]? {
        var pdfURLs: [URL] = []
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        for scan in scans {
            // Generate PDF data
            if let pdfData = PDFExportService.generatePDF(from: scan) {
                // Create a sanitized filename from the title
                let sanitizedTitle = scan.title.replacingOccurrences(of: "[^a-zA-Z0-9]", with: "_", options: .regularExpression)
                let filename = "PosterLens_\(sanitizedTitle).pdf"
                let fileURL = documentsDirectory.appendingPathComponent(filename)
                
                do {
                    try pdfData.write(to: fileURL)
                    pdfURLs.append(fileURL)
                } catch {
                    print("Failed to write PDF file: \(error.localizedDescription)")
                }
            }
        }
        
        return pdfURLs.isEmpty ? nil : pdfURLs
    }
    
    // Import scans from a JSON file
    func importScans(from url: URL) -> Bool {
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let importedScans = try decoder.decode([PosterScan].self, from: data)
            
            // Merge with existing scans, avoiding duplicates
            for scan in importedScans {
                if !savedScans.contains(where: { $0.id == scan.id }) {
                    savedScans.append(scan)
                }
            }
            
            return true
        } catch {
            print("Failed to import scans: \(error.localizedDescription)")
            return false
        }
    }
    
    // Clear all saved data (scans and conversations)
    func clearAllScans() {
        // Clear scans
        savedScans.removeAll()
        UserDefaults.standard.removeObject(forKey: saveKey)
        UserDefaults.standard.removeObject(forKey: "scansSavedToFile")
        
        // Clear conversations
        conversations.removeAll()
        UserDefaults.standard.removeObject(forKey: conversationsKey)
        UserDefaults.standard.removeObject(forKey: "conversationsSavedToFile")
        
        // Remove the saved files
        do {
            let fileManager = FileManager.default
            
            // Remove scans file
            let scansFileURL = getScansFileURL()
            if fileManager.fileExists(atPath: scansFileURL.path) {
                try fileManager.removeItem(at: scansFileURL)
                print("Removed saved scans file")
            }
            
            // Remove conversations file
            let conversationsFileURL = getConversationsFileURL()
            if fileManager.fileExists(atPath: conversationsFileURL.path) {
                try fileManager.removeItem(at: conversationsFileURL)
                print("Removed saved conversations file")
            }
        } catch {
            print("Error deleting saved files: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Conversation Management
    
    /// Get the conversation for a specific poster, or create a new one if none exists
    func getOrCreateConversation(for posterId: UUID) -> Conversation {
        if let existingConversation = conversations.first(where: { $0.posterId == posterId }) {
            return existingConversation
        } else {
            let newConversation = Conversation(posterId: posterId)
            conversations.append(newConversation)
            return newConversation
        }
    }
    
    /// Add a message to a specific conversation
    func addMessage(_ message: ChatMessage, to conversationId: UUID) {
        print("🔄 DataStore.addMessage called - message: \(message.sender), conversation ID: \(conversationId)")
        
        if let index = conversations.firstIndex(where: { $0.id == conversationId }) {
            print("✅ Found conversation at index \(index), adding message")
            conversations[index].addMessage(message)
            
            // Explicitly trigger objectWillChange to ensure UI updates
            objectWillChange.send()
            print("📣 Sent objectWillChange notification")
        } else {
            print("❌ No matching conversation found for ID: \(conversationId)")
        }
    }
    
    /// Delete a conversation
    func deleteConversation(with id: UUID) {
        conversations.removeAll(where: { $0.id == id })
    }
    
    /// Delete all conversations for a specific poster
    func deleteConversations(for posterId: UUID) {
        conversations.removeAll(where: { $0.posterId == posterId })
    }
    
    /// Save conversations to UserDefaults
    // nonisolated allows this to be called from background queues
    nonisolated private func getConversationsFileURL() -> URL {
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDirectory.appendingPathComponent("PosterLensConversations.json")
    }
    
    // PERFORMANCE: Save conversations to file on background queue
    private func saveConversations() {
        let conversationsToSave = conversations  // Copy to avoid capturing self

        // PERFORMANCE OPTIMIZATION: Move file I/O to background queue
        DispatchQueue.global(qos: .utility).async {
            do {
                let encoder = JSONEncoder()
                let data = try encoder.encode(conversationsToSave)

                // Save to file instead of UserDefaults to avoid size limit
                try data.write(to: self.getConversationsFileURL())

                // Store a flag in UserDefaults to indicate data has been migrated
                UserDefaults.standard.set(true, forKey: "conversationsSavedToFile")

                // Remove large data from UserDefaults if it exists
                if UserDefaults.standard.object(forKey: self.conversationsKey) != nil {
                    UserDefaults.standard.removeObject(forKey: self.conversationsKey)
                    print("Removed large conversation data from UserDefaults")
                }
            } catch {
                print("Failed to save conversations: \(error.localizedDescription)")
            }
        }
    }
    
    /// Load conversations from file or UserDefaults - PERFORMANCE: Runs on background queue
    private func loadConversations() {
        let fileURL = getConversationsFileURL()

        // PERFORMANCE OPTIMIZATION: Move file I/O to background queue
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let fileManager = FileManager.default  // Create inside closure to satisfy Sendable

            // First, try to load from file
            if fileManager.fileExists(atPath: fileURL.path) {
                do {
                    let data = try Data(contentsOf: fileURL)
                    let decoder = JSONDecoder()
                    let loadedConversations = try decoder.decode([Conversation].self, from: data)

                    // Update on main thread
                    DispatchQueue.main.async {
                        self.conversations = loadedConversations
                        print("Successfully loaded conversations from file")
                    }
                    return
                } catch {
                    print("Failed to load conversations from file: \(error.localizedDescription)")
                }
            }

            // If file doesn't exist or loading failed, try to load from UserDefaults (migration path)
            if let data = UserDefaults.standard.data(forKey: self.conversationsKey) {
                do {
                    let decoder = JSONDecoder()
                    let loadedConversations = try decoder.decode([Conversation].self, from: data)

                    // Update on main thread
                    DispatchQueue.main.async {
                        self.conversations = loadedConversations
                        print("Successfully loaded conversations from UserDefaults, will migrate to file")

                        // Migrate to file storage
                        self.saveConversations()
                    }
                } catch {
                    print("Failed to load conversations from UserDefaults: \(error.localizedDescription)")

                    // If loading fails, reset the saved data
                    UserDefaults.standard.removeObject(forKey: self.conversationsKey)
                }
            }
        }
    }
}
