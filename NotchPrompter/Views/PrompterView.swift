import SwiftUI

struct PrompterView: View {
    @ObservedObject var engine: PrompterEngine
    @State private var showSpeedBadge = false
    @State private var badgeTask: Task<Void, Never>?

    private let cornerRadius: CGFloat = 16
    private let fontSize: CGFloat = 34
    private let horizontalPadding: CGFloat = 24

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                Color.black
                if engine.text.isEmpty {
                    placeholder
                } else {
                    scrollingText(viewportHeight: geo.size.height)
                        .opacity(engine.isPlaying ? 1 : 0.6)
                    fades
                }
                speedBadge
            }
        }
        .clipShape(UnevenRoundedRectangle(
            bottomLeadingRadius: cornerRadius,
            bottomTrailingRadius: cornerRadius
        ))
        .onChange(of: engine.speed) { _, _ in flashSpeedBadge() }
    }

    private var placeholder: some View {
        Text("Escribe tu guion desde el menú")
            .font(.system(size: 18))
            .foregroundStyle(.gray)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func scrollingText(viewportHeight: CGFloat) -> some View {
        Text(engine.text)
            .font(.system(size: fontSize, weight: .medium))
            .lineSpacing(fontSize * 0.3)
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, horizontalPadding)
            .padding(.top, viewportHeight)
            .background(
                GeometryReader { textGeo in
                    Color.clear.onAppear { engine.contentHeight = textGeo.size.height }
                        .onChange(of: textGeo.size.height) { _, h in engine.contentHeight = h }
                }
            )
            .offset(y: -engine.offset)
    }

    private var fades: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [.black, .black.opacity(0)], startPoint: .top, endPoint: .bottom)
                .frame(height: 28)
            Spacer()
            LinearGradient(colors: [.black.opacity(0), .black], startPoint: .top, endPoint: .bottom)
                .frame(height: 44)
        }
        .allowsHitTesting(false)
    }

    private var speedBadge: some View {
        HStack {
            Spacer()
            VStack {
                Spacer()
                Text("\(Int(engine.speed))")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.15), in: Capsule())
                    .padding(8)
                    .opacity(showSpeedBadge ? 1 : 0)
                    .animation(.easeOut(duration: 0.2), value: showSpeedBadge)
            }
        }
    }

    private func flashSpeedBadge() {
        badgeTask?.cancel()
        showSpeedBadge = true
        badgeTask = Task {
            try? await Task.sleep(for: .seconds(1))
            if !Task.isCancelled { showSpeedBadge = false }
        }
    }
}
