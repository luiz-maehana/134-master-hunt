shader_type spatial;
// Disco do portal: redemoinho roxo e ciano girando. `active` = 0 deixa o disco apagado
// (cinza e quase transparente) enquanto o jogador não tem o contrato.
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;

instance uniform float active = 1.0;
uniform vec3 color_a : source_color = vec3(0.55, 0.3, 1.0);
uniform vec3 color_b : source_color = vec3(0.3, 0.9, 1.0);

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float angle = atan(p.y, p.x);
	float swirl = sin(angle * 3.0 + r * 9.0 - TIME * 3.0 * active) * 0.5 + 0.5;
	float rim = smoothstep(0.7, 0.98, r) * (1.0 - smoothstep(0.98, 1.0, r));
	float inside = 1.0 - smoothstep(0.96, 1.0, r);
	vec3 lit = mix(color_a, color_b, swirl) * (0.7 + 0.6 * swirl) + vec3(rim);
	vec3 off = vec3(0.14, 0.14, 0.17) + vec3(0.05) * swirl;
	ALBEDO = mix(off, lit, active);
	ALPHA = inside * mix(0.45, 0.9, active);
}
