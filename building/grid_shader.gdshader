shader_type spatial;

uniform vec4 grid_color : source_color = vec4(0.0, 0.8, 1.0, 0.2);
uniform float grid_size = 4.0;
uniform float line_width = 0.1;

varying vec3 world_pos;

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    float line_4 = 4.0;
    float line_1 = 1.0;
    float line_05 = 0.5;
    float line_025 = 0.25;
    
    // World anchored coordinates (horizontal plane)
    vec2 pos = world_pos.xz;
    
    // Major Grid (4m) - Anchored to 2.0 offset to match factory centers
    vec2 g4 = fract((pos - 2.0) / line_4);
    float d4 = min(min(g4.x, 1.0 - g4.x), min(g4.y, 1.0 - g4.y)) * line_4;
    float m4 = 1.0 - smoothstep(0.0, line_width, d4);
    
    // Mid Grid (1m)
    vec2 g1 = fract(pos / line_1);
    float d1 = min(min(g1.x, 1.0 - g1.x), min(g1.y, 1.0 - g1.y)) * line_1;
    float m1 = 1.0 - smoothstep(0.0, line_width * 0.6, d1);
    
    // Minor Grid (0.5m)
    vec2 g05 = fract(pos / line_05);
    float d05 = min(min(g05.x, 1.0 - g05.x), min(g05.y, 1.0 - g05.y)) * line_05;
    float m05 = 1.0 - smoothstep(0.0, line_width * 0.4, d05);
    
    // Fine Grid (0.25m)
    vec2 g025 = fract(pos / line_025);
    float d025 = min(min(g025.x, 1.0 - g025.x), min(g025.y, 1.0 - g025.y)) * line_025;
    float m025 = 1.0 - smoothstep(0.0, line_width * 0.2, d025);
    
    // Blend layers with increasing transparency
    float a = (m4 * grid_color.a) + (m1 * grid_color.a * 0.4) + (m05 * grid_color.a * 0.2) + (m025 * grid_color.a * 0.1);
    
    ALBEDO = grid_color.rgb;
    ALPHA = clamp(a, 0.0, 1.0);
}
