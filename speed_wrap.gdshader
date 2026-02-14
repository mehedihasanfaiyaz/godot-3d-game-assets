shader_type canvas_item;

uniform float speed_intensity : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

// Stable noise function
float random(vec2 uv) {
    return fract(sin(dot(uv.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

void fragment() {
    vec2 uv = SCREEN_UV;
    vec2 center = vec2(0.5, 0.5);
    vec2 to_center = uv - center;
    float dist = length(to_center);
    
    // 1. High-Quality Radial Blur
    vec3 col = vec3(0.0);
    const float samples = 12.0; 
    float strength = speed_intensity * 0.08;
    
    // Simple Chromatic Aberration
    float chroma = speed_intensity * 0.01 * dist;
    
    for(float i = 0.0; i < samples; i++) {
        // Dithered sampling to hide banding
        float jitter = random(uv + vec2(i, TIME * 0.1)) * 0.05;
        float t = (i + jitter) / samples;
        float scale = 1.0 - t * strength * dist;
        
        vec2 sample_uv = center + to_center * scale;
        
        col.r += texture(screen_texture, sample_uv + normalize(to_center) * chroma).r;
        col.g += texture(screen_texture, sample_uv).g;
        col.b += texture(screen_texture, sample_uv - normalize(to_center) * chroma).b;
    }
    col /= samples;
    
    // 2. Simple Vignette
    float vignette = smoothstep(0.3, 0.9, dist);
    col *= mix(1.0, 0.7, vignette * speed_intensity);
    
    // 3. Subtle Cyan Boost Flash
    vec3 boost_color = vec3(0.0, 0.5, 1.0);
    col = mix(col, col + boost_color * 0.2, vignette * speed_intensity);
    
    COLOR = vec4(col, 1.0);
}
