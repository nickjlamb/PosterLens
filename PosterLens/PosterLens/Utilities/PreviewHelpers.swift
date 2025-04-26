import SwiftUI

/// Helper struct for creating Binding in SwiftUI previews
/// This allows preview providers to create and modify state without needing a full view hierarchy
public struct StateWrapper<Value, Content: View>: View {
    @State var value: Value
    let content: (Binding<Value>) -> Content
    
    public init(initialValue: Value, content: @escaping (Binding<Value>) -> Content) {
        self._value = State(initialValue: initialValue)
        self.content = content
    }
    
    public var body: some View {
        content($value)
    }
}
