// Çim tutamları: rüzgârda sallanan, kökü koyu ucu açık otlar.
shader_type spatial;
render_mode cull_disabled, diffuse_burley;

uniform vec3 root_col : source_color = vec3(0.20, 0.38, 0.10);
uniform vec3 tip_col : source_color = vec3(0.52, 0.74, 0.24);
uniform float wind = 1.0;
uniform vec3 tint : source_color = vec3(1.0);
uniform float snow = 0.0;

varying float h;

void vertex() {
	h = UV.y;
	vec3 wp = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float t = TIME * 1.6 + wp.x * 0.7 + wp.z * 0.45;
	float sway = (sin(t) * 0.6 + sin(t * 2.3) * 0.25) * wind;
	VERTEX.x += sway * 0.06 * h * h;
	VERTEX.z += cos(t * 0.8) * 0.03 * h * h * wind;
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	ALBEDO = mix(mix(root_col, tip_col, h) * COLOR.rgb * tint, vec3(0.92, 0.94, 0.97), snow * (0.3 + 0.7 * h));
	ROUGHNESS = 0.9;
	SPECULAR = 0.1;
}
