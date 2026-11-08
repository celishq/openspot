import Metal
import SwiftUI

/// The battery as a liquid that fills the card to its level, with waves on its top and bubbles while it charges.
struct SpotView: View {
    let spot: SpotInput
    @State private var start = Date()

    private var level: Double { (Double(spot["title"] ?? "") ?? 0) / 100 }
    private var isCharging: Bool { spot["state"] == "charging" }

    var body: some View {
        TimelineView(.animation) { context in
            let time = Float(context.date.timeIntervalSince(start))
            ZStack(alignment: .topLeading) {
                if let frame = Liquid.shared?.frame(size: spot.size, time: time, level: Float(level), isCharging: isCharging) {
                    Image(decorative: frame, scale: Liquid.scale)
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text(spot["title"].map { "\($0)%" } ?? "–")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    Text(spot["detail"] ?? "")
                        .font(spot.font.detail)
                        .opacity(spot.secondary)
                }
                .foregroundStyle(spot.ink)
                .padding(spot.inset)
            }
        }
    }
}

/// A Metal pipeline that draws one frame of the liquid into an image.
@MainActor
final class Liquid {
    static let shared = Liquid()
    static let scale: CGFloat = 2

    /// The shader: a full-screen triangle, and a fragment that draws two waves, a lit surface and rising bubbles.
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

        float wave(float x, float t, float level, float a, float f, float s, float phase) {
            return 1 - level + a * sin(x * f + t * s + phase);
        }

        fragment float4 fragmentMain(Out in [[stage_in]], constant Uniforms &u [[buffer(0)]]) {
            float2 uv = in.uv;
            float x = uv.x * u.aspect;
            float3 red = float3(1.0, 0.30, 0.26);
            float3 amber = float3(1.0, 0.70, 0.18);
            float3 green = float3(0.20, 0.82, 0.45);
            float3 base = mix(mix(red, amber, smoothstep(0.10, 0.30, u.level)), green, smoothstep(0.35, 0.60, u.level));

            float front = wave(x, u.time, u.level, 0.022, 6.0, 2.2, 0.0) + 0.012 * sin(x * 13.0 - u.time * 3.1);
            float back = wave(x, u.time, u.level, 0.030, 4.5, -1.6, 1.3);
            float depth = uv.y - front;
            float inFront = smoothstep(0.0, 0.012, depth);
            float inBack = smoothstep(0.0, 0.012, uv.y - back);

            float3 color = mix(base * 1.10, base * 0.62, saturate(depth * 1.4));
            float rim = exp(-abs(depth) * 140.0) * inFront;

            float bubbles = 0.0;
            if (u.charging > 0.5) {
                for (int i = 0; i < 14; i++) {
                    float n = float(i);
                    float bx = fract(sin(n * 12.9898) * 43758.5453) * u.aspect;
                    float speed = 0.12 + 0.22 * fract(sin(n * 78.233) * 12345.678);
                    float by = 1.0 - fract(u.time * speed + n * 0.37);
                    float r = 0.010 + 0.014 * fract(n * 0.618);
                    float d = length(float2(x - bx + 0.01 * sin(u.time * 3.0 + n), uv.y - by));
                    bubbles += smoothstep(r, r * 0.4, d) * step(front, by);
                }
            }

            float alpha = max(inFront * 0.92, inBack * 0.35);
            float3 lit = (inFront > 0.0 ? color : base) + rim * 0.55 + bubbles * 0.45;
            return float4(lit * alpha, alpha);
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
