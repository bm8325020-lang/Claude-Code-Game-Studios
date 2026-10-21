// PROTOTYPE - NOT FOR PRODUCTION
// Ground of the open world, painted, no textures: the biome colour comes per vertex from world.gd (grass, forest
// floor, autumn leaves, snow, desert sand, beach), rock shows on steep slopes, roads are light dirt (vertex alpha).
// The far horizon mesh uses the same shader with a hole where the detailed chunks are.
shader_type spatial;

uniform vec4 rock_color : source_color = vec4(0.6, 0.54, 0.47, 1.0);
uniform vec4 road_color : source_color = vec4(0.8, 0.66, 0.45, 1.0);
uniform vec4 hole = vec4(1.0, 1.0, 0.0, 0.0);  // x/z min, x/z max of the area drawn by the detailed chunks (empty: none)

varying vec3 wpos;
varying vec4 vcol;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vcol = COLOR;
}

void fragment() {
	if (wpos.x > hole.x && wpos.x < hole.z && wpos.z > hole.y && wpos.z < hole.w) {
		discard;
	}
	// two scales of patches: meadows read as grass with lighter and darker tufts, not as a flat colour
	float n = vnoise(wpos.xz * 0.08) * 0.6 + vnoise(wpos.xz * 0.6) * 0.4;
	vec3 c = pow(vcol.rgb, vec3(2.2)) * (0.85 + 0.3 * n);
	// rock where the ground is steep: the face's own normal (from screen derivatives), so cliffs read as rock even
	// where the smoothed vertex normals still lean upward
	vec3 fn = normalize(cross(dFdy(wpos), dFdx(wpos)));
	float r = smoothstep(0.25, 0.45, 1.0 - abs(fn.y));
	c = mix(c, rock_color.rgb * (0.85 + 0.3 * vnoise(wpos.xz * 0.3 + wpos.y * 0.5)), r);
	c = mix(c, road_color.rgb * (0.9 + 0.2 * n), vcol.a * (1.0 - r));
	ALBEDO = c;
	ROUGHNESS = 0.95;
}
