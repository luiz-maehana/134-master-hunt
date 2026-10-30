shader_type spatial;
// Chão da versão web (asfalto, calçadas, gramado): cor lisa e a mancha de luz da lanterna.
// Na web não há luzes dinâmicas (cada uma obrigaria a recompilar shaders de tudo); a lanterna
// (Flashlight) passa posição, direção e abertura por uniforms globais e o chão se acende no cone.
render_mode specular_disabled;

uniform vec3 albedo : source_color = vec3(0.5);

global uniform float flash_light;
global uniform vec3 flash_light_pos;
global uniform vec3 flash_light_dir;
global uniform float flash_light_cos;
global uniform float flash_light_range;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	ALBEDO = albedo;
	ROUGHNESS = 0.95;
	vec3 to_point = world_pos - flash_light_pos;
	float distance = max(length(to_point), 0.001);
	// Borda do facho suave; mais forte no centro e perto da lanterna.
	float cone = smoothstep(flash_light_cos, mix(flash_light_cos, 1.0, 0.4), dot(to_point / distance, flash_light_dir));
	float falloff = clamp(1.0 - distance / max(flash_light_range, 0.001), 0.0, 1.0);
	EMISSION = albedo * vec3(1.0, 0.95, 0.85) * cone * falloff * falloff * flash_light * 1.4;
}
