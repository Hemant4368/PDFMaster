import SwiftUI

struct ToolsView: View {
    @Binding var showScanner: Bool
    @State private var selectedTool: PDFTool?
    @State private var selectedCategory: ToolCategory = .all

    private var filteredTools: [PDFTool] {
        selectedCategory == .all
            ? PDFTool.allCases
            : PDFTool.allCases.filter { $0.category == selectedCategory }
    }

    var body: some View {
        VStack(spacing: 0) {
            categoryBar
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(filteredTools) { tool in
                        Button {
                            if tool == .scanner { showScanner = true } else { selectedTool = tool }
                        } label: {
                            ToolCard(tool: tool)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
                .animation(.spring(response: 0.38, dampingFraction: 0.82), value: selectedCategory)
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationDestination(item: $selectedTool) { ToolRouterView(tool: $0) }
    }

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(ToolCategory.allCases) { category in
                    Button {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.80)) {
                            selectedCategory = category
                        }
                    } label: {
                        Text(category.rawValue)
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                selectedCategory == category
                                    ? category.accent
                                    : Color(.secondarySystemBackground)
                            )
                            .foregroundStyle(selectedCategory == category ? .white : .primary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
    }
}
