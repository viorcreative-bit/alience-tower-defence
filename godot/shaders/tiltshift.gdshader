// Minyatür etkisi: görüntünün üst ve alt kenarı yumuşakça bulanıklaşır, köşeler hafif kararır.
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
// odak bandı (ekran yüksekliğine oranla): bunun dışında kalan kısım bulanıklaşır
uniform float focus_top = 0.3;
uniform float focus_bottom = 0.75;
uniform float fade = 0.18;
uniform float strength = 2.6;
uniform float vignette = 0.28;

void fragment() {
	float y = SCREEN_UV.y;
	float b = max(smoothstep(focus_top, focus_top - fade, y), smoothstep(focus_bottom, focus_bottom + fade, y));
	vec3 c = textureLod(screen, SCREEN_UV, b * strength).rgb;
	vec2 d = SCREEN_UV - 0.5;
	float v = smoothstep(0.35, 0.85, length(d * vec2(1.25, 0.9)));
	c *= 1.0 - v * vignette;
	COLOR = vec4(c, 1.0);
}
