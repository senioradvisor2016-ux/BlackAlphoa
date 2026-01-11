import SwiftUI

struct KnobControl: View
{
    let title: String
    let min: Int
    let max: Int
    @Binding var value: Int

    private let sensitivity: Double = 0.35 // px -> value scaling

    var body: some View
    {
        VStack(alignment: .leading, spacing: 6)
        {
            HStack
            {
                Text(title)
                    .font(.subheadline)
                Spacer()
                Text("\(value)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10)
            {
                ZStack
                {
                    Circle()
                        .fill(.regularMaterial)
                        .overlay(
                            Circle().strokeBorder(.black.opacity(0.25), lineWidth: 1)
                        )

                    // Indicator
                    GeometryReader { geo in
                        let size = min(geo.size.width, geo.size.height)
                        let radius = size * 0.38
                        let angle = angleForValue(value)
                        Path { p in
                            p.move(to: CGPoint(x: geo.size.width/2, y: geo.size.height/2))
                            p.addLine(to: CGPoint(
                                x: geo.size.width/2 + cos(angle) * radius,
                                y: geo.size.height/2 + sin(angle) * radius
                            ))
                        }
                        .stroke(.orange.opacity(0.85), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                    }
                    .padding(10)
                }
                .frame(width: 56, height: 56)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { g in
                            let delta = -Double(g.translation.height) * sensitivity
                            let newV = Int((Double(value) + delta).rounded())
                            value = Swift.min(max, Swift.max(min, newV))
                        }
                )

                // Fine adjust stepper (still useful and precise)
                Stepper("", value: $value, in: min...max)
                    .labelsHidden()

                Spacer()
            }
        }
        .padding(10)
        .background(.thinMaterial)
        .cornerRadius(10)
    }

    private func angleForValue(_ v: Int) -> Double
    {
        // Map min..max to -135deg..135deg
        let t = (Double(v - min) / Double(max - min))
        let start = -Double.pi * 0.75
        let end = Double.pi * 0.75
        return start + t * (end - start)
    }
}

