import SwiftUI

struct PDFAnnotationInspector: View {
    @ObservedObject var viewModel: PDFEditorViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                        ForEach(annotationColors, id: \.self) { color in
                            Circle()
                                .fill(color)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                                )
                                .overlay(
                                    Circle()
                                        .stroke(AppTheme.primary, lineWidth: 2)
                                        .opacity(viewModel.annotationColor == color ? 1 : 0)
                                )
                                .onTapGesture { viewModel.annotationColor = color }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Opacity") {
                    VStack {
                        Slider(value: $viewModel.annotationOpacity, in: 0.1...1.0)
                        Text("\(Int(viewModel.annotationOpacity * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if viewModel.editorMode == .annotate && viewModel.annotationSubtool.isShapeTool {
                    Section("Line Width") {
                        VStack {
                            Slider(value: $viewModel.lineWidth, in: 1...12)
                            Text("\(viewModel.lineWidth, specifier: "%.0f") pt")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if viewModel.editorMode == .text {
                    Section("Font") {
                        HStack {
                            Text("Size")
                            Spacer()
                            Slider(value: $viewModel.fontSize, in: 8...48)
                            Text("\(viewModel.fontSize, specifier: "%.0f")")
                                .font(.caption)
                                .frame(width: 30)
                        }
                        ColorPicker("Text Color", selection: $viewModel.fontColor)
                    }
                }

                if viewModel.selectionManager.hasSelection {
                    Section {
                        Button(role: .destructive) {
                            if let ann = viewModel.selectionManager.selectedAnnotation,
                               let page = ann.page {
                                viewModel.removeAnnotation(ann, from: page)
                                viewModel.selectionManager.deselectAll()
                            }
                        } label: {
                            Label("Delete Annotation", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle("Annotation Style")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("Done") { viewModel.showInspector = false }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private let annotationColors: [Color] = [
    .yellow, .orange, .red, .pink, .purple, .blue,
    .cyan, .green, .mint, .brown, .gray, .black,
]
