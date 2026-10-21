// PROTOTYPE - NOT FOR PRODUCTION
// Island ground: muddy leaves, sand near the sea, rock on steep slopes (world-space tiling).
shader_type spatial;

uniform sampler2D mud : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D mud_n : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_n : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D sand : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D sand_n : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float tile = 0.22;

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = NORMAL;
}

void fragment() {
	vec2 uv = wpos.xz * tile;
	vec2 uvr = (abs(wnorm.x) > abs(wnorm.z) ? wpos.zy : wpos.xy) * tile;
	float r = smoothstep(0.22, 0.42, 1.0 - wnorm.y);
	float s = 1.0 - smoothstep(-1.0, 0.8, wpos.y);
	vec3 c = mix(texture(mud, uv).rgb, texture(sand, uv).rgb * 0.8, s);
	c = mix(c, texture(rock, uvr).rgb, r);
	ALBEDO = c * 0.7;
	NORMAL_MAP = mix(mix(texture(mud_n, uv).rgb, texture(sand_n, uv).rgb, s), texture(rock_n, uvr).rgb, r);
	ROUGHNESS = 0.95;
}
