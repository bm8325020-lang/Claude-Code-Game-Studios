// PROTOTYPE - NOT FOR PRODUCTION
// Painted look for the level's own blocks and modelled pieces: one clean colour with a soft world-space wobble
// (no stone or brick texture), and an optional second colour on faces that look up (grass on rocks, moss on walls).
// Compatibility renderer, cheap enough for phones: no texture reads.
shader_type spatial;

uniform vec4 color : source_color = vec4(0.85, 0.8, 0.7, 1.0);
uniform vec4 top_color : source_color = vec4(0.85, 0.8, 0.7, 1.0);
uniform float top_amount = 0.0;  // 0: no top colour, 1: every up-facing face
uniform float wobble = 0.12;  // how much the colour varies across a surface
uniform float scale = 0.3;  // size of the colour patches (1 / metres)
uniform float roughness_value = 0.85;

varying vec3 wpos;
varying vec3 wnorm;

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
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// project the noise on the plane the face looks along, so walls and floors both get patches
	vec3 an = abs(wnorm);
	vec2 p = an.y > max(an.x, an.z) ? wpos.xz : (an.x > an.z ? wpos.zy : wpos.xy);
	float n = vnoise(p * scale) * 0.65 + vnoise(p * scale * 4.0) * 0.35;
	vec3 c = color.rgb * (1.0 - wobble + 2.0 * wobble * n);
	float up = smoothstep(0.55, 0.8, wnorm.y) * top_amount * smoothstep(0.3, 0.6, vnoise(wpos.xz * 0.5) + 0.3);
	ALBEDO = mix(c, top_color.rgb * (0.9 + 0.2 * n), up);
	ROUGHNESS = roughness_value;
}
