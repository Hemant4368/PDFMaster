import SwiftUI

// Full-screen view (no transparent overlay) — the VC sets the background, not us.
struct ShareToolPickerView: View {
    let filename: String
    let fileType: ShareFileType
    let onSelect: (String) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {

            // Drag handle
            Capsule()
                .fill(Color(uiColor: .tertiaryLabel))
                .frame(width: 40, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 8)

            // File header
            HStack(spacing: 14) {
                Image(systemName: fileType.icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Color(uiColor: fileType.color))
                    .frame(width: 50, height: 50)
                    .background(Color(uiColor: fileType.color).opacity(0.12),
                                in: RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 2) {
                    Text(filename)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(uiColor: .label))
                        .lineLimit(2)
                    Text("Open with PDF Converter")
                        .font(.caption)
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Divider()
                .padding(.horizontal, 20)

            Text("CHOOSE AN ACTION")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(uiColor: .secondaryLabel))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 4)

            // Tool rows
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(fileType.tools.enumerated()), id: \.element.key) { idx, tool in
                        Button {
                            onSelect(tool.key)
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: tool.icon)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(.red)
                                    .frame(width: 34, height: 34)
                                    .background(Color.red.opacity(0.1),
                                                in: RoundedRectangle(cornerRadius: 9))

                                Text(tool.name)
                                    .font(.body)
                                    .foregroundStyle(Color(uiColor: .label))

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color(uiColor: .tertiaryLabel))
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if idx < fileType.tools.count - 1 {
                            Divider().padding(.leading, 68)
                        }
                    }
                }
            }

            Divider()
                .padding(.top, 8)

            // Cancel button
            Button {
                onCancel()
            } label: {
                Text("Cancel")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
        .background(Color(uiColor: .systemBackground))
    }
}
