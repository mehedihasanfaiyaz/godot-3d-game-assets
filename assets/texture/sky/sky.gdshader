shader_type sky;

uniform vec3 sky_color : source_color = vec3(0.3, 0.6, 1.0);
uniform vec3 horizon_color : source_color = vec3(0.5, 0.8, 1.0);
uniform vec3 ground_color : source_color = vec3(0.1, 0.1, 0.1);

uniform float cloud_density : hint_range(0.0, 1.0) = 0.5;
uniform float cloud_scale : hint_range(0.1, 10.0) = 1.0;
uniform float cloud_speed : hint_range(0.0, 1.0) = 0.1;
uniform vec3 cloud_color : source_color = vec3(1.0, 1.0, 1.0);

// Simple noise function for clouds
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i + vec2(0.0, 0.0)), hash(i + vec2(1.0, 0.0)), u.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    vec2 shift = vec2(100.0);
    for (int i = 0; i < 5; ++i) {
        v += a * noise(p);
        p = p * 2.0 + shift;
        a *= 0.5;
    }
    return v;
}

void sky() {
    float v_dist = EYEDIR.y;
    vec3 base_sky = mix(horizon_color, sky_color, clamp(v_dist * 2.0, 0.0, 1.0));
    if (v_dist < 0.0) {
        base_sky = mix(horizon_color, ground_color, clamp(-v_dist * 5.0, 0.0, 1.0));
    }

    // Clouds
    if (EYEDIR.y > 0.0) {
        vec2 sky_uv = EYEDIR.xz / (EYEDIR.y + 0.1);
        sky_uv *= cloud_scale;
        sky_uv += TIME * cloud_speed;
        
        float cloud_noise = fbm(sky_uv);
        float cloud_mask = smoothstep(1.0 - cloud_density, 1.0, cloud_noise);
        
        base_sky = mix(base_sky, cloud_color, cloud_mask * 0.8);
    }

    COLOR = base_sky;
}
