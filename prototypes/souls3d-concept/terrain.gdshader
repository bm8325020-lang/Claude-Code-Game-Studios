// PROTOTYPE - NOT FOR PRODUCTION
// Ground: muddy leaves, sand below sand_level, rock on steep slopes (world-space tiling).
shader_type spatial;

uniform sampler2D mud : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D mud_n : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_n : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D sand : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D sand_n : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D road : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D road_n : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float tile = 0.22;
uniform float sand_level = -1.0;

varying vec3 wpos;
varying vec3 wnorm;
varying float road_mask;  // vertex colour red: 1 on roads and town streets (world.gd)

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = NORMAL;
	road_mask = COLOR.r;
}

void fragment() {
	vec2 uv = wpos.xz * tile;
	vec2 uvr = (abs(wnorm.x) > abs(wnorm.z) ? wpos.zy : wpos.xy) * tile;
	float r = smoothstep(0.22, 0.42, 1.0 - wnorm.y);
	float s = 1.0 - smoothstep(sand_level, sand_level + 1.8, wpos.y);
	vec3 c = mix(texture(mud, uv).rgb, texture(sand, uv).rgb * 0.8, s);
	c = mix(c, texture(rock, uvr).rgb, r);
	vec2 uvd = wpos.xz * tile * 1.6;
	c = mix(c, texture(road, uvd).rgb * 0.75, road_mask * (1.0 - r));
	ALBEDO = c * 0.7;
	NORMAL_MAP = mix(mix(mix(texture(mud_n, uv).rgb, texture(sand_n, uv).rgb, s), texture(road_n, uvd).rgb, road_mask * (1.0 - r)), texture(rock_n, uvr).rgb, r);
	ROUGHNESS = 0.95;
}
