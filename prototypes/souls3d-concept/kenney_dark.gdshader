// PROTOTYPE - NOT FOR PRODUCTION
// Makes the bright Kenney kit pieces fit a dark world: their own colour (palette texture or flat colour) is
// desaturated and darkened, then broken up by a world-space triplanar stone texture and its normal map.
shader_type spatial;

uniform sampler2D colormap : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_map = true;
uniform bool use_vcolor = false;  // flat-coloured kits: the colour comes per vertex (sRGB)
uniform vec4 base_color : source_color = vec4(1.0);
uniform sampler2D grit : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D grit_n : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float tile = 0.35;
uniform float desat = 0.55;
uniform float dark = 0.62;
uniform vec3 tint = vec3(0.92, 0.9, 0.95);

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 c = use_map ? texture(colormap, UV).rgb : (use_vcolor ? pow(COLOR.rgb, vec3(2.2)) : base_color.rgb);
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(l), desat) * dark * tint;
	// triplanar: pick the projection the surface faces most
	vec3 n = abs(wnorm);
	vec2 uv = n.y > max(n.x, n.z) ? wpos.xz : (n.x > n.z ? wpos.zy : wpos.xy);
	uv *= tile;
	vec3 g = texture(grit, uv).rgb;
	float gl = dot(g, vec3(0.333));
	ALBEDO = c * mix(0.55, 1.45, gl);
	NORMAL_MAP = texture(grit_n, uv).rgb;
	NORMAL_MAP_DEPTH = 0.8;
	ROUGHNESS = 0.9;
}
