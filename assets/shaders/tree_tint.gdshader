shader_type spatial;
// Árvores da Kenney (textura de paleta) com a copa repintada pela cor da instância do
// MultiMesh: ipês amarelos, roxos e brancos. Só os tons verdes mudam; o tronco fica igual.

uniform sampler2D colormap : source_color, filter_nearest;

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec3 base = texture(colormap, UV).rgb;
	float green = base.g - max(base.r, base.b);
	float leaf = smoothstep(0.03, 0.1, green);
	// Mantém a variação de luz da paleta (folhas claras e escuras).
	float shade = clamp(dot(base, vec3(0.3, 0.59, 0.11)) * 2.2, 0.65, 1.25);
	ALBEDO = mix(base, tint.rgb * shade, leaf);
	ROUGHNESS = 0.9;
}
