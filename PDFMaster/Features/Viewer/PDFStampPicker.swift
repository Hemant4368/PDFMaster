import SwiftUI

struct PDFStampPicker: View {
    @ObservedObject var viewModel: PDFEditorViewModel
    @State private var customText = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(StampDef.builtIn) { stamp in
                        Button {
                            if let (_, _) = viewModel.pendingTapPoint {
                                viewModel.placeStampAtPendingPoint(stamp)
                                viewModel.showStampPicker = false
                            } else {
                                viewModel.pendingStamp = stamp
                                viewModel.showStampPicker = false
                            }
                        } label: {
                        let color = Color(stamp.color)
                        Text(stamp.label)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
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
                        let stamp = StampDef(label: customText.trimmingCharacters(in: .whitespaces).uppercased(), color: .systemGray6)
                        if let (_, _) = viewModel.pendingTapPoint {
                            viewModel.placeStampAtPendingPoint(stamp)
                            viewModel.showStampPicker = false
                        } else {
                            viewModel.pendingStamp = stamp
                            viewModel.showStampPicker = false
                        }
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
}
