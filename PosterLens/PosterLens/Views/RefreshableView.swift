import SwiftUI

struct RefreshableView<Content: View>: View {
    var content: Content
    var onRefresh: (@escaping () -> Void) -> Void
    
    @State private var isRefreshing = false
    @State private var refreshOffset: CGFloat = 0
    @State private var animationAmount = 0.0
    
    private let threshold: CGFloat = 80
    
    init(onRefresh: @escaping (@escaping () -> Void) -> Void, @ViewBuilder content: () -> Content) {
        self.onRefresh = onRefresh
        self.content = content()
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                // The main content
                content
                    .offset(y: isRefreshing ? threshold : refreshOffset > 0 ? refreshOffset : 0)
                
                // Pull to refresh indicator
                VStack {
                    Spacer().frame(height: 8)
                    
                    if isRefreshing {
                        // Show spinner when refreshing
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(1.2)
                    } else {
                        // Show downward arrow when pulling
                        Image(systemName: "arrow.down")
                            .font(.system(size: 16, weight: .semibold))
                            .rotationEffect(.degrees(refreshOffset > threshold ? 180.0 : Double(refreshOffset) / Double(threshold) * 180.0))
                            .opacity(refreshOffset > 0 ? min(1.0, Double(refreshOffset) / Double(threshold)) : 0)
                    }
                    
                    Text(isRefreshing ? "Refreshing..." : refreshOffset > threshold ? "Release to refresh" : "Pull to refresh")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                        .opacity(refreshOffset > 0 ? min(1.0, Double(refreshOffset) / (Double(threshold) / 2.0)) : 0)
                }
                .frame(width: geometry.size.width)
                .offset(y: -40 + (isRefreshing ? threshold : refreshOffset > 0 ? refreshOffset : 0))
            }
            .offset(y: -refreshOffset)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        // Only allow pull to refresh from the top
                        guard value.location.y > 0 else { return }
                        
                        // Only if we're not already refreshing
                        guard !isRefreshing else { return }
                        
                        // Calculate offset with some resistance
                        refreshOffset = min(value.translation.height * 0.5, threshold * 1.5)
                    }
                    .onEnded { value in
                        if refreshOffset > threshold {
                            // Start refresh
                            withAnimation(.spring()) {
                                isRefreshing = true
                                refreshOffset = 0
                            }
                            
                            // Call the refresh closure
                            onRefresh {
                                // End refresh when the work is done
                                withAnimation(.spring()) {
                                    isRefreshing = false
                                }
                            }
                        } else {
                            // Reset without refreshing
                            withAnimation(.spring()) {
                                refreshOffset = 0
                            }
                        }
                    }
            )
        }
    }
}

struct RefreshableView_Previews: PreviewProvider {
    static var previews: some View {
        RefreshableView(onRefresh: { completion in
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                completion()
            }
        }) {
            ScrollView {
                VStack(spacing: 20) {
                    ForEach(0..<10) { i in
                        Text("Item \(i)")
                            .frame(maxWidth: .infinity)
                            .frame(height: 80)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(8)
                    }
                }
                .padding()
            }
        }
    }
}