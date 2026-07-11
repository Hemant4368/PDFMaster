import SwiftUI

struct SettingsView: View {
    @AppStorage("settings.darkMode") private var darkMode = false
    @AppStorage("settings.appLockEnabled") private var appLockEnabled = false
    @AppStorage("settings.ocrLanguage") private var ocrLanguage = "en-US"
    @AppStorage("settings.pdfQuality") private var pdfQuality = PDFQuality.balanced.rawValue
    @State private var showSubscription = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Premium") {
                    Button { showSubscription = true } label: {
                        Label("PDF Master AI Premium", systemImage: "crown.fill")
                            .foregroundStyle(AppTheme.primary)
                    }
                }
                Section("Preferences") {
                    Toggle("Dark Mode", isOn: $darkMode)
                    Picker("PDF Quality", selection: $pdfQuality) {
                        ForEach(PDFQuality.allCases) { Text($0.rawValue).tag($0.rawValue) }
                    }
                    TextField("OCR Language", text: $ocrLanguage)
                }
                Section("Security") {
                    Toggle("App Lock", isOn: $appLockEnabled)
                    NavigationLink("Privacy Settings") {
                        Text("All documents are stored locally in the app container. iCloud-ready services can be added behind the storage protocols without changing feature screens.")
                            .padding()
                            .navigationTitle("Privacy")
                    }
                }
                Section("Support") {
                    Link("Help & Support", destination: URL(string: "mailto:support@pdfmasterai.example")!)
                    Text("Version 1.0")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .preferredColorScheme(darkMode ? .dark : nil)
            .sheet(isPresented: $showSubscription) {
                NavigationStack { SubscriptionView() }
            }
        }
    }
}
