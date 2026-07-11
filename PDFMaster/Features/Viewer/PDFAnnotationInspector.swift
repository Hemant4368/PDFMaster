import SwiftUI

struct PDFAnnotationInspector: View {
    @ObservedObject var viewModel: PDFEditorViewModel

    var body: some View {
        NavigationStack {
            Form {
                colorSection
                opacitySection

                if viewModel.editorMode == .annotate && viewModel.annotationSubtool.isShapeTool {
                    lineWidthSection
                    fillColorSection
                    dashSection
                }

                if viewModel.editorMode == .text {
                    fontSection
                    textFormatSection
                    alignmentSection
                    spacingSection
                    borderSection
                }

                if viewModel.editorMode == .draw {
                    drawBrushSection
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

    private var colorSection: some View {
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
    }

    private var opacitySection: some View {
        Section("Opacity") {
            VStack {
                Slider(value: $viewModel.annotationOpacity, in: 0.1...1.0)
                Text("\(Int(viewModel.annotationOpacity * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var lineWidthSection: some View {
        Section("Line Width") {
            VStack {
                Slider(value: $viewModel.lineWidth, in: 1...12)
                Text("\(viewModel.lineWidth, specifier: "%.0f") pt")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var fillColorSection: some View {
        Section("Fill Color") {
            ColorPicker("Fill", selection: $viewModel.fillColor)
        }
    }

    private var dashSection: some View {
        Section("Dash Pattern") {
            Picker("Style", selection: Binding(
                get: { viewModel.dashPattern == nil ? 0 : viewModel.dashPattern == [6, 4] ? 1 : 2 },
                set: {
                    switch $0 {
                    case 0: viewModel.dashPattern = nil
                    case 1: viewModel.dashPattern = [6, 4]
                    default: viewModel.dashPattern = [2, 4]
                    }
                }
            )) {
                Text("Solid").tag(0)
                Text("Dashed").tag(1)
                Text("Dotted").tag(2)
            }
            .pickerStyle(.segmented)
        }
    }

    private var fontSection: some View {
        Section("Font") {
            HStack {
                Text("Size")
                Spacer()
                Slider(value: $viewModel.freeTextStyle.fontSize, in: 8...72)
                Text("\(viewModel.freeTextStyle.fontSize, specifier: "%.0f")")
                    .font(.caption)
                    .frame(width: 30)
            }
            ColorPicker("Text Color", selection: $viewModel.freeTextStyle.textColor)
            ColorPicker("Background", selection: $viewModel.freeTextStyle.backgroundColor)
        }
    }

    private var textFormatSection: some View {
        Section("Format") {
            Toggle("Bold", isOn: $viewModel.freeTextStyle.isBold)
            Toggle("Italic", isOn: $viewModel.freeTextStyle.isItalic)
            Toggle("Underline", isOn: $viewModel.freeTextStyle.isUnderline)
            Picker("Font", selection: $viewModel.freeTextStyle.fontFamily) {
                Text("Helvetica").tag("Helvetica")
                Text("Helvetica Neue").tag("Helvetica Neue")
                Text("Arial").tag("Arial")
                Text("Times New Roman").tag("Times New Roman")
                Text("Courier").tag("Courier")
                Text("Georgia").tag("Georgia")
                Text("Verdana").tag("Verdana")
            }
        }
    }

    private var alignmentSection: some View {
        Section("Alignment") {
            Picker("Align", selection: $viewModel.freeTextStyle.alignment) {
                Image(systemName: "text.alignleft").tag(NSTextAlignment.left)
                Image(systemName: "text.aligncenter").tag(NSTextAlignment.center)
                Image(systemName: "text.alignright").tag(NSTextAlignment.right)
            }
            .pickerStyle(.segmented)
        }
    }

    private var spacingSection: some View {
        Section("Spacing") {
            VStack {
                HStack {
                    Text("Char Spacing")
                    Spacer()
                    Slider(value: $viewModel.freeTextStyle.characterSpacing, in: 0...10)
                    Text("\(viewModel.freeTextStyle.characterSpacing, specifier: "%.1f")")
                        .font(.caption)
                        .frame(width: 30)
                }
                HStack {
                    Text("Line Height")
                    Spacer()
                    Slider(value: $viewModel.freeTextStyle.lineHeight, in: 0.8...3.0)
                    Text("\(viewModel.freeTextStyle.lineHeight, specifier: "%.1f")")
                        .font(.caption)
                        .frame(width: 30)
                }
            }
        }
    }

    private var borderSection: some View {
        Section("Border") {
            ColorPicker("Border Color", selection: $viewModel.freeTextStyle.borderColor)
            HStack {
                Text("Width")
                Spacer()
                Slider(value: $viewModel.freeTextStyle.borderWidth, in: 0...8)
                Text("\(viewModel.freeTextStyle.borderWidth, specifier: "%.0f") pt")
                    .font(.caption)
                    .frame(width: 40)
            }
        }
    }

    private var drawBrushSection: some View {
        Section("Brush") {
            Picker("Type", selection: $viewModel.brushType) {
                Text("Pencil").tag(AnnotationTool.pencil)
                Text("Marker").tag(AnnotationTool.marker)
                Text("Highlighter").tag(AnnotationTool.highlighterPen)
                Text("Brush").tag(AnnotationTool.brush)
                Text("Eraser").tag(AnnotationTool.eraser)
            }
            HStack {
                Text("Width")
                Spacer()
                Slider(value: $viewModel.lineWidth, in: 1...20)
                Text("\(viewModel.lineWidth, specifier: "%.0f") pt")
                    .font(.caption)
                    .frame(width: 40)
            }
        }
    }
}

private let annotationColors: [Color] = [
    .yellow, .orange, .red, .pink, .purple, .blue,
    .cyan, .green, .mint, .brown, .gray, .black,
]
