import SwiftUI

struct PDFEditorToolbar: View {
    @ObservedObject var viewModel: PDFEditorViewModel
    let documentPageCount: Int
    let currentPageIndex: Int
    let onSave: () -> Void
    let onPrint: () -> Void
    let onAddPage: () -> Void
    let onDeletePage: () -> Void
    let onReorder: () -> Void
    let onMarkupApply: () -> Void
    let onApplyRedactions: () -> Void
    let onCalibrate: () -> Void
    let onCompletePolygon: () -> Void

    @State private var modeExpanded = false

    private var isActiveMode: Bool { viewModel.editorMode != .view }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            VStack(spacing: 0) {
                modePill
                    .padding(.horizontal, 8)
                    .padding(.top, 8)

                if isActiveMode {
                    subtoolSection
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                actionBar
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                    .padding(.top, isActiveMode ? 4 : 0)
            }
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.12), radius: 12, y: -2)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 6)
        }
        .ignoresSafeArea(.keyboard)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: viewModel.editorMode)
        .animation(.spring(response: 0.3, dampingFraction: 0.9), value: viewModel.annotationSubtool)
    }

    // MARK: - Mode Pill

    private var modePill: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(EditorMode.allCases) { mode in
                    let isActive = viewModel.editorMode == mode
                    Button {
                        activateMode(mode)
                    } label: {
                        Image(systemName: mode.icon)
                            .font(.system(size: 17, weight: isActive ? .bold : .regular))
                            .foregroundStyle(isActive ? .white : .secondary)
                            .frame(width: 38, height: 34)
                            .background {
                                if isActive {
                                    Capsule()
                                        .fill(AppTheme.primary)
                                        .shadow(color: AppTheme.primary.opacity(0.3), radius: 4, y: 1)
                                }
                            }
                            .scaleEffect(isActive ? 1.05 : 1)
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
        }
        .scrollClipDisabled(true)
    }

    private func activateMode(_ mode: EditorMode) {
        let haptic = UIImpactFeedbackGenerator(style: .soft)
        haptic.impactOccurred()
        viewModel.editorMode = mode
        if mode == .signature { viewModel.showSignatureSheet = true }
        if mode == .search { viewModel.showSearchPanel = true }
    }

    // MARK: - Subtool Section

    @ViewBuilder
    private var subtoolSection: some View {
        VStack(spacing: 0) {
            Divider()
                .padding(.horizontal, 4)

            switch viewModel.editorMode {
            case .annotate:
                annotateSubtools

            case .draw:
                drawSubtools

            case .stamp:
                ContextHint("Tap on the PDF to place", icon: "seal")

            case .signature:
                ContextHint("Tap to sign", icon: "signature")

            case .text:
                ContextHint("Tap to add text", icon: "character.textbox")

            case .search:
                ContextHint("Search document", icon: "magnifyingglass")

            case .redact:
                redactSubtools

            case .image:
                ContextHint("Tap to place an image", icon: "photo")

            case .link:
                ContextHint("Tap to place a link", icon: "link")

            case .view:
                EmptyView()
            }
        }
    }

    // MARK: Annotate

    private var annotateSubtools: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(AnnotationSubtool.allCases) { tool in
                        let isActive = viewModel.annotationSubtool == tool
                        Button {
                            viewModel.annotationSubtool = tool
                        } label: {
                            VStack(spacing: 2) {
                                Image(systemName: tool.icon)
                                    .font(.system(size: 15, weight: isActive ? .bold : .regular))
                                Text(tool.rawValue)
                                    .font(.system(size: 8, weight: isActive ? .semibold : .regular))
                            }
                            .foregroundStyle(isActive ? AppTheme.primary : .secondary)
                            .frame(minWidth: 42)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 6)
                            .background {
                                if isActive {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(AppTheme.primary.opacity(0.12))
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    inspectorButton
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
            .scrollClipDisabled(true)

            if viewModel.annotationSubtool.isMultiPointTool {
                multiPointBar
            }
            if viewModel.annotationSubtool == .measurement {
                measurementBar
            }
        }
    }

    private var inspectorButton: some View {
        Button { viewModel.showInspector = true } label: {
            Image(systemName: "paintpalette.fill")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.primary)
                .frame(width: 28, height: 28)
                .background(Circle().fill(AppTheme.primary.opacity(0.12)))
        }
        .buttonStyle(.plain)
        .padding(.leading, 4)
    }

    private var multiPointBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "hand.tap")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("Tap points · Double-tap or tap Finish")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Button { viewModel.polygonPoints = [] } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.regularMaterial)
    }

    private var measurementBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "ruler")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("\(viewModel.measurementScale, specifier: "%.0f") px/\(viewModel.measurementUnit)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Button("Calibrate") { onCalibrate() }
                .font(.caption2.weight(.semibold))
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.primary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.regularMaterial)
    }

    // MARK: Draw

    private var drawSubtools: some View {
        HStack(spacing: 8) {
            Button { viewModel.showInspector = true } label: {
                Label("Style", systemImage: "paintpalette.fill")
                    .font(.caption2.weight(.semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.primary)

            quickColor(.yellow, label: "Highlighter")
            quickColor(.black, label: "Marker")
            quickColor(.systemBlue, label: "Pen")
            quickColor(.systemRed, label: "Red")

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private func quickColor(_ color: UIColor, label: String) -> some View {
        Button {
            viewModel.annotationColor = Color(color)
            viewModel.annotationOpacity = color == .yellow ? 0.4 : 1
            viewModel.lineWidth = color == .black ? 4 : 2.5
        } label: {
            Circle()
                .fill(Color(color))
                .frame(width: 22, height: 22)
                .overlay(Circle().strokeBorder(.white.opacity(0.5), lineWidth: 1))
                .shadow(color: Color(color).opacity(0.3), radius: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: Redact

    private var redactSubtools: some View {
        HStack(spacing: 8) {
            Image(systemName: "rectangle.slash")
                .font(.caption2)
                .foregroundStyle(.red)
            Text("Drag to mark areas")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Button { onApplyRedactions() } label: {
                Label("Apply", systemImage: "checkmark.circle.fill")
                    .font(.caption2.weight(.semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack(spacing: 0) {
            actionItem("Add Page", "doc.badge.plus", action: onAddPage)

            Divider().frame(height: 20)

            actionItem("Undo", "arrow.uturn.backward") { viewModel.undo() }
                .disabled(!viewModel.canUndo)
            actionItem("Redo", "arrow.uturn.forward") { viewModel.redo() }
                .disabled(!viewModel.canRedo)

            if viewModel.editorMode == .annotate && viewModel.annotationSubtool.isMarkupTool {
                Divider().frame(height: 20)
                actionItem("Apply", "checkmark.circle.fill", color: AppTheme.primary, action: onMarkupApply)
            }

            if viewModel.editorMode == .annotate && viewModel.annotationSubtool.isMultiPointTool {
                Divider().frame(height: 20)
                actionItem("Finish", "checkmark.circle.fill", color: AppTheme.primary, action: onCompletePolygon)
            }

            Divider().frame(height: 20)

            actionItem("Pages", "square.grid.2x2", action: onReorder)
            actionItem("Delete", "trash", color: .red, action: onDeletePage)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func actionItem(_ title: String, _ icon: String, color: Color = .primary, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(.system(size: 7, weight: .medium))
            }
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Context Hint

struct ContextHint: View {
    let text: String
    let icon: String

    init(_ text: String, icon: String) {
        self.text = text
        self.icon = icon
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(text)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
