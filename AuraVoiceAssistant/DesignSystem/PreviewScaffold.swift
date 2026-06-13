import SwiftUI

struct PreviewScaffold<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            MeshBackground()
            content
        }
    }
}
