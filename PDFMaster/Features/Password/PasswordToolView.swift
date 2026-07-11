import SwiftData
import SwiftUI

struct PasswordToolView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var sourceURL: URL?
    @State private var showPicker = false
    @State private var password = ""
    @State private var confirm = ""
    @State private var removePassword = false
    @State private var title = "Secure PDF"
    @State private var savedDocument: DocumentRecord?
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                Button(sourceURL?.lastPathComponent ?? "Choose PDF") { showPicker = true }
                Toggle("Remove password", isOn: $removePassword)
                SecureField("Password", text: $password)
                if !removePassword { SecureField("Confirm Password", text: $confirm) }
                TextField("Output name", text: $title)
            }
            Section {
                PrimaryButton(title: removePassword ? "Remove Password" : "Encrypt PDF", systemImage: "lock.shield") { run() }
                    .disabled(sourceURL == nil || password.isEmpty || (!removePassword && password != confirm))
            }
        }
        .navigationTitle("PDF Password")
        .sheet(isPresented: $showPicker) {
            DocumentPickerView(allowsMultipleSelection: false) { sourceURL = $0.first }
        }
        .navigationDestination(item: $savedDocument) { PDFViewerView(document: $0) }
        .alert("Password", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func run() {
        guard let sourceURL else { return }
        Task {
            do {
                let data = removePassword
                    ? try await PDFProcessingService.shared.unlock(url: sourceURL, password: password)
                    : try await PDFProcessingService.shared.protect(url: sourceURL, password: password)
                savedDocument = try await SaveDocumentHelper.savePDF(data: data, title: title, modelContext: modelContext)
            } catch { errorMessage = error.localizedDescription }
        }
    }
}
