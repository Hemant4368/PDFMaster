import SwiftUI

struct PDFAnnotationInspector: View {
    @ObservedObject var viewModel: PDFEditorViewModel
    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    colorSection

                    if viewModel.editorMode == .annotate && viewModel.annotationSubtool.isShapeTool {
                        shapeStyleSection
                    }

                    if viewModel.editorMode == .text {
                        fontSection
                    }

                    if viewModel.editorMode == .draw {
                        brushSection
                    }

                    if viewModel.selectionManager.hasSelection {
                        deleteSection
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Style")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { viewModel.showInspector = false }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Color Swatches

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Color", icon: "paintpalette.fill")

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 10) {
                ForEach(annotationColors, id: \.self) { color in
                    ZStack {
                        Circle()
                            .fill(color)
                            .frame(width: 38, height: 38)
                            .overlay(
                                Circle()
                                    .strokeBorder(.primary.opacity(0.15), lineWidth: 1)
                            )
                            .shadow(color: color.opacity(0.3), radius: viewModel.annotationColor == color ? 4 : 0)

                        if viewModel.annotationColor == color {
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(color == .black || color == .blue || color == .purple ? .white : .black)
                        }
                    }
                    .scaleEffect(viewModel.annotationColor == color ? 1.1 : 1)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                            viewModel.annotationColor = color
                        }
                    }
                }
            }

            opacitySlider
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var opacitySlider: some View {
        VStack(spacing: 4) {
            HStack {
                Text("Opacity")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(viewModel.annotationOpacity * 100))%")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(value: $viewModel.annotationOpacity, in: 0.1...1.0)
                .tint(AppTheme.primary)
        }
    }

    // MARK: - Shape Style

    private var shapeStyleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Shape Style", icon: "square.on.circle")

            lineWidthControl
            dashControl
            fillControl
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var lineWidthControl: some View {
        HStack {
            Image(systemName: "lineweight")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Slider(value: $viewModel.lineWidth, in: 1...12)
                .tint(AppTheme.primary)
            Text("\(viewModel.lineWidth, specifier: "%.0f") pt")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(width: 36)
        }
    }

    private var dashControl: some View {
        HStack {
            Image(systemName: "line.diagonal")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 20)
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
                Label("Solid", systemImage: "line.diagonal").tag(0)
                Label("Dash", systemImage: "line.diagonal").tag(1)
                Label("Dot", systemImage: "dot.viewfinder").tag(2)
            }
            .pickerStyle(.segmented)
        }
    }

    private var fillControl: some View {
        HStack {
            Image(systemName: "drop.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            ColorPicker("Fill Color", selection: $viewModel.fillColor)
                .font(.subheadline)
        }
    }

    // MARK: - Font

    private var fontSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Font", icon: "character.textbox")

            VStack(spacing: 10) {
                fontPicker
                fontSizeControl
                formatToggles
                alignmentControl
                colorRow("Text Color", color: $viewModel.freeTextStyle.textColor)
                colorRow("Background", color: $viewModel.freeTextStyle.backgroundColor)
                colorRow("Border", color: $viewModel.freeTextStyle.borderColor)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var fontPicker: some View {
        Picker("Font", selection: $viewModel.freeTextStyle.fontFamily) {
            ForEach(["Helvetica", "Helvetica Neue", "Arial", "Times New Roman", "Courier", "Georgia", "Verdana"], id: \.self) { name in
                Text(name).tag(name)
            }
        }
        .pickerStyle(.menu)
    }

    private var fontSizeControl: some View {
        HStack {
            Image(systemName: "textformat.size")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Slider(value: $viewModel.freeTextStyle.fontSize, in: 8...72, step: 1)
                .tint(AppTheme.primary)
            Text("\(viewModel.freeTextStyle.fontSize, specifier: "%.0f")")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(width: 30)
        }
    }

    private var formatToggles: some View {
        HStack(spacing: 8) {
            formatButton("B", isOn: $viewModel.freeTextStyle.isBold)
            formatButton("I", isOn: $viewModel.freeTextStyle.isItalic)
            formatButton("U", isOn: $viewModel.freeTextStyle.isUnderline)
            Spacer()
            alignmentButton("text.alignleft", alignment: .left)
            alignmentButton("text.aligncenter", alignment: .center)
            alignmentButton("text.alignright", alignment: .right)
        }
    }

    private func formatButton(_ label: String, isOn: Binding<Bool>) -> some View {
        Button {
            withAnimation { isOn.wrappedValue.toggle() }
        } label: {
            Text(label)
                .font(.system(size: 14, weight: .bold))
                .frame(width: 32, height: 28)
                .background {
                    if isOn.wrappedValue {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(AppTheme.primary.opacity(0.15))
                    }
                }
                .foregroundStyle(isOn.wrappedValue ? AppTheme.primary : .secondary)
        }
        .buttonStyle(.plain)
    }

    private func alignmentButton(_ icon: String, alignment: NSTextAlignment) -> some View {
        Button {
            viewModel.freeTextStyle.alignment = alignment
        } label: {
            Image(systemName: icon)
                .font(.system(size: 14))
                .frame(width: 32, height: 28)
                .background {
                    if viewModel.freeTextStyle.alignment == alignment {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(AppTheme.primary.opacity(0.15))
                    }
                }
                .foregroundStyle(viewModel.freeTextStyle.alignment == alignment ? AppTheme.primary : .secondary)
        }
        .buttonStyle(.plain)
    }

    private var alignmentControl: some View {
        EmptyView()
    }

    private func colorRow(_ label: String, color: Binding<Color>) -> some View {
        HStack {
            ColorPicker(label, selection: color)
                .font(.subheadline)
        }
    }

    // MARK: - Brush

    private var brushSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Brush", icon: "pencil.tip")

            VStack(spacing: 10) {
                Picker("Type", selection: $viewModel.brushType) {
                    Label("Pencil", systemImage: "pencil.tip").tag(AnnotationTool.pencil)
                    Label("Marker", systemImage: "pencil.tip").tag(AnnotationTool.marker)
                    Label("Highlighter", systemImage: "highlighter").tag(AnnotationTool.highlighterPen)
                    Label("Brush", systemImage: "paintbrush.pointed").tag(AnnotationTool.brush)
                    Label("Eraser", systemImage: "eraser").tag(AnnotationTool.eraser)
                }
                .pickerStyle(.menu)

                HStack {
                    Image(systemName: "lineweight")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                    Slider(value: $viewModel.lineWidth, in: 1...20)
                        .tint(AppTheme.primary)
                    Text("\(viewModel.lineWidth, specifier: "%.0f") pt")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .frame(width: 36)
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Delete

    private var deleteSection: some View {
        Button(role: .destructive) {
            if let ann = viewModel.selectionManager.selectedAnnotation,
               let page = ann.page {
                viewModel.removeAnnotation(ann, from: page)
                viewModel.selectionManager.deselectAll()
                viewModel.showInspector = false
            }
        } label: {
            Label("Delete Annotation", systemImage: "trash")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(AppTheme.primary)
            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        }
    }
}

private let annotationColors: [Color] = [
    .yellow, .orange, .red, .pink, .purple, .blue,
    .cyan, .green, .mint, .brown, .gray, .black,
]
