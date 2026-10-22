// PROTOTYPE - NOT FOR PRODUCTION
// Kenney kit pieces in their own bright colours (palette texture, flat colour or vertex colour), a little more
// saturated, with a soft world-space colour wobble so big flat faces do not look plastic.
shader_type spatial;

uniform sampler2D colormap : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_map = true;
uniform bool use_vcolor = false;  // flat-coloured kits: the colour comes per vertex (sRGB)
uniform vec4 base_color : source_color = vec4(1.0);
uniform float saturation = 1.2;
uniform float bright = 1.0;
uniform vec3 tint = vec3(1.0);

varying vec3 wpos;

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
}

void fragment() {
	vec3 c = use_map ? texture(colormap, UV).rgb : (use_vcolor ? pow(COLOR.rgb, vec3(2.2)) : base_color.rgb);
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = max(mix(vec3(l), c, saturation), vec3(0.0)) * bright * tint;
	float n = vnoise(wpos.xz * 0.35 + wpos.y * 0.2) * 0.6 + vnoise(wpos.xz * 1.7) * 0.4;
	ALBEDO = c * mix(0.88, 1.1, n);
	ROUGHNESS = 0.85;
}
