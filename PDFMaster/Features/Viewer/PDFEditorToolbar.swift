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

    @State private var showModePicker = false

    var body: some View {
        VStack(spacing: 0) {
            // Mode bar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(EditorMode.allCases) { mode in
                        Button {
                            viewModel.editorMode = mode
                            if mode == .signature { viewModel.showSignatureSheet = true }
                            if mode == .search { viewModel.showSearchPanel = true }
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: mode.icon)
                                    .font(.system(size: 18, weight: viewModel.editorMode == mode ? .bold : .regular))
                                Text(mode.rawValue)
                                    .font(.caption2)
                            }
                            .foregroundStyle(viewModel.editorMode == mode ? AppTheme.primary : .secondary)
                            .frame(minWidth: 52)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 8)
                            .background(viewModel.editorMode == mode ? AppTheme.primary.opacity(0.1) : .clear)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .background(.bar)

            Divider()

            // Annotate subtool bar
            if viewModel.editorMode == .annotate {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(AnnotationSubtool.allCases) { tool in
                            Button {
                                viewModel.annotationSubtool = tool
                            } label: {
                                Label(tool.rawValue, systemImage: tool.icon)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(viewModel.annotationSubtool == tool ? AppTheme.primary : .secondary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(viewModel.annotationSubtool == tool ? AppTheme.primary.opacity(0.1) : .clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            .buttonStyle(.plain)
                        }

                        Divider().frame(height: 20)

                        Button { viewModel.showInspector = true } label: {
                            Image(systemName: "paintpalette")
                                .font(.caption)
                                .foregroundStyle(AppTheme.primary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                .background(.bar.opacity(0.8))
                Divider()

                // Multi-point subtoolbar
                if viewModel.annotationSubtool.isMultiPointTool {
                    HStack(spacing: 12) {
                        Text("Tap to place points, double-tap to finish")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button { viewModel.polygonPoints = [] } label: {
                            Label("Clear", systemImage: "xmark.circle")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.red)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.bar.opacity(0.8))
                    Divider()
                }

                // Measurement subtoolbar
                if viewModel.annotationSubtool == .measurement {
                    HStack(spacing: 12) {
                        Text("\(viewModel.measurementScale, specifier: "%.0f") px/\(viewModel.measurementUnit)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Button("Calibrate") { onCalibrate() }
                            .font(.caption.weight(.medium))
                            .buttonStyle(.plain)
                            .foregroundStyle(AppTheme.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.bar.opacity(0.8))
                    Divider()
                }
            }

            // Draw toolbar
            if viewModel.editorMode == .draw {
                HStack(spacing: 12) {
                    Button { viewModel.showInspector = true } label: {
                        Label("Style", systemImage: "paintpalette")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppTheme.primary)

                    Button { viewModel.annotationColor = .yellow; viewModel.annotationOpacity = 0.4 } label: {
                        Label("Highlighter", systemImage: "highlighter")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.orange)

                    Button { viewModel.annotationColor = .black; viewModel.annotationOpacity = 1; viewModel.lineWidth = 4 } label: {
                        Label("Marker", systemImage: "pencil.tip")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.primary)

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.bar.opacity(0.8))
                Divider()
            }

            // Redact toolbar
            if viewModel.editorMode == .redact {
                HStack(spacing: 12) {
                    Text("Drag to mark areas for redaction")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        onApplyRedactions()
                    } label: {
                        Label("Apply", systemImage: "checkmark.circle.fill")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.bar.opacity(0.8))
                Divider()
            }

            // Stamp toolbar
            if viewModel.editorMode == .stamp {
                HStack(spacing: 12) {
                    Button { viewModel.showStampPicker = true } label: {
                        Label("Pick Stamp", systemImage: "seal")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppTheme.primary)
                    Spacer()
                    Text("Tap on the PDF to place")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.bar.opacity(0.8))
                Divider()
            }

            // Image toolbar
            if viewModel.editorMode == .image {
                HStack(spacing: 12) {
                    Text("Tap on the PDF to place an image")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.bar.opacity(0.8))
                Divider()
            }

            // Link toolbar
            if viewModel.editorMode == .link {
                HStack(spacing: 12) {
                    Text("Tap on the PDF to place a link")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.bar.opacity(0.8))
                Divider()
            }

            // Bottom actions
            HStack(spacing: 0) {
                toolbarButton("Add Page", "doc.badge.plus", action: onAddPage)
                toolbarButton("Undo", "arrow.uturn.backward") { viewModel.undo() }
                    .disabled(!viewModel.canUndo)
                toolbarButton("Redo", "arrow.uturn.forward") { viewModel.redo() }
                    .disabled(!viewModel.canRedo)

                if viewModel.editorMode == .annotate && viewModel.annotationSubtool.isMarkupTool {
                    toolbarButton("Apply", "checkmark.circle.fill") { onMarkupApply() }
                        .foregroundStyle(AppTheme.primary)
                }

                if viewModel.editorMode == .annotate && viewModel.annotationSubtool.isMultiPointTool {
                    toolbarButton("Finish", "checkmark.circle.fill") { onCompletePolygon() }
                        .foregroundStyle(AppTheme.primary)
                }

                toolbarButton("Pages", "square.grid.2x2", action: onReorder)
                toolbarButton("Delete", "trash", action: onDeletePage)
                    .foregroundStyle(.red)
            }
            .padding(.vertical, 4)
            .background(.bar)
        }
    }

    private func toolbarButton(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                Text(title)
                    .font(.system(size: 9, weight: .medium))
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}
