import SwiftUI

struct NotesCard: View {
    let notes: String?
    let onTap: () -> Void
    var onDelete: (() -> Void)? = nil

    @State private var showDeleteConfirm = false

    private var hasNotes: Bool {
        !(notes ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Your Notes")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: hasNotes ? "square.and.pencil" : "plus")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if hasNotes {
                    Text(notes ?? "")
                        .font(.body)
                        .foregroundColor(.primary.opacity(0.9))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Add your own notes about this poster")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            if hasNotes, onDelete != nil {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Delete Notes", systemImage: "trash")
                }
            }
        }
        .confirmationDialog(
            "Delete these notes?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete Notes", role: .destructive) {
                HapticManager.shared.mediumImpact()
                onDelete?()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

struct NotesEditorSheet: View {
    let initialNotes: String
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String = ""
    @State private var showDeleteConfirm = false
    @FocusState private var editorFocused: Bool

    private var hasInitialNotes: Bool {
        !initialNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationView {
            TextEditor(text: $text)
                .focused($editorFocused)
                .padding(.horizontal, 12)
                .padding(.top, 4)
                .navigationTitle("Your Notes")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        if hasInitialNotes {
                            Button(role: .destructive) {
                                showDeleteConfirm = true
                            } label: {
                                Image(systemName: "trash")
                            }
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            onSave(text.trimmingCharacters(in: .whitespacesAndNewlines))
                            dismiss()
                        }
                        .fontWeight(.semibold)
                    }
                }
                .confirmationDialog(
                    "Delete these notes?",
                    isPresented: $showDeleteConfirm,
                    titleVisibility: .visible
                ) {
                    Button("Delete Notes", role: .destructive) {
                        onSave("")
                        dismiss()
                    }
                    Button("Cancel", role: .cancel) {}
                }
                .onAppear {
                    text = initialNotes
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        editorFocused = true
                    }
                }
        }
    }
}
