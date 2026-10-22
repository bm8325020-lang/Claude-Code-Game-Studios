// PROTOTYPE - NOT FOR PRODUCTION
// KayKit Medieval Hexagon pieces with the kit's lime grass painted a fresher green (the village). One texture read.
shader_type spatial;

uniform sampler2D atlas : source_color, filter_linear_mipmap;
uniform vec4 grass : source_color = vec4(0.3, 0.58, 0.2, 1.0);

void fragment() {
	vec3 c = texture(atlas, UV).rgb;
	// the kit's grass is yellow-green: red and green both well above blue, red not above green
	float lime = smoothstep(0.08, 0.2, min(c.r, c.g) - c.b * 1.2) * step(c.r, c.g * 1.25);
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	ALBEDO = mix(c, grass.rgb * (0.45 + 0.7 * l), lime);
	ROUGHNESS = 0.9;
}
