import SwiftUI

struct Sparkline: View {
    let values: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let n = max(values.count - 1, 1)

            ZStack {
                ForEach([25.0, 50.0, 75.0], id: \.self) { y in
                    let yPos = h - h * (y / 100.0)
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: yPos))
                        p.addLine(to: CGPoint(x: w, y: yPos))
                    }
                    .stroke(.secondary.opacity(0.15), lineWidth: 1)
                }

                Path { path in
                    path.move(to: CGPoint(x: 0, y: h))
                    for (i, v) in values.enumerated() {
                        let x = w * CGFloat(i) / CGFloat(n)
                        let y = h - h * CGFloat(v / 100.0)
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                    path.addLine(to: CGPoint(x: w, y: h))
                    path.closeSubpath()
                }
                .fill(LinearGradient(
                    gradient: Gradient(colors: [color.opacity(0.4), color.opacity(0.05)]),
                    startPoint: .top,
                    endPoint: .bottom
                ))

                Path { path in
                    for (i, v) in values.enumerated() {
                        let x = w * CGFloat(i) / CGFloat(n)
                        let y = h - h * CGFloat(v / 100.0)
                        if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(color, lineWidth: 1.5)
            }
        }
    }
}
