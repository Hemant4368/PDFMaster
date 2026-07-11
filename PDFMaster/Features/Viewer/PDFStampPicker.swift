import SwiftUI

struct PDFStampPicker: View {
    @ObservedObject var viewModel: PDFEditorViewModel
    @State private var customText = ""

    private let columns = [GridItem(.adaptive(minimum: 140))]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    SectionHeader("Standard")
                    ForEach(StampDef.builtIn.filter { !$0.isDynamic }) { stamp in
                        stampButton(stamp)
                    }

                    SectionHeader("Dynamic")
                    ForEach(StampDef.builtIn.filter(\.isDynamic)) { stamp in
                        stampButton(stamp)
                    }
                }
                .padding()

                Divider().padding(.horizontal)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Custom Stamp")
                        .font(.headline)
                    TextField("Enter stamp text", text: $customText)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        guard !customText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        let text = customText.trimmingCharacters(in: .whitespaces).uppercased()
                        let stamp = StampDef(label: text, color: .systemGray, isDynamic: false, imageData: nil)
                        placeOrQueue(stamp)
                    } label: {
                        Text("Place Custom Stamp")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(AppTheme.primary)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(customText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding()
            }
            .navigationTitle("Select Stamp")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("Cancel") {
                    viewModel.pendingTapPoint = nil
                    viewModel.pendingStamp = nil
                    viewModel.showStampPicker = false
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func stampButton(_ stamp: StampDef) -> some View {
        Button {
            placeOrQueue(stamp)
        } label: {
            let color = Color(stamp.color)
            VStack(spacing: 4) {
                Text(stamp.isDynamic ? stamp.displayLabel : stamp.label)
                    .font(stamp.isDynamic ? .subheadline.weight(.semibold) : .headline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if stamp.isDynamic {
                    Text(stamp.label)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(color.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(color, lineWidth: 2)
            )
            .shadow(color: color.opacity(0.3), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }

    private func placeOrQueue(_ stamp: StampDef) {
        if viewModel.pendingTapPoint != nil {
            viewModel.placeStampAtPendingPoint(stamp)
        } else {
            viewModel.pendingStamp = stamp
        }
        viewModel.showStampPicker = false
    }
}

private struct SectionHeader: View {
    let title: String
    init(_ title: String) { self.title = title }
    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
    }
}
