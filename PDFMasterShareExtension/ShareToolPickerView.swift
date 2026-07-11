import SwiftUI

struct ShareToolPickerView: View {
    let filename: String
    let fileType: ShareFileType
    let onSelect: (String) -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { onCancel() }

            VStack(spacing: 0) {
                // Handle
                Capsule()
                    .fill(Color.secondary.opacity(0.5))
                    .frame(width: 40, height: 5)
                    .padding(.top, 10)

                // File header
                HStack(spacing: 14) {
                    Image(systemName: fileType.icon)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(Color(uiColor: fileType.color))
                        .frame(width: 52, height: 52)
                        .background(Color(uiColor: fileType.color).opacity(0.12),
                                    in: RoundedRectangle(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(filename)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(2)
                        Text("Open with PDF Master AI")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Divider().padding(.vertical, 14)

                Text("Choose an action")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)

                // Tool list
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(fileType.tools, id: \.key) { tool in
                            Button {
                                onSelect(tool.key)
                            } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: tool.icon)
                                        .font(.system(size: 17, weight: .medium))
                                        .foregroundStyle(.red)
                                        .frame(width: 36, height: 36)
                                        .background(Color.red.opacity(0.1),
                                                    in: RoundedRectangle(cornerRadius: 10))
                                    Text(tool.name)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 360)

                Divider().padding(.vertical, 6)

                Button(role: .cancel) {
                    onCancel()
                } label: {
                    Text("Cancel")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
    }
}
