shader_type spatial;
// Greybox farm ground: soft cartoon grass, dirt paths and colored reserve pads.
// Vertex color: R = path mask, G = pad mask. WebGL2-safe (no compute, no extensions).

uniform vec3 grass_color : source_color = vec3(0.34, 0.60, 0.22);
uniform vec3 grass_alt_color : source_color = vec3(0.29, 0.54, 0.19);
uniform vec3 path_color : source_color = vec3(0.60, 0.42, 0.25);
uniform vec3 pad_color : source_color = vec3(0.78, 0.62, 0.36);
uniform float grid_size = 1.0;
uniform float grid_strength = 0.06;

varying vec3 world_pos;
varying vec4 vertex_mask;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vertex_mask = COLOR;
}

void fragment() {
	float path = smoothstep(0.35, 0.65, vertex_mask.r);
	float pad = smoothstep(0.35, 0.65, vertex_mask.g);
	float patch_mix = 0.5 + 0.5 * sin(world_pos.x * 0.21) * sin(world_pos.z * 0.17);
	vec3 color = mix(grass_color, grass_alt_color, patch_mix);
	color = mix(color, path_color, path);
	color = mix(color, pad_color, pad);

	vec2 coord = world_pos.xz / grid_size;
	vec2 fw = max(fwidth(coord), vec2(0.0001));
	vec2 grid = abs(fract(coord - 0.5) - 0.5) / fw;
	float line = 1.0 - min(min(grid.x, grid.y), 1.0);
	line *= 1.0 - smoothstep(0.25, 0.5, max(fw.x, fw.y));  // fade the grid with distance
	ALBEDO = color * (1.0 - grid_strength * line);
	ROUGHNESS = 1.0;
}
