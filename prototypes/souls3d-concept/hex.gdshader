// PROTOTYPE - NOT FOR PRODUCTION
// KayKit Medieval Hexagon pieces (one shared colour atlas) with the biome painted over the kit's lime grass and
// leaves: deeper green forests, orange autumn woods, snow, desert sand. recolor.a = 0 keeps the kit's own colours.
// Compatibility renderer; one texture read.
shader_type spatial;

uniform sampler2D atlas : source_color, filter_linear_mipmap;
uniform vec4 recolor : source_color = vec4(1.0, 1.0, 1.0, 0.0);
uniform float saturation = 1.1;
uniform bool leaves = false;  // decor: recolour the trees' leaves instead of the grass

void fragment() {
	vec3 c = texture(atlas, UV).rgb;
	// the kit's grass and leaves are yellow-green: red and green well above blue
	float lime = smoothstep(0.08, 0.2, min(c.r, c.g) - c.b * 1.2) * step(c.r, c.g * 1.25);
	if (leaves) {  // tree foliage is a bluer green: green well above red and blue
		lime = smoothstep(0.05, 0.15, c.g - max(c.r, c.b));
	}
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 painted = recolor.rgb * (0.6 + 1.1 * l);
	c = mix(c, painted, lime * recolor.a);
	l = dot(c, vec3(0.299, 0.587, 0.114));
	ALBEDO = mix(vec3(l), c, saturation);
	ROUGHNESS = 0.9;
}
