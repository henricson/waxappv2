import SwiftUI

struct MagnifyingGlass<Content: View>: View {
  var size: CGFloat
  var scale: CGFloat
  var cornerRadius: CGFloat
  var location: CGPoint
  var coordinateSpace: AnyHashable
  @ViewBuilder var content: Content

  init(
    size: CGFloat = 120,
    scale: CGFloat = 2.0,
    cornerRadius: CGFloat = 16,
    location: CGPoint,
    coordinateSpace: AnyHashable = "magnify-space",
    @ViewBuilder content: () -> Content
  ) {
    self.size = size
    self.scale = scale
    self.cornerRadius = cornerRadius
    self.location = location
    self.coordinateSpace = coordinateSpace
    self.content = content()
  }

  // Lens overlay simulating optical glass
  private var lensOverlay: some View {
    let r = cornerRadius
    return ZStack {
      // Edge vignette (darker rim)
      RoundedRectangle(cornerRadius: r, style: .continuous)
        .fill(
          RadialGradient(
            colors: [Color.black.opacity(0.20), Color.black.opacity(0.05), .clear],
            center: .center,
            startRadius: max(1, size * 0.35),
            endRadius: size * 0.65
          )
        )
        .blendMode(.multiply)

      // Inner shadow via overlay stroke with blur and offset
      RoundedRectangle(cornerRadius: r, style: .continuous)
        .stroke(Color.black.opacity(0.18), lineWidth: 1.0)
        .blur(radius: 1.2)
        .offset(y: 0.5)
        .mask(
          RoundedRectangle(cornerRadius: r, style: .continuous)
            .fill(LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom))
        )
        .blendMode(.multiply)

      // Specular highlight streak
      RoundedRectangle(cornerRadius: r, style: .continuous)
        .stroke(
          LinearGradient(
            colors: [Color.white.opacity(0.75), Color.white.opacity(0.0)], startPoint: .topLeading,
            endPoint: .bottomTrailing),
          lineWidth: 3
        )
        .blur(radius: 1.2)
        .opacity(0.55)

      // Subtle chromatic ring (very faint)
      RoundedRectangle(cornerRadius: r, style: .continuous)
        .strokeBorder(
          AngularGradient(
            gradient: Gradient(colors: [
              Color.red.opacity(0.12),
              Color.green.opacity(0.12),
              Color.blue.opacity(0.12),
              Color.red.opacity(0.12),
            ]),
            center: .center
          ),
          lineWidth: 1.0
        )
        .blendMode(.screen)
        .opacity(0.35)

      // Faint glass tint fill
      RoundedRectangle(cornerRadius: r, style: .continuous)
        .fill(Color.white.opacity(0.05))
        .blendMode(.softLight)
    }
  }

  var body: some View {
    GeometryReader { proxy in
      // Read the frame in the named coordinate space for consistent math
      let sourceFrame = proxy.frame(in: .named(coordinateSpace))
      let half = size / 2

      ZStack {
        content
          .scaleEffect(scale, anchor: .topLeading)
          .offset(
            x: -(location.x - sourceFrame.minX) * (scale - 1)
              - (location.x - sourceFrame.minX - half),
            y: -(location.y - sourceFrame.minY) * (scale - 1)
              - (location.y - sourceFrame.minY - half)
          )
          .compositingGroup()

        // Optical lens overlay
        lensOverlay
      }
      .frame(width: size, height: size)
      .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
      .overlay {
        // Polished rim
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .stroke(
            LinearGradient(
              colors: [Color.white.opacity(0.85), Color.white.opacity(0.35)],
              startPoint: .topLeading, endPoint: .bottomTrailing),
            lineWidth: 1
          )
          .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 1)
      }
    }
    .frame(width: size, height: size)
  }
}

#Preview {
  struct DemoMagnify: View {
    @State private var location: CGPoint = CGPoint(x: 180, y: 260)

    var body: some View {
      GeometryReader { proxy in
        let frame = proxy.frame(in: .named("magnify-space"))

        // Shared background for consistency
        let background = Image("post-introduction-background")
          .resizable()
          .scaledToFill()
          .ignoresSafeArea()

        ZStack {
          background
            .gesture(
              DragGesture(minimumDistance: 0)
                .onChanged { value in
                  let x = min(max(value.location.x, frame.minX), frame.maxX)
                  let y = min(max(value.location.y, frame.minY), frame.maxY)
                  location = CGPoint(x: x, y: y)
                }
            )

          MagnifyingGlass(
            size: 170, scale: 5, cornerRadius: 26, location: location,
            coordinateSpace: "magnify-space"
          ) {
            background
          }
          .position(location)
          .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 6)  // soft drop shadow under the lens
        }
        .clipped()
        .coordinateSpace(name: "magnify-space")
      }
    }
  }

  return DemoMagnify()
}
