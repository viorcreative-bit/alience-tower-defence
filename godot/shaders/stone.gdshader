// Taş duvar: dünya konumundan yontma taş sıraları, harç çizgileri ve taş başına renk farkı.
// Yan yüzlerde sıralı taş, üst yüzlerde döşeme taşı. Doku dosyası gerektirmez.
shader_type spatial;
render_mode diffuse_burley;

uniform vec3 base : source_color = vec3(0.80, 0.73, 0.60);
uniform vec3 mortar : source_color = vec3(0.52, 0.47, 0.40);
uniform vec2 brick = vec2(0.16, 0.075);
uniform float vary = 0.16;

varying vec3 wpos;
varying vec3 wnrm;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = abs(wnrm);
	vec2 uv;
	vec2 b = brick;
	if (n.y > 0.6) {
		uv = wpos.xz;
		b = vec2(brick.x, brick.x * 0.8);
	} else {
		// yatay koordinat: yüzün yönüne göre x ya da z; silindirlerde ikisinin karışımı
		float h = n.x > n.z ? wpos.z * sign(wnrm.x) : -wpos.x * sign(wnrm.z);
		uv = vec2(h, wpos.y);
	}
	float row = floor(uv.y / b.y);
	uv.x += mod(row, 2.0) * b.x * 0.5;
	vec2 cell = floor(uv / b);
	vec2 f = fract(uv / b);
	float gx = 0.06;
	float gy = 0.1;
	float m = smoothstep(0.0, gx, f.x) * smoothstep(0.0, gx, 1.0 - f.x) * smoothstep(0.0, gy, f.y) * smoothstep(0.0, gy, 1.0 - f.y);
	float r = hash(cell);
	vec3 c = base * (1.0 - vary * 0.5 + vary * r);
	c = mix(c, c * vec3(1.04, 0.98, 0.9), step(0.7, hash(cell + 7.0)));
	// taşın kenarı biraz koyu, ortası açık: hafif kabartma etkisi
	float bevel = smoothstep(0.0, 0.25, min(min(f.x, 1.0 - f.x) * 2.0, min(f.y, 1.0 - f.y) * 1.2));
	c *= 0.86 + 0.14 * bevel;
	ALBEDO = mix(mortar, c, m);
	ROUGHNESS = 0.92;
}
