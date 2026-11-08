import Metal
import SwiftUI

/// The battery as a lit liquid. On show it fills from empty and sloshes until it settles, its number counts up with it, and
/// the number turns white where the liquid covers it. While it charges, bubbles rise and burst at the top.
struct SpotView: View {
    let spot: SpotInput
    @State private var start = Date()

    private static let fill = 1.4

    private var level: Double { min(1, max(0, (Double(spot["title"] ?? "") ?? 0) / 100)) }
    private var isCharging: Bool { spot["state"] == "charging" }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 60)) { context in
            let time = context.date.timeIntervalSince(start)
            let progress = 1 - pow(1 - min(time / Self.fill, 1), 3)
            let shown = level * progress
            let frame = Liquid.shared?.frame(size: spot.size, time: Float(time), level: Float(shown), slosh: Float(exp(-time * 1.6)), isCharging: isCharging)
            ZStack(alignment: .topLeading) {
                if let frame {
                    Image(decorative: frame, scale: Liquid.scale)
                    label(shown).foregroundStyle(spot.ink)
                    label(shown).foregroundStyle(.white).mask(Image(decorative: frame, scale: Liquid.scale))
                } else {
                    label(shown).foregroundStyle(spot.ink)
                }
            }
        }
        .onAppear { start = Date() }
    }

    private func label(_ shown: Double) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(spot["title"] == nil ? "–" : "\(Int((shown * 100).rounded()))%")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text(spot["detail"] ?? "")
                .font(spot.font.detail)
                .opacity(spot.secondary)
        }
        .padding(spot.inset)
        .frame(width: spot.size.width, height: spot.size.height, alignment: .topLeading)
    }
}

/// A Metal pipeline that draws one frame of the liquid into an image.
@MainActor
final class Liquid {
    static let shared = Liquid()
    static let scale: CGFloat = 2

    /// The shader: a full-screen triangle, and a fragment that draws a back wave, a lit front wave with caustics, a glow
    /// above the surface and bubbles.
    private static let source = """
        #include <metal_stdlib>
        using namespace metal;

        struct Out { float4 position [[position]]; float2 uv; };
        struct Uniforms { float time; float level; float charging; float aspect; float slosh; };

        vertex Out vertexMain(uint id [[vertex_id]]) {
            float2 p = float2((id << 1) & 2, id & 2);
            Out out;
            out.position = float4(p * 2 - 1, 0, 1);
            out.uv = float2(p.x, 1 - p.y);
            return out;
        }

        float surface(float x, float t, float level, float slosh, float phase) {
            float a = 0.010 + 0.05 * slosh;
            return 1 - level
                + a * sin(x * 4.6 + t * 1.9 + phase)
                + a * 0.55 * sin(x * 8.7 - t * 2.6 + 1.7 + phase)
                + 0.07 * slosh * sin(x * 2.1 - t * 6.0);
        }

        float caustics(float2 p, float t) {
            float c = 0.0;
            for (int i = 0; i < 3; i++) {
                p += 0.55 * sin(p.yx * 1.4 + t * 0.7 + float(i));
                c += sin(p.x + p.y);
            }
            return pow(saturate(0.5 + 0.5 * sin(c * 1.2 + t * 0.8)), 8.0);
        }

        fragment float4 fragmentMain(Out in [[stage_in]], constant Uniforms &u [[buffer(0)]]) {
            float2 uv = in.uv;
            float x = uv.x * u.aspect;
            float3 red = float3(1.00, 0.33, 0.30);
            float3 amber = float3(1.00, 0.72, 0.24);
            float3 green = float3(0.24, 0.86, 0.54);
            float3 base = mix(mix(red, amber, smoothstep(0.10, 0.30, u.level)), green, smoothstep(0.35, 0.60, u.level));

            float front = surface(x, u.time, u.level, u.slosh, 0.0);
            float back = surface(x, u.time * 0.8, u.level, u.slosh, 2.4) - 0.012;
            float d = uv.y - front;
            float inFront = smoothstep(-0.003, 0.003, d);
            float inBack = smoothstep(-0.003, 0.003, uv.y - back) * 0.28;

            float deep = smoothstep(0.0, 0.9, d);
            float3 color = mix(base * 1.08, base * 0.52, deep);
            color += base * caustics(float2(x, uv.y) * 5.0, u.time) * 0.16 * (1.0 - deep);
            float line = exp(-pow(d * 120.0, 2.0));
            float glow = d < 0.0 ? exp(d * 26.0) * 0.16 : 0.0;

            float bubbles = 0.0;
            if (u.charging > 0.5) {
                for (int i = 0; i < 12; i++) {
                    float n = float(i);
                    float speed = 0.10 + 0.16 * fract(sin(n * 78.233) * 12345.678);
                    float by = 1.0 - fract(u.time * speed + n * 0.41);
                    float bx = fract(sin(n * 12.9898) * 43758.5453) * u.aspect + 0.012 * sin(u.time * 2.4 + n * 3.0);
                    float r = 0.008 + 0.012 * fract(n * 0.618);
                    float dist = length(float2(x - bx, uv.y - by));
                    float rim = smoothstep(r, r * 0.8, dist) - smoothstep(r * 0.7, r * 0.45, dist) * 0.7;
                    bubbles += rim * step(front + r, by);
                }
            }

            float alpha = max(inFront * 0.94, inBack) + line * 0.55 + glow;
            float3 lit = color + line * 0.8 + bubbles * 0.6;
            float3 shown = inFront > 0.01 ? lit : base * (1.0 + line);
            return float4(shown * saturate(alpha), saturate(alpha));
        }
        """

    private struct Uniforms {
        var time: Float
        var level: Float
        var charging: Float
        var aspect: Float
        var slosh: Float
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
    func frame(size: CGSize, time: Float, level: Float, slosh: Float, isCharging: Bool) -> CGImage? {
        let width = Int(size.width * Self.scale)
        let height = Int(size.height * Self.scale)
        guard width > 0, height > 0, let target = target(width: width, height: height) else { return nil }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = target
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        pass.colorAttachments[0].storeAction = .store
        guard let buffer = queue.makeCommandBuffer(), let encoder = buffer.makeRenderCommandEncoder(descriptor: pass) else { return nil }
        var uniforms = Uniforms(time: time, level: level, charging: isCharging ? 1 : 0, aspect: Float(size.width / size.height), slosh: slosh)
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
