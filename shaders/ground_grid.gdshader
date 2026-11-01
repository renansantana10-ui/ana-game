shader_type spatial;
// Placeholder ground: flat color with a 1 m grid so movement is readable. WebGL2-safe.

uniform vec3 base_color : source_color = vec3(0.38, 0.62, 0.32);
uniform vec3 line_color : source_color = vec3(0.30, 0.52, 0.26);
uniform float cell_size = 1.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 coord = world_pos.xz / cell_size;
	vec2 grid = abs(fract(coord - 0.5) - 0.5) / max(fwidth(coord), vec2(0.0001));
	float line = 1.0 - min(min(grid.x, grid.y), 1.0);
	ALBEDO = mix(base_color, line_color, line);
	ROUGHNESS = 1.0;
}
