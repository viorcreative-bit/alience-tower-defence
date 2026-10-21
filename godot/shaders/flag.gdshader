// Dalgalanan sancak: direğe bağlı kenar sabit, uca doğru dalga büyür.
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform float speed = 5.0;
uniform float amp = 0.06;

void vertex() {
	float k = UV.x;
	float w = sin(UV.x * 7.0 - TIME * speed + float(INSTANCE_ID)) * amp * k;
	VERTEX.z += w;
	VERTEX.y += sin(UV.x * 5.0 - TIME * speed * 0.7) * amp * 0.3 * k;
}

void fragment() {
	vec4 c = texture(tex, UV);
	ALBEDO = c.rgb;
	ROUGHNESS = 0.8;
}
