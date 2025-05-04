import Foundation
import Combine
import UIKit

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
    
    private func saveScans() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(savedScans)
            UserDefaults.standard.set(data, forKey: saveKey)
        } catch {
            print("Failed to save scans: \(error.localizedDescription)")
        }
    }
    
    private func loadSavedScans() {
        guard let data = UserDefaults.standard.data(forKey: saveKey) else { return }
        
        do {
            let decoder = JSONDecoder()
            savedScans = try decoder.decode([PosterScan].self, from: data)
        } catch {
            print("Failed to load saved scans: \(error.localizedDescription)")
            
            // If loading fails, reset the saved data
            UserDefaults.standard.removeObject(forKey: saveKey)
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
    
    // Clear all saved scans
    func clearAllScans() {
        savedScans.removeAll()
        UserDefaults.standard.removeObject(forKey: saveKey)
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
    private func saveConversations() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(conversations)
            UserDefaults.standard.set(data, forKey: conversationsKey)
        } catch {
            print("Failed to save conversations: \(error.localizedDescription)")
        }
    }
    
    /// Load conversations from UserDefaults
    private func loadConversations() {
        guard let data = UserDefaults.standard.data(forKey: conversationsKey) else { return }
        
        do {
            let decoder = JSONDecoder()
            conversations = try decoder.decode([Conversation].self, from: data)
        } catch {
            print("Failed to load conversations: \(error.localizedDescription)")
            UserDefaults.standard.removeObject(forKey: conversationsKey)
        }
    }
}
