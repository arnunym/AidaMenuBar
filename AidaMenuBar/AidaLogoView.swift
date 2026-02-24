import SwiftUI

/// AIDA Pyramid Logo rendered from the official SVG favicon
/// Original SVG viewBox: 0 0 24 24, fill: #004583
struct AidaLogoView: View {
    var size: CGFloat = 24
    var color: Color = Color(red: 0, green: 0.271, blue: 0.514) // #004583
    
    var body: some View {
        Canvas { context, canvasSize in
            let scale = canvasSize.width / 24.0
            
            // Bottom tier (widest)
            let bottom = Path { p in
                p.move(to: CGPoint(x: 22.33 * scale, y: 19.2586 * scale))
                p.addLine(to: CGPoint(x: 2.0 * scale, y: 19.2586 * scale))
                p.addLine(to: CGPoint(x: 4.97553 * scale, y: 14.4778 * scale))
                p.addLine(to: CGPoint(x: 19.3502 * scale, y: 14.4778 * scale))
                p.closeSubpath()
                
                // Inner cutout shape
                p.move(to: CGPoint(x: 8.06256 * scale, y: 19.0591 * scale))
                p.addLine(to: CGPoint(x: 9.12664 * scale, y: 14.6689 * scale))
                p.addLine(to: CGPoint(x: 5.08751 * scale, y: 14.6705 * scale))
                p.addLine(to: CGPoint(x: 2.34268 * scale, y: 19.0627 * scale))
                p.closeSubpath()
            }
            
            // Middle tier
            let middle = Path { p in
                p.move(to: CGPoint(x: 18.4471 * scale, y: 13.0559 * scale))
                p.addLine(to: CGPoint(x: 5.86981 * scale, y: 13.0627 * scale))
                p.addLine(to: CGPoint(x: 8.88288 * scale, y: 8.23553 * scale))
                p.addLine(to: CGPoint(x: 15.4418 * scale, y: 8.23553 * scale))
                p.closeSubpath()
                
                p.move(to: CGPoint(x: 9.57508 * scale, y: 12.8601 * scale))
                p.addLine(to: CGPoint(x: 10.6543 * scale, y: 8.43554 * scale))
                p.addLine(to: CGPoint(x: 8.98705 * scale, y: 8.43345 * scale))
                p.addLine(to: CGPoint(x: 6.22711 * scale, y: 12.8538 * scale))
                p.closeSubpath()
            }
            
            // Top tier (peak)
            let top = Path { p in
                p.move(to: CGPoint(x: 14.5767 * scale, y: 6.85527 * scale))
                p.addLine(to: CGPoint(x: 9.74646 * scale, y: 6.85891 * scale))
                p.addLine(to: CGPoint(x: 12.1679 * scale, y: 3.0 * scale))
                p.closeSubpath()
                
                p.move(to: CGPoint(x: 11.0965 * scale, y: 6.65474 * scale))
                p.addLine(to: CGPoint(x: 11.6882 * scale, y: 4.14689 * scale))
                p.addLine(to: CGPoint(x: 10.1006 * scale, y: 6.66203 * scale))
                p.closeSubpath()
            }
            
            context.fill(bottom, with: .color(color))
            context.fill(middle, with: .color(color))
            context.fill(top, with: .color(color))
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    HStack(spacing: 20) {
        AidaLogoView(size: 24)
        AidaLogoView(size: 32)
        AidaLogoView(size: 48, color: .orange)
    }
    .padding()
}
