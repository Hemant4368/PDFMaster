import SwiftUI

struct ToolsView: View {
    @Binding var showScanner: Bool
    @State private var selectedTool: PDFTool?

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(PDFTool.allCases) { tool in
                    Button {
                        if tool == .scanner { showScanner = true } else { selectedTool = tool }
                    } label: {
                        ToolCard(tool: tool)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationDestination(item: $selectedTool) { tool in
            ToolRouterView(tool: tool)
        }
        
    }
}
