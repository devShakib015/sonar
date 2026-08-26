import SwiftUI
struct ToolPlaceholder: View {
    let title: String
    var body: some View {
        VStack { Text(title).font(.largeTitle) }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle(title)
    }
}
