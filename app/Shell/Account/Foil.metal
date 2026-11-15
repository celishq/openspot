#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

static float foilHash(float2 p) { return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453); }

static float foilNoise(float2 p) {
    float2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(foilHash(i), foilHash(i + float2(1, 0)), f.x), mix(foilHash(i + float2(0, 1)), foilHash(i + float2(1, 1)), f.x), f.y);
}

static float3 foilFilm(float t) { return 0.5 + 0.5 * cos(6.2831 * (t + float3(0.0, 0.33, 0.67))); }

static float3 foilLab(float3 lch) { return float3(lch.x, lch.y * cos(lch.z), lch.y * sin(lch.z)); }

static float3 foilRGB(float3 o) {
    float l = o.x + 0.3963377774 * o.y + 0.2158037573 * o.z;
    float m = o.x - 0.1055613458 * o.y - 0.0638541728 * o.z;
    float s = o.x - 0.0894841775 * o.y - 1.2914855480 * o.z;
    l = l * l * l; m = m * m * m; s = s * s * s;
    float3 lin = float3(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
                        -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
                        -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s);
    lin = clamp(lin, 0.0, 1.0);
    return mix(lin * 12.92, 1.055 * pow(lin, float3(1.0 / 2.4)) - 0.055, step(float3(0.0031308), lin));
}

static float3 foilHueMix(float3 a, float3 b, float t) {
    float turn = b.z - a.z + 3.14159;
    float d = turn - 6.28318 * floor(turn / 6.28318) - 3.14159;
    return float3(mix(a.x, b.x, t), mix(a.y, b.y, t), a.z + d * t);
}

static float foilBand(float2 q, float2 dir, float at, float width) {
    float x = (dot(q, dir) - at) / width;
    return exp(-x * x);
}

static float foilEdge(float width, float x) { return 1.0 - smoothstep(0.0, width, x); }

[[ stitchable ]] half4 foil(float2 position, half4 color, float2 size, float2 tilt, float3 seed, float3 tintA, float3 tintB,
                            float3 tintC, float angle, float2 center, float shape, float pattern, float facets, float freq) {
    float2 uv = float2(position.x / size.x, 1.0 - position.y / size.y);
    float aspect = size.x / size.y;
    float2 q = uv * float2(aspect, 1.0);
    float2 cell = floor(q * facets);
    float a = foilHash(cell + seed.xy * 10.0) * 6.2831;
    float2 facet = float2(cos(a), sin(a));
    float2 light = tilt * 2.2;
    float3 rainbow = foilFilm(dot(facet, light) + dot(q, float2(0.35, 0.2)) + seed.y);
    float flash = pow(max(0.0, dot(facet, normalize(light + float2(0.001)))), 6.0) * smoothstep(0.02, 0.3, length(light));
    float2 mid = float2(aspect, 1.0) * 0.5;
    float2 along = float2(cos(angle), sin(angle));
    float warp = (foilNoise(q * 2.2 + seed.xz * 5.0) - 0.5) * 0.35;
    float2 d = q - center;
    float g;
    if (shape < 0.5) g = dot(q - mid, along) * 0.7 + 0.5 + warp;
    else if (shape < 1.5) g = length(d) * 1.1 + warp;
    else if (shape < 2.5) g = fract(atan2(d.y, d.x) / 6.2831 + length(d) * 0.8 + angle);
    else if (shape < 3.5) g = 0.0;
    else g = 0.5 + 0.5 * sin(dot(q, along) * freq + foilNoise(q * 3.0 + seed.xy) * 2.5);
    g = clamp(g, 0.0, 1.0);
    float3 tint;
    if (shape > 2.5 && shape < 3.5) {
        float2 p1 = center, p2 = float2(mid.x * 2.0 - center.x, 1.0 - center.y), p3 = mid + along * 0.4;
        float3 w = 1.0 / (float3(dot(q - p1, q - p1), dot(q - p2, q - p2), dot(q - p3, q - p3)) + 0.04);
        w += (foilNoise(q * 3.0 + seed.yz) - 0.5) * float3(4.0);
        w = max(w, 0.0);
        tint = foilRGB((foilLab(tintA) * w.x + foilLab(tintB) * w.y + foilLab(tintC) * w.z) / (w.x + w.y + w.z));
    } else {
        float wrap = abs(fract(g * 0.999) * 2.0 - 1.0);
        float t = shape > 1.5 && shape < 2.5 ? wrap : g;
        tint = foilRGB(foilLab(t < 0.5 ? foilHueMix(tintA, tintB, t * 2.0) : foilHueMix(tintB, tintC, t * 2.0 - 1.0)));
    }
    bool isDark = (tintA.x + tintB.x + tintC.x) / 3.0 < 0.55;
    float lines = 0.0;
    float r = length(q - mid), th = atan2(q.y - mid.y, q.x - mid.x);
    if (pattern > 0.5 && pattern < 1.5) lines = foilEdge(0.08, abs(sin(r * 60.0 + sin(th * 12.0 + angle) * 1.6))) * 0.55 + foilEdge(0.08, abs(sin(r * 60.0 - sin(th * 9.0) * 1.6))) * 0.45;
    else if (pattern > 1.5 && pattern < 2.5) lines = foilEdge(0.12, abs(sin(length(d) * 70.0)));
    else if (pattern > 2.5 && pattern < 3.5) lines = foilEdge(0.1, abs(sin(dot(q, float2(-along.y, along.x)) * 160.0)));
    else if (pattern > 3.5) lines = foilEdge(0.06, abs(fract(foilNoise(q * 2.4 + seed.xz * 3.0) * 9.0) - 0.5) - 0.45);
    tint = mix(tint, tint * (isDark ? 1.6 : 0.55), lines * 0.45);
    float dark = 1.0 - smoothstep(0.0, 0.35, dot(tint, float3(0.333)));
    float3 metal = tint + (foilNoise(q * 60.0) - 0.5) * 0.06;
    float2 dir = normalize(float2(0.8, 0.6));
    float spec = foilBand(q, dir, 0.6 + light.x * 0.9 - light.y * 0.6, 0.3);
    float3 shine = mix(float3(1.0), tint * 1.4, 0.35);
    float3 own = mix(tint * 1.25 + 0.08, rainbow, 0.25);
    float3 c = mix(metal, own, 0.45 * flash * spec) + spec * shine * mix(0.22, 0.14, dark);
    c *= 0.82 + 0.18 * uv.y;
    return half4(half3(c), 1.0h) * color.a;
}
