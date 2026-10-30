// Moeda: uma malha para os seis valores (1, 5, 10, 25, 50 centavos e R$ 1).
// O valor vem do MultiMesh (INSTANCE_CUSTOM.r = índice / 10) ou, numa moeda solta, do
// parâmetro de instância `denomination_override`.
//
// Sem imagens próprias (use_atlas = false), tinge a imagem da moeda de 1 centavo com a cor de
// cada valor; a de R$ 1 ganha o anel dourado. Com use_atlas = true, cada valor tem uma linha
// no atlas (frente à esquerda, verso à direita), de cima para baixo na ordem dos índices.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float normal_scale = 0.6;
uniform float metallic = 0.75;
uniform float roughness = 0.45;
// Brilho próprio (o ciclo de dia e noite diminui à noite, para a lanterna fazer diferença).
uniform float self_glow = 0.06;
// Lanterna do jogador (Flashlight): moedas dentro do facho ganham um brilho dourado.
uniform vec3 flash_pos = vec3(0.0);
uniform vec3 flash_dir = vec3(0.0, 0.0, -1.0);
uniform float flash_cos = 0.9;
uniform float flash_range = 0.0;
uniform float flash_glint = 0.0;
varying vec3 world_pos;
uniform bool use_atlas = false;
uniform vec3 face_colors[6];
uniform vec3 ring_colors[6];
// Fração do raio onde começa o anel (R$ 1).
uniform float ring_start = 0.66;

instance uniform float denomination_override = -1.0;

varying flat int denom;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float d = denomination_override >= 0.0 ? denomination_override : INSTANCE_CUSTOM.r * 10.0;
	denom = clamp(int(round(d)), 0, 5);
}

void fragment() {
	vec2 uv = UV;
	if (use_atlas) {
		uv.y = (uv.y + float(denom)) / 6.0;
	}
	vec3 tex = texture(albedo_texture, uv).rgb;
	vec3 albedo = tex;
	if (!use_atlas && denom > 0) {
		// Imagem original (cobre) vira tons de cinza e recebe a cor do valor.
		float lum = dot(tex, vec3(0.299, 0.587, 0.114));
		vec2 center = UV.x < 0.5 ? vec2(0.25, 0.5) : vec2(0.75, 0.5);
		float r = length((UV - center) / vec2(0.25, 0.5));
		vec3 tint = r > ring_start ? ring_colors[denom] : face_colors[denom];
		albedo = tint * clamp(lum * 1.9, 0.0, 1.4);
	}
	ALBEDO = albedo;
	METALLIC = metallic;
	ROUGHNESS = roughness;
	NORMAL_MAP = texture(normal_texture, uv).rgb;
	NORMAL_MAP_DEPTH = normal_scale;
	EMISSION = albedo * self_glow;
	if (flash_glint > 0.0 && flash_range > 0.0) {
		vec3 to_coin = world_pos - flash_pos;
		float dist = length(to_coin);
		float inside = smoothstep(flash_cos, mix(flash_cos, 1.0, 0.5), dot(to_coin / max(dist, 0.001), flash_dir));
		float fade = clamp(1.0 - dist / flash_range, 0.0, 1.0);
		EMISSION += albedo * flash_glint * inside * fade * 1.6;
	}
}
