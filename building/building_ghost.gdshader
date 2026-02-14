shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_always;

uniform vec4 base_color : source_color = vec4(0.0, 0.6, 1.0, 0.4);
uniform float scan_speed : hint_range(0.1, 5.0) = 1.6;
uniform float scan_width : hint_range(0.01, 1.0) = 0.15;
uniform float grid_pixel_size : hint_range(0.01, 1.0) = 0.5;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// 1. BASE COLOR
	vec3 final_color = base_color.rgb;
	float alpha = base_color.a;
	
	// 2. SCANLINE PULSE
	// Moving up in world space
	float scan_line = mod(world_pos.y - (TIME * scan_speed), 4.0);
	float scan_impact = smoothstep(4.0 - scan_width, 4.0, scan_line) * 0.8;
	final_color += base_color.rgb * scan_impact * 2.0;
	alpha += scan_impact * 0.3;
	
	// 3. GRID PATTERN
	// Subtle world-space grid
	vec3 grid_pos = world_pos / grid_pixel_size;
	vec3 grid_dist = abs(fract(grid_pos - 0.5) - 0.5) / fwidth(grid_pos);
	float grid_line = min(min(grid_dist.x, grid_dist.y), grid_dist.z);
	float grid_mask = 1.0 - smoothstep(0.0, 1.0, grid_line);
	
	final_color += base_color.rgb * grid_mask * 0.2;
	alpha += grid_mask * 0.1;

	// 4. EDGE GLOW (Fresnel-like but simpler for unshaded)
	float fresnel = 1.0 - dot(NORMAL, VIEW);
	fresnel = pow(fresnel, 3.0);
	final_color += base_color.rgb * fresnel * 0.5;
	alpha += fresnel * 0.2;

	ALBEDO = final_color;
	ALPHA = clamp(alpha, 0.0, 1.0);
}
