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

        // Re-read the iCloud container when returning to the app, so scans made
        // on another device show up (downloads happen via coordinated reads).
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.loadSavedScans()
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
        let ids = offsets.map { savedScans[$0].id }
        savedScans.remove(atOffsets: offsets)
        removeScanFiles(ids)
    }

    func deleteScan(withID id: UUID) {
        if let index = savedScans.firstIndex(where: { $0.id == id }) {
            savedScans.remove(at: index)
        }
        removeScanFiles([id])
    }

    // Delete the on-disk files for the given scan IDs (explicit deletion so a
    // transient empty reload can never mass-delete via the save-time prune)
    private func removeScanFiles(_ ids: [UUID]) {
        DispatchQueue.global(qos: .utility).async {
            let dir = self.scansDirectoryURL()
            for id in ids {
                self.coordinatedRemove(self.scanFileURL(for: id, in: dir))
            }
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
    
    private nonisolated var iCloudContainerID: String { "iCloud.com.medcopywriter.PosterLens" }

    // Always-local scans directory (migration source and fallback)
    nonisolated private func localScansDirectoryURL() -> URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = documentsDirectory.appendingPathComponent("scans", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // iCloud container scans directory, or nil if iCloud is unavailable.
    // NOTE: url(forUbiquityContainerIdentifier:) blocks — only call off the main thread.
    nonisolated private func iCloudScansDirectoryURL() -> URL? {
        guard let container = FileManager.default.url(forUbiquityContainerIdentifier: iCloudContainerID) else {
            return nil
        }
        let dir = container.appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent("scans", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // The active scans directory: iCloud when available, otherwise local.
    nonisolated private func scansDirectoryURL() -> URL {
        return iCloudScansDirectoryURL() ?? localScansDirectoryURL()
    }

    nonisolated private func scanFileURL(for id: UUID, in dir: URL) -> URL {
        return dir.appendingPathComponent("\(id.uuidString).json")
    }

    nonisolated private func jsonFileURLs(in dir: URL) -> [URL] {
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "json" }
    }

    // File-coordinated write/remove so iCloud doesn't see partial files
    nonisolated private func coordinatedWrite(_ data: Data, to url: URL) {
        let coordinator = NSFileCoordinator()
        var coordError: NSError?
        coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &coordError) { writeURL in
            do { try data.write(to: writeURL) }
            catch { print("Coordinated write failed for \(url.lastPathComponent): \(error.localizedDescription)") }
        }
        if let coordError { print("File coordination error: \(coordError.localizedDescription)") }
    }

    // Coordinated read; for an iCloud item this triggers a download and waits
    // until the latest version is available locally before reading.
    nonisolated private func coordinatedRead(_ url: URL) -> Data? {
        var result: Data?
        let coordinator = NSFileCoordinator()
        var coordError: NSError?
        coordinator.coordinate(readingItemAt: url, options: [], error: &coordError) { readURL in
            result = try? Data(contentsOf: readURL)
        }
        return result
    }

    nonisolated private func coordinatedRemove(_ url: URL) {
        let coordinator = NSFileCoordinator()
        var coordError: NSError?
        coordinator.coordinate(writingItemAt: url, options: .forDeleting, error: &coordError) { deleteURL in
            try? FileManager.default.removeItem(at: deleteURL)
        }
        if let coordError { print("File coordination (delete) error: \(coordError.localizedDescription)") }
    }

    // Write all current scans as per-scan files and prune files for deleted scans
    private func saveScans() {
        let scansToSave = savedScans  // Copy to avoid capturing self

        DispatchQueue.global(qos: .utility).async {
            let dir = self.scansDirectoryURL()
            let encoder = JSONEncoder()

            for scan in scansToSave {
                if let data = try? encoder.encode(scan) {
                    self.coordinatedWrite(data, to: self.scanFileURL(for: scan.id, in: dir))
                }
            }

            // Prune files for scans that no longer exist — but ONLY when we have
            // scans in memory. Deletions are handled explicitly elsewhere, so an
            // empty in-memory set here means a failed/transient load, not a real
            // "delete everything"; never mass-delete from that state.
            guard !scansToSave.isEmpty else { return }
            let currentIDs = Set(scansToSave.map { $0.id.uuidString })
            for file in self.jsonFileURLs(in: dir) {
                let fileID = file.deletingPathExtension().lastPathComponent
                if !currentIDs.contains(fileID) {
                    self.coordinatedRemove(file)
                }
            }
        }
    }

    // Load scans from per-scan files, seeding the active directory from local /
    // legacy storage on first run (e.g. when iCloud is first enabled).
    private func loadSavedScans() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let fileManager = FileManager.default
            let decoder = JSONDecoder()
            let targetDir = self.scansDirectoryURL()       // iCloud when available, else local
            let localDir = self.localScansDirectoryURL()

            // Seed the target directory if it has no scans yet
            if self.jsonFileURLs(in: targetDir).isEmpty {
                let localFiles = self.jsonFileURLs(in: localDir)
                if targetDir != localDir, !localFiles.isEmpty {
                    // Moving onto iCloud: copy existing local per-scan files into the container
                    for file in localFiles {
                        if let data = try? Data(contentsOf: file) {
                            self.coordinatedWrite(data, to: targetDir.appendingPathComponent(file.lastPathComponent))
                        }
                    }
                    print("Seeded iCloud scans directory from \(localFiles.count) local files")
                } else {
                    // Migrate from the legacy single JSON file, then UserDefaults
                    let legacyURL = self.getScansFileURL()
                    if fileManager.fileExists(atPath: legacyURL.path),
                       let data = try? Data(contentsOf: legacyURL),
                       let legacyScans = try? decoder.decode([PosterScan].self, from: data) {
                        self.writeScanFiles(legacyScans, to: targetDir)
                        let backupURL = legacyURL.appendingPathExtension("bak")
                        try? fileManager.removeItem(at: backupURL)
                        try? fileManager.moveItem(at: legacyURL, to: backupURL)
                        print("Migrated \(legacyScans.count) scans from legacy file")
                    } else if let data = UserDefaults.standard.data(forKey: self.saveKey),
                              let legacyScans = try? decoder.decode([PosterScan].self, from: data) {
                        self.writeScanFiles(legacyScans, to: targetDir)
                        UserDefaults.standard.removeObject(forKey: self.saveKey)
                        print("Migrated \(legacyScans.count) scans from UserDefaults")
                    }
                }
            }

            // Load everything in the target directory. A coordinated read pulls
            // down iCloud items on demand, so scans from another device appear.
            let scanFiles = self.jsonFileURLs(in: targetDir)
            var loaded: [PosterScan] = []
            for file in scanFiles {
                if let data = self.coordinatedRead(file),
                   let scan = try? decoder.decode(PosterScan.self, from: data) {
                    loaded.append(scan)
                }
            }

            // Safety: if files exist but none were readable (e.g. iCloud not ready
            // yet on a foreground refresh), keep the current scans rather than
            // clobbering them with an empty set.
            if loaded.isEmpty && !scanFiles.isEmpty {
                print("Scan files present but none readable yet; keeping current scans")
                return
            }

            let sorted = loaded.sorted(by: { $0.date > $1.date })
            DispatchQueue.main.async {
                self.savedScans = sorted
                print("Loaded \(sorted.count) scans from \(targetDir.path)")
            }
        }
    }

    // Write the given scans to per-scan files in a specific directory (migration)
    nonisolated private func writeScanFiles(_ scans: [PosterScan], to dir: URL) {
        let encoder = JSONEncoder()
        for scan in scans {
            if let data = try? encoder.encode(scan) {
                coordinatedWrite(data, to: scanFileURL(for: scan.id, in: dir))
            }
        }
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
        
        // Remove the saved files off the main thread (the iCloud lookup blocks)
        let conversationsFileURL = getConversationsFileURL()
        DispatchQueue.global(qos: .utility).async {
            let fileManager = FileManager.default

            // Remove per-scan files (iCloud and local) and the legacy file
            let scansDir = self.scansDirectoryURL()
            try? fileManager.removeItem(at: scansDir)
            let localDir = self.localScansDirectoryURL()
            if localDir != scansDir {
                try? fileManager.removeItem(at: localDir)
            }
            try? fileManager.removeItem(at: self.getScansFileURL())

            // Remove conversations file
            if fileManager.fileExists(atPath: conversationsFileURL.path) {
                try? fileManager.removeItem(at: conversationsFileURL)
            }
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
