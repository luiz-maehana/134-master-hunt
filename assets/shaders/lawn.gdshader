shader_type spatial;
// Gramado da Esplanada, todo calculado (sem textura): manchas grandes de verde e amarelado,
// as faixas de corte ao longo do eixo e um granulado fino perto da câmera. Barato: um punhado de
// operações por pixel, em coordenadas de mundo (não estica com a escala das lajes).

uniform vec3 grass_light : source_color = vec3(0.42, 0.6, 0.28);
uniform vec3 grass_dark : source_color = vec3(0.3, 0.47, 0.22);
uniform vec3 grass_dry : source_color = vec3(0.55, 0.56, 0.3);
// Largura das faixas de corte (m) e quanto elas aparecem.
uniform float stripe_width = 6.0;
uniform float stripe_strength = 0.12;
// Distância em que o granulado fino some (evita cintilar longe).
uniform float speckle_fade = 40.0;

varying vec3 world_pos;

// Hash sem seno (estável com coordenadas grandes do mundo; Dave Hoskins).
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// Ruído de valor suave (4 amostras).
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float patches = noise(p * 0.035) * 0.65 + noise(p * 0.11) * 0.35;
	vec3 color = mix(grass_dark, grass_light, smoothstep(0.1, 0.9, patches));
	color = mix(color, grass_dry, smoothstep(0.72, 0.95, noise(p * 0.02 + 17.0)) * 0.6);
	// Faixas de corte: alternam claro e escuro ao longo do eixo (z).
	float stripe = step(0.5, fract(p.y / (stripe_width * 2.0)));
	color *= 1.0 + (stripe - 0.5) * 2.0 * stripe_strength;
	// Granulado fino, só perto.
	float near = 1.0 - smoothstep(speckle_fade * 0.5, speckle_fade, length(world_pos - CAMERA_POSITION_WORLD));
	color *= 1.0 + (noise(p * 3.0) - 0.5) * 0.2 * near;
	ALBEDO = color;
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
}
