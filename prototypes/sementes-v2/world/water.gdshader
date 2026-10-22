// PROTOTYPE - NOT FOR PRODUCTION
// Map module: stylized water for the river and the Lago Manso (Compatibility renderer, no screen textures).
// Depth comes baked in COLOR.r (water depth in metres / 4), so shallow edges fade and foam without a depth buffer.
// UV.x runs along the flow (metres), UV.y across; flow_speed 0 for the lake.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D wave_noise : filter_linear_mipmap, repeat_enable;
uniform vec3 shallow : source_color = vec3(0.34, 0.62, 0.58);
uniform vec3 deep : source_color = vec3(0.07, 0.22, 0.30);
uniform vec3 foam_col : source_color = vec3(0.95, 0.93, 0.85);
uniform float flow_speed = 0.6;
uniform float wave_height = 0.04;
uniform float foam_width = 0.12;

varying float depth;
varying vec2 wxz;

void vertex() {
	depth = COLOR.r * 4.0;
	wxz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	float t = TIME;
	VERTEX.y += (sin(wxz.x * 0.35 + t * 1.1) + sin(wxz.y * 0.27 - t * 0.8)) * wave_height * clamp(depth, 0.0, 1.0);
}

void fragment() {
	float t = TIME;
	vec2 flow = vec2(UV.x - t * flow_speed, UV.y);
	// two scrolling noise layers drive the ripple normals
	vec2 uv1 = (flow_speed > 0.0) ? flow * 0.11 : wxz * 0.045 + vec2(t * 0.012, t * 0.007);
	vec2 uv2 = (flow_speed > 0.0) ? vec2(UV.x - t * flow_speed * 1.6, UV.y) * 0.23 + 0.5 : wxz * 0.09 - vec2(t * 0.009, -t * 0.015);
	float a = texture(wave_noise, uv1).r;
	float b = texture(wave_noise, uv2).r;
	float ax = texture(wave_noise, uv1 + vec2(0.01, 0.0)).r;
	float az = texture(wave_noise, uv1 + vec2(0.0, 0.01)).r;
	vec3 n = normalize(vec3((a - ax) * 6.0 + (b - 0.5) * 0.3, 1.0, (a - az) * 6.0 + (b - 0.5) * 0.3));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);

	float d = clamp(depth / 2.6, 0.0, 1.0);
	vec3 col = mix(shallow, deep, smoothstep(0.0, 1.0, d));
	// soft foam bands at the shore that breathe with the noise
	float f = 1.0 - smoothstep(0.0, foam_width + 0.08 * b, depth * 0.25 - 0.02 * sin(t * 1.3 + wxz.x * 0.4));
	float speck = smoothstep(0.62, 0.72, b * 0.6 + a * 0.5);
	float foam = clamp(f * (0.55 + 0.45 * speck), 0.0, 1.0);
	// stream streaks in the river
	float streak = smoothstep(0.72, 0.85, texture(wave_noise, vec2(flow.x * 0.05, flow.y * 0.6)).r) * step(0.01, flow_speed) * 0.35;
	col = mix(col, foam_col, max(foam, streak));
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	col = mix(col, vec3(0.75, 0.80, 0.82), fres * 0.45);
	ALBEDO = col;
	ROUGHNESS = mix(0.06, 0.6, foam);
	SPECULAR = 0.6;
	ALPHA = clamp(mix(0.25, 0.92, smoothstep(0.0, 1.2, depth)) + foam * 0.6 + fres * 0.2, 0.0, 1.0);
}
