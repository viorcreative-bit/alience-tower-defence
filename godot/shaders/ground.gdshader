// Zemin: çim, toprak yol ve surların içinde kaldırım taşı. Yol, köşe noktalarından
// hesaplanan uzaklıkla çizilir; böylece doku gerektirmez ve kenarlar yumuşak olur.
shader_type spatial;
render_mode diffuse_burley;

uniform vec2 pts[12];
uniform int count = 10;
uniform float wall_z = 4.5;
uniform vec3 grass_a : source_color = vec3(0.50, 0.62, 0.20);
uniform vec3 grass_b : source_color = vec3(0.30, 0.44, 0.13);
uniform vec3 dirt : source_color = vec3(0.82, 0.68, 0.45);
uniform vec3 dirt_edge : source_color = vec3(0.60, 0.45, 0.28);
uniform vec3 cobble : source_color = vec3(0.70, 0.64, 0.54);
uniform float board_half_w = 4.5;
// mevsim: çim rengi çarpanı (sonbaharda sarı-kızıl) ve kar örtüsü (0..1)
uniform vec3 season_tint : source_color = vec3(1.0);
uniform float snow = 0.0;

varying vec3 wpos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float seg_dist(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	float d = 1e5;
	for (int i = 0; i < count - 1; i++) {
		d = min(d, seg_dist(p, pts[i], pts[i + 1]));
	}
	float n = noise(p * 0.7) * 0.5 + noise(p * 2.3) * 0.3 + noise(p * 7.0) * 0.2;
	vec3 g = mix(grass_b, grass_a, smoothstep(0.25, 0.75, n)) * season_tint;
	// tahtanın dışı biraz daha koyu ve sisli
	float outside = smoothstep(board_half_w - 0.2, board_half_w + 1.5, abs(p.x));
	g = mix(g, g * vec3(0.8, 0.88, 0.8), outside);

	float wob = (noise(p * 5.0) - 0.5) * 0.08;
	float edge = 0.40 + wob;
	float path_m = 1.0 - smoothstep(edge - 0.03, edge + 0.02, d);
	float rim = smoothstep(edge - 0.14, edge - 0.01, d);
	vec3 dc = mix(dirt, dirt_edge, rim) * (0.88 + 0.24 * noise(p * 11.0));
	// tekerlek izleri
	float rut = smoothstep(0.03, 0.0, abs(d - 0.17)) * 0.12;
	dc *= 1.0 - rut;
	// yol kenarındaki çimin gölgesi
	g *= 1.0 - 0.25 * smoothstep(edge + 0.12, edge, d) * (1.0 - path_m);
	vec3 col = mix(g, dc, path_m);
	vec3 snow_col = vec3(0.9, 0.92, 0.96) * (0.9 + 0.1 * n);
	col = mix(col, snow_col, snow * mix(0.9, 0.5, path_m) * smoothstep(0.1, 0.5, n));

	// surların içi: kaldırım taşı
	if (p.y > wall_z + 0.3 && p.y < wall_z + 3.6 && abs(p.x) < board_half_w) {
		vec2 c = p * 3.2;
		c.x += floor(c.y) * 0.5;
		vec2 f = fract(c);
		float gap = smoothstep(0.0, 0.08, f.x) * smoothstep(1.0, 0.92, f.x) * smoothstep(0.0, 0.1, f.y) * smoothstep(1.0, 0.9, f.y);
		vec3 st = cobble * (0.82 + 0.3 * hash(floor(c)));
		col = mix(st * 0.55, st, gap);
		col = mix(col, snow_col, snow * 0.4 * (1.0 - gap * 0.5));
	}
	ALBEDO = col;
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
}
