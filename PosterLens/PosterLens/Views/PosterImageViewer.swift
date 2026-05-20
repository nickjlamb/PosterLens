import SwiftUI

struct PosterImageViewer: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var dismissDrag: CGSize = .zero

    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 5.0
    private let doubleTapScale: CGFloat = 2.5
    private let dismissThreshold: CGFloat = 120

    var body: some View {
        ZStack {
            Color.black
                .opacity(backgroundOpacity)
                .ignoresSafeArea()

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .offset(
                    x: offset.width + dismissDrag.width,
                    y: offset.height + dismissDrag.height
                )
                .gesture(magnification)
                .simultaneousGesture(panOrDismiss)
                .onTapGesture(count: 2, perform: handleDoubleTap)

            VStack {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 8)
                }
                Spacer()
            }
        }
        .statusBarHidden()
    }

    private var backgroundOpacity: Double {
        let dismissProgress = min(abs(dismissDrag.height) / 300, 0.6)
        return 1.0 - dismissProgress
    }

    private var magnification: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = min(max(lastScale * value, minScale * 0.85), maxScale)
            }
            .onEnded { _ in
                withAnimation(.spring(response: 0.3)) {
                    if scale < minScale {
                        scale = minScale
                        offset = .zero
                        lastOffset = .zero
                    }
                }
                lastScale = scale
            }
    }

    private var panOrDismiss: some Gesture {
        DragGesture()
            .onChanged { value in
                if scale > 1.01 {
                    offset = CGSize(
                        width: lastOffset.width + value.translation.width,
                        height: lastOffset.height + value.translation.height
                    )
                } else {
                    dismissDrag = value.translation
                }
            }
            .onEnded { value in
                if scale > 1.01 {
                    lastOffset = offset
                } else if abs(value.translation.height) > dismissThreshold {
                    dismiss()
                } else {
                    withAnimation(.spring(response: 0.3)) {
                        dismissDrag = .zero
                    }
                }
            }
    }

    private func handleDoubleTap() {
        HapticManager.shared.mediumImpact()
        withAnimation(.spring(response: 0.35)) {
            if scale > 1.01 {
                scale = 1.0
                offset = .zero
                lastOffset = .zero
                lastScale = 1.0
            } else {
                scale = doubleTapScale
                lastScale = doubleTapScale
            }
        }
    }
}
