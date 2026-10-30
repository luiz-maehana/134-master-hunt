shader_type spatial;
// Fachada procedural dos prédios (caixas unitárias escaladas num MultiMesh): andares,
// janelas com moldura e vidro, térreo de loja com toldo pintado e faixa escura no topo.
// A cor da parede vem da cor da instância. Tudo em coordenadas de mundo, então janelas
// têm o mesmo tamanho em qualquer prédio.

uniform float floor_height = 3.2;
uniform float window_spacing = 2.6;
uniform float ground_floor = 4.0;
uniform vec3 glass_color : source_color = vec3(0.2, 0.3, 0.38);
uniform vec3 frame_color : source_color = vec3(0.86, 0.84, 0.8);
uniform vec3 shop_color : source_color = vec3(0.16, 0.2, 0.24);
// 0 = dia, 1 = noite (DayNight): parte das janelas e vitrines acende.
uniform float night = 0.0;
// Força o modo ministério numa peça solta (torres do Congresso), sem cor por vértice.
instance uniform bool ministry_mode = false;

varying vec3 world_pos;
varying vec3 world_normal;
varying float base_y;
varying float top_y;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	// Caixa unitária centrada: base e topo do prédio em y de mundo.
	vec3 center = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float half_height = length(MODEL_MATRIX[1].xyz) * 0.5;
	base_y = center.y - half_height;
	top_y = center.y + half_height;
}

void fragment() {
	vec3 wall = COLOR.rgb;
	vec3 albedo = wall;
	float rough = 0.9;
	float metal = 0.0;
	vec3 emit = vec3(0.0);
	bool ministry = COLOR.a < 0.75 || ministry_mode;
	if (ministry && abs(world_normal.y) < 0.5) {
		// Ministério: pontas (viradas para o eixo, em z) brancas e cegas; fachadas compridas de
		// vidro verde em faixas contínuas; térreo recuado sobre pilotis.
		float h = world_pos.y - base_y;
		if (h < 4.0) {
			albedo = vec3(0.18, 0.2, 0.2);
		} else if (abs(world_normal.z) > 0.5) {
			albedo = wall;
		} else {
			float fv = fract((h - 4.0) / floor_height);
			float cu = fract(world_pos.z / 1.6);
			float r = hash(vec2(floor(world_pos.z / 1.6), floor((h - 4.0) / floor_height) + base_y));
			albedo = mix(vec3(0.16, 0.34, 0.3), vec3(0.3, 0.5, 0.45), r);
			if (fv < 0.12 || cu < 0.06) {
				albedo = vec3(0.75, 0.78, 0.76);
			}
			rough = 0.15;
			metal = 0.35;
			emit = vec3(1.0, 0.85, 0.55) * step(0.6, fract(r * 11.0)) * night * 0.8;
		}
	} else if (abs(world_normal.y) < 0.5) {
		// Coordenada horizontal ao longo da fachada.
		float u = abs(world_normal.x) > 0.5 ? world_pos.z : world_pos.x;
		float h = world_pos.y - base_y;
		float from_top = top_y - world_pos.y;
		float column = floor(u / window_spacing);
		float cu = fract(u / window_spacing);
		if (h < ground_floor) {
			// Térreo: vitrines largas, faixa de toldo e base escura.
			float shop_cell = floor(u / 6.0);
			float su = fract(u / 6.0);
			float tint = hash(vec2(shop_cell, base_y));
			if (h < 0.35) {
				albedo = wall * 0.55;
			} else if (h > ground_floor - 0.9) {
				vec3 awning = mix(vec3(0.75, 0.22, 0.18), vec3(0.2, 0.45, 0.65), step(0.5, tint));
				awning = mix(awning, vec3(0.85, 0.65, 0.2), step(0.8, tint));
				float stripe = step(0.5, fract(u * 1.2));
				albedo = mix(awning, awning * 0.75, stripe * 0.6);
			} else if (su > 0.08 && su < 0.92 && h > 0.6) {
				albedo = shop_color;
				emit = vec3(1.0, 0.8, 0.5) * step(0.65, tint) * night * 0.3;
				rough = 0.15;
				metal = 0.4;
			} else {
				albedo = wall * 0.85;
			}
		} else if (from_top < 0.6) {
			// Platibanda no topo.
			albedo = wall * 0.78;
		} else {
			float level = floor((h - ground_floor) / floor_height);
			float fv = fract((h - ground_floor) / floor_height);
			float pane = step(0.18, cu) * step(cu, 0.82) * step(0.22, fv) * step(fv, 0.82);
			float frame = step(0.13, cu) * step(cu, 0.87) * step(0.17, fv) * step(fv, 0.87);
			// Faixa entre andares e peitoril.
			if (fv < 0.06) {
				albedo = wall * 0.82;
			}
			if (frame > 0.5) {
				albedo = frame_color;
			}
			if (pane > 0.5) {
				float r = hash(vec2(column, level + base_y * 7.0));
				// Algumas janelas com cortina clara, outras mais escuras.
				vec3 glass = glass_color * mix(0.75, 1.25, r);
				if (r > 0.86) {
					glass = vec3(0.78, 0.72, 0.6);
				}
				// À noite, umas janelas acesas (amareladas), outras apagadas.
				emit = mix(vec3(1.0, 0.82, 0.5), vec3(0.75, 0.85, 1.0), step(0.9, fract(r * 7.0))) * step(0.55, fract(r * 13.0)) * night * 1.2;
				// Reflexo do céu mais forte no alto da janela.
				glass = mix(glass, vec3(0.55, 0.68, 0.82), smoothstep(0.5, 0.82, fv) * 0.35);
				albedo = glass;
				rough = 0.12;
				metal = 0.3;
			}
		}
	} else if (world_normal.y > 0.5) {
		albedo = wall * 0.6;
	}
	ALBEDO = albedo;
	ROUGHNESS = rough;
	METALLIC = metal;
	EMISSION = emit;
}
