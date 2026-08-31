import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "hand.wave.fill").font(.system(size: 48))
            Text("MyApp").font(.title.bold())
        }
        .padding()
    }
}

#Preview { ContentView() }
