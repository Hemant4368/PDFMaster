import SwiftUI

import SwiftUI

struct MainTabView: View {
    
    @State private var selectedTab: Tab = .files
    @State private var showScanner = false
    
    enum Tab {
        case files
        case tools
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                
                // MARK: - Content
                //            NavigationStack {
                Group {
                    switch selectedTab {
                        
                    case .files:
                        HomeView(showScanner: $showScanner)
                    case .tools:
                        ToolsView(showScanner: $showScanner)
                    }
                    
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.bottom, 60)
                .navigationTitle("PDF Scanner")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItemGroup(placement: .topBarLeading) {
                        
                        NavigationLink(destination: SettingsView()) {
                            Image(systemName: "gear")
                            
                        }
                    }
                }
                //            }
                
                
                
                // MARK: - Custom Tab Bar
                
                VStack(spacing: 0) {
                    
                    Divider()
                    
                    HStack {
                        
                        // LEFT TAB
                        
                        Button {
                            selectedTab = .files
                        } label: {
                            
                            VStack(spacing: 4) {
                                
                                Image(systemName: "doc.text.fill")
                                    .font(.system(size: 22))
                                
                                Text("My Files")
                                    .font(.caption2)
                            }
                            .foregroundStyle(
                                selectedTab == .files
                                ? AppTheme.primary
                                : .gray
                            )
                            .frame(maxWidth: .infinity)
                        }
                        
                        
                        // SPACE FOR CENTER BUTTON
                        
                        Spacer()
                            .frame(width: 80)
                        
                        
                        // RIGHT TAB
                        
                        Button {
                            selectedTab = .tools
                        } label: {
                            
                            VStack(spacing: 4) {
                                
                                Image(systemName: "square.grid.2x2.fill")
                                    .font(.system(size: 22))
                                
                                Text("Tools")
                                    .font(.caption2)
                            }
                            .foregroundStyle(
                                selectedTab == .tools
                                ? AppTheme.primary
                                : .gray
                            )
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                }
                
                
                // MARK: - CENTER FLOATING BUTTON
                
                Button {
                    showScanner = true
                } label: {
                    
                    ZStack {
                        
                        Circle()
                            .fill(AppTheme.redGradient)
                            .frame(width: 74, height: 74)
                        
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .shadow(
                        color: AppTheme.primary.opacity(0.35),
                        radius: 12,
                        y: 8
                    )
                }
                .offset(y: -20)
            }
            .ignoresSafeArea(.keyboard)
            .fullScreenCover(isPresented: $showScanner) {
                ScannerFlowView()
            }
        }
    }
}


#Preview {
    MainTabView()
}
