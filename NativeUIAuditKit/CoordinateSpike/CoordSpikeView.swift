import SwiftUI

// Declared ground truth (points, top-left origin, portrait):
//   Button:    x=40  y=100  w=200  h=44
//   TextField: x=40  y=164  w=280  h=44
//   Label:     x=40  y=228  w=200  h=30
//
// Expected pixel coordinates: multiply by UIScreen.main.scale (2.0 or 3.0).
// See NativeUIAuditKit/Research/CoordinateSpike.md for measurement protocol.

struct CoordSpikeView: View {
    @State private var textInput = ""
    @State private var frames: [String: CGRect] = [:]

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.white.ignoresSafeArea()

            Button("Primary Button") {}
                .frame(width: 200, height: 44)
                .background(Color.blue.opacity(0.15))
                .border(Color.blue, width: 1)
                .accessibilityIdentifier("coord_spike_button")
                .offset(x: 40, y: 100)
                .background(frameReader(id: "button"))

            TextField("Text Field", text: $textInput)
                .frame(width: 280, height: 44)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("coord_spike_textfield")
                .offset(x: 40, y: 164)
                .background(frameReader(id: "textfield"))

            Text("Static Label")
                .frame(width: 200, height: 30, alignment: .leading)
                .accessibilityIdentifier("coord_spike_label")
                .offset(x: 40, y: 228)
                .background(frameReader(id: "label"))

            // Frame readout overlay for visual verification in previews.
            VStack(alignment: .leading, spacing: 4) {
                ForEach(frames.sorted(by: { $0.key < $1.key }), id: \.key) { key, rect in
                    Text("\(key): \(Int(rect.minX)),\(Int(rect.minY)) \(Int(rect.width))×\(Int(rect.height))")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            .padding(8)
            .offset(x: 8, y: 320)
        }
        .coordinateSpace(name: "global")
        .onPreferenceChange(CoordSpikeFramePreference.self) { frames in
            self.frames = frames
        }
    }

    private func frameReader(id: String) -> some View {
        GeometryReader { proxy in
            Color.clear
                .preference(
                    key: CoordSpikeFramePreference.self,
                    value: [id: proxy.frame(in: .global)]
                )
        }
    }
}

private struct CoordSpikeFramePreference: PreferenceKey {
    static let defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

#Preview {
    CoordSpikeView()
}
