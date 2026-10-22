// PROTOTYPE - NOT FOR PRODUCTION
// Map module: ground splat for the Vale de Lume.
// Layers: grass (base), forest floor, dirt road, rock (slopes, triplanar), river mud, lake sand, tilled field.
// ctrl (2 m/texel): r = forest floor, g = wet mud, b = sand, a = tilled field. paths (1 m/texel): r = road.
// Anti-tiling: grass and forest are sampled at two scales and mixed with a macro noise; colours are graded
// toward the warm, painterly palette of the Quaternius kits.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D ctrl : filter_linear, repeat_disable;
uniform sampler2D paths : filter_linear, repeat_disable;
uniform sampler2D macro : filter_linear_mipmap, repeat_enable;
uniform sampler2D t_grass : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D t_forest : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D t_dirt : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D t_rock : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D t_mud : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D t_sand : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D n_grass : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D n_dirt : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D n_rock : hint_normal, filter_linear_mipmap, repeat_enable;

uniform vec3 grass_lush : source_color = vec3(0.30, 0.46, 0.15);
uniform vec3 grass_dry : source_color = vec3(0.56, 0.54, 0.27);
uniform vec3 forest_tint : source_color = vec3(0.55, 0.50, 0.32);
uniform vec3 dirt_tint : source_color = vec3(0.80, 0.64, 0.46);
uniform vec3 rock_tint : source_color = vec3(0.56, 0.50, 0.45);
uniform vec3 field_tint : source_color = vec3(0.55, 0.40, 0.27);

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float lum(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

// keep the texture's detail (luminance) but take the hue from a painted tint
vec3 grade(vec3 tex, vec3 tint, float amount) {
	float l = lum(tex);
	vec3 painted = tint * (0.55 + l * 0.9);
	return mix(tex, painted, amount);
}

void fragment() {
	vec2 w = wpos.xz;
	vec4 m = texture(macro, w * 0.0035);          // ~285 m pattern
	vec4 m2 = texture(macro, w * 0.021 + 0.37);    // ~48 m pattern
	vec4 c = texture(ctrl, UV);
	float road = texture(paths, UV).r;

	// grass: two scales, macro mixed, lush to dry
	vec3 g1 = texture(t_grass, w * 0.23).rgb;
	vec3 g2 = texture(t_grass, w * 0.061 + 0.5).rgb;
	vec3 grass_tex = mix(g1, g2, 0.35 + 0.3 * m2.r);
	float dryness = smoothstep(0.35, 0.75, m.g * 0.8 + m2.b * 0.35);
	vec3 gtint = mix(grass_lush, grass_dry, dryness * 0.75);
	vec3 col = grade(grass_tex, gtint, 0.82);
	col *= 0.9 + 0.2 * m2.g;

	// forest floor
	vec3 f1 = texture(t_forest, w * 0.19).rgb;
	vec3 f2 = texture(t_forest, w * 0.057 + 0.21).rgb;
	vec3 forest = grade(mix(f1, f2, 0.4), forest_tint, 0.35) * 0.95;
	float fw = smoothstep(0.25, 0.75, c.r + (m2.r - 0.5) * 0.5);
	col = mix(col, forest, fw);

	// tilled field (rows run along x)
	vec3 soil = grade(texture(t_mud, w * 0.2).rgb, field_tint, 0.6);
	float rows = 0.75 + 0.25 * sin(w.y * 3.1416 * 1.4);
	col = mix(col, soil * rows, smoothstep(0.3, 0.7, c.a));

	// mud along the river banks
	vec3 mud = grade(texture(t_mud, w * 0.27).rgb, vec3(0.45, 0.40, 0.27), 0.35);
	col = mix(col, mud, smoothstep(0.3, 0.8, c.g + (m2.g - 0.5) * 0.4));

	// sand on the lake shore
	vec3 sand = grade(texture(t_sand, w * 0.22).rgb, vec3(0.82, 0.74, 0.58), 0.5);
	col = mix(col, sand, smoothstep(0.35, 0.75, c.b + (m2.b - 0.5) * 0.3));

	// dirt roads with ragged grassy edges
	vec3 dirt = grade(texture(t_dirt, w * 0.25).rgb, dirt_tint, 0.45);
	dirt = mix(dirt, dirt * 0.82, smoothstep(0.4, 0.9, texture(t_dirt, w * 0.05).r));
	float edge = (texture(macro, w * 0.18).r - 0.5) * 0.7;
	float rw = smoothstep(0.35, 0.65, road + edge);
	col = mix(col, dirt, rw);

	// rock on slopes: triplanar
	vec3 an = abs(wnrm);
	vec3 bw = pow(an, vec3(4.0));
	bw /= (bw.x + bw.y + bw.z);
	vec3 rx = texture(t_rock, wpos.zy * 0.11).rgb;
	vec3 ry = texture(t_rock, wpos.xz * 0.11).rgb;
	vec3 rz = texture(t_rock, wpos.xy * 0.11).rgb;
	vec3 rock = rx * bw.x + ry * bw.y + rz * bw.z;
	rock = grade(rock, rock_tint, 0.55) * (0.85 + 0.25 * m2.r);
	float slope = 1.0 - wnrm.y;
	float rk = smoothstep(0.24, 0.42, slope + (m2.g - 0.5) * 0.18);
	col = mix(col, rock, rk);

	// macro brightness breakup so wide fields never look stamped
	col *= 0.88 + 0.24 * m.r;
	ALBEDO = col;
	ROUGHNESS = mix(0.95, 0.8, rk);
	SPECULAR = 0.25;

	vec3 ng = texture(n_grass, w * 0.23).rgb;
	vec3 nd = texture(n_dirt, w * 0.25).rgb;
	vec3 nr = texture(n_rock, wpos.xz * 0.11).rgb;
	vec3 nn = mix(ng, nd, rw);
	nn = mix(nn, nr, rk * 0.6);
	NORMAL_MAP = nn;
	NORMAL_MAP_DEPTH = 0.8;
}
