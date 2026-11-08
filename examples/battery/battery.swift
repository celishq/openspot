import Metal
import SwiftUI

/// The battery as the Mac once drew it: an outline with a nub, filled to its level with a glossy liquid in which bubbles
/// rise from the bottom. The number and the detail use the card's own type. A bolt shows while it charges.
struct SpotView: View {
    let spot: SpotInput
    @State private var start = Date()

    private static let fill = 1.0
    private static let line: CGFloat = 2
    private static let gap: CGFloat = 3

    private var level: Double { min(1, max(0, (Double(spot["title"] ?? "") ?? 0) / 100)) }
    private var isCharging: Bool { spot["state"] == "charging" }
    private var isTall: Bool { spot.size.height > 100 }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 60)) { context in
            let time = context.date.timeIntervalSince(start)
            let shown = level * (1 - pow(1 - min(time / Self.fill, 1), 3))
            Group {
                if isTall {
                    VStack(alignment: .leading, spacing: 0) {
                        words
                        Spacer(minLength: 0)
                        battery(time: time, shown: shown, height: 44)
                    }
                } else {
                    HStack(spacing: 10) {
                        words
                        battery(time: time, shown: shown, height: 26)
                    }
                }
            }
            .padding(spot.inset)
            .frame(width: spot.size.width, height: spot.size.height, alignment: .topLeading)
        }
        .foregroundStyle(spot.ink)
        .onAppear { start = Date() }
    }

    private var words: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(spot["title"].map { "\($0)%" } ?? "–").font(isTall ? spot.font.metric : spot.font.value)
            Text(spot["detail"] ?? "").font(spot.font.detail).opacity(spot.secondary)
        }
        .fixedSize()
    }

    private func battery(time: Double, shown: Double, height: CGFloat) -> some View {
        let corner = height * 0.24
        return HStack(spacing: 1.5) {
            GeometryReader { place in
                let inner = CGSize(width: place.size.width - 2 * (Self.line + Self.gap), height: place.size.height - 2 * (Self.line + Self.gap))
                ZStack {
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .strokeBorder(spot.ink.opacity(0.4), lineWidth: Self.line)
                    if let frame = Liquid.shared?.frame(size: inner, time: Float(time), level: Float(shown), isCharging: isCharging) {
                        Image(decorative: frame, scale: Liquid.scale)
                            .clipShape(RoundedRectangle(cornerRadius: corner - Self.line - Self.gap / 2, style: .continuous))
                    }
                    if isCharging {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: height * 0.5, weight: .bold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.35), radius: 1, y: 0.5)
                    }
                }
            }
            .frame(height: height)
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(spot.ink.opacity(0.4))
                .frame(width: 3.5, height: height * 0.36)
        }
    }
}

/// A Metal pipeline that draws one frame of the liquid into an image.
@MainActor
final class Liquid {
    static let shared = Liquid()
    static let scale: CGFloat = 2

    /// The shader: a full-screen triangle, and a fragment that fills the width to the level with a glossy liquid, a moving
    /// edge, and bubbles that rise from the bottom.
    private static let source = """
        #include <metal_stdlib>
        using namespace metal;

        struct Out { float4 position [[position]]; float2 uv; };
        struct Uniforms { float time; float level; float charging; float aspect; };

        vertex Out vertexMain(uint id [[vertex_id]]) {
            float2 p = float2((id << 1) & 2, id & 2);
            Out out;
            out.position = float4(p * 2 - 1, 0, 1);
            out.uv = float2(p.x, 1 - p.y);
            return out;
        }

        float hash(float n) { return fract(sin(n * 12.9898) * 43758.5453); }

        fragment float4 fragmentMain(Out in [[stage_in]], constant Uniforms &u [[buffer(0)]]) {
            float2 uv = in.uv;
            float x = uv.x * u.aspect;
            float3 red = float3(0.93, 0.22, 0.18);
            float3 amber = float3(0.98, 0.66, 0.10);
            float3 green = float3(0.30, 0.78, 0.22);
            float3 base = mix(mix(red, amber, smoothstep(0.08, 0.11, u.level)), green, smoothstep(0.18, 0.21, u.level));

            float edge = u.level * u.aspect + 0.035 * sin(uv.y * 7.0 + u.time * 2.2) + 0.02 * sin(uv.y * 13.0 - u.time * 3.4);
            float inside = smoothstep(edge + 0.02, edge - 0.02, x);

            float3 color = mix(base * 1.15, base * 0.72, smoothstep(0.15, 0.85, uv.y));
            color += float3(0.30) * smoothstep(0.62, 1.0, uv.y);
            float gloss = smoothstep(0.50, 0.08, uv.y) * smoothstep(0.0, 0.07, uv.y);
            color = mix(color, float3(1.0), gloss * 0.55);
            color += float3(0.55) * exp(-pow((x - edge) * 26.0, 2.0)) * inside;

            float bubbles = 0.0;
            float count = u.charging > 0.5 ? 16.0 : 7.0;
            for (int i = 0; i < 16; i++) {
                float n = float(i);
                if (n >= count) { break; }
                float speed = 0.35 + 0.45 * hash(n + 3.1);
                float by = 1.1 - fract(u.time * speed + hash(n + 7.7));
                float bx = hash(n + 1.3) * max(edge - 0.08, 0.0) + 0.04 + 0.03 * sin(u.time * 3.0 + n * 2.0);
                float r = 0.045 + 0.05 * hash(n + 5.9);
                float dist = length(float2((x - bx) * 1.0, uv.y - by));
                float ring = smoothstep(r, r * 0.78, dist) - smoothstep(r * 0.72, r * 0.35, dist) * 0.75;
                float shine = smoothstep(r * 0.35, 0.0, length(float2(x - bx + r * 0.35, uv.y - by + r * 0.35)));
                bubbles += (ring * 0.7 + shine * 0.8) * step(bx, edge - r);
            }
            color += bubbles * 0.6;

            float alpha = inside;
            return float4(saturate(color) * alpha, alpha);
        }
        """

    private struct Uniforms {
        var time: Float
        var level: Float
        var charging: Float
        var aspect: Float
    }

    private let device: MTLDevice
    private let queue: MTLCommandQueue
    private let pipeline: MTLRenderPipelineState
    private var texture: MTLTexture?

    private init?() {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue(),
              let library = try? device.makeLibrary(source: Self.source, options: nil)
        else { return nil }
        let description = MTLRenderPipelineDescriptor()
        description.vertexFunction = library.makeFunction(name: "vertexMain")
        description.fragmentFunction = library.makeFunction(name: "fragmentMain")
        description.colorAttachments[0].pixelFormat = .bgra8Unorm
        guard let pipeline = try? device.makeRenderPipelineState(descriptor: description) else { return nil }
        self.device = device
        self.queue = queue
        self.pipeline = pipeline
    }

    /// Draws one frame at this size in points, and returns it as an image of `scale` pixels per point.
    func frame(size: CGSize, time: Float, level: Float, isCharging: Bool) -> CGImage? {
        let width = Int(size.width * Self.scale)
        let height = Int(size.height * Self.scale)
        guard width > 0, height > 0, let target = target(width: width, height: height) else { return nil }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = target
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        pass.colorAttachments[0].storeAction = .store
        guard let buffer = queue.makeCommandBuffer(), let encoder = buffer.makeRenderCommandEncoder(descriptor: pass) else { return nil }
        var uniforms = Uniforms(time: time, level: level, charging: isCharging ? 1 : 0, aspect: Float(size.width / size.height))
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
        buffer.commit()
        buffer.waitUntilCompleted()
        return image(of: target, width: width, height: height)
    }

    private func target(width: Int, height: Int) -> MTLTexture? {
        if let texture, texture.width == width, texture.height == height { return texture }
        let description = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
        description.usage = [.renderTarget]
        description.storageMode = .shared
        texture = device.makeTexture(descriptor: description)
        return texture
    }

    private func image(of texture: MTLTexture, width: Int, height: Int) -> CGImage? {
        let row = width * 4
        var bytes = [UInt8](repeating: 0, count: row * height)
        texture.getBytes(&bytes, bytesPerRow: row, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
        guard let provider = CGDataProvider(data: Data(bytes) as CFData) else { return nil }
        let info = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: row,
                       space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: info, provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }
}
