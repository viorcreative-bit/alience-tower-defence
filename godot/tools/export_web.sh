#!/bin/bash
# Web çıktısı: build/web/ altına Godot dışa aktarımı, ardından motoru (index.wasm) gzip ile sıkıştırır
# ve index.html'e tarayıcıda açan küçük bir yama ekler. Böylece en büyük dosya ~9 MB olur
# (bazı barındırmalar tek dosyada 15 MB sınırı koyar). Oyun paketine (index.pck) her derlemede değişen bir
# sürüm eki eklenir; böylece telefonlar eski paketi önbellekten getirmez.
# Kullanım: GODOT=/yol/godot tools/export_web.sh
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT=${GODOT:-godot}
mkdir -p build/web
"$GODOT" --headless --export-release "Web" build/web/index.html
cd build/web
gzip -9 -c index.wasm > index.wasm.gz
python3 - <<'PY'
import time
s = open('index.html', encoding='utf-8').read()
patch = '''<script>
(function () {
	const realFetch = window.fetch.bind(window);
	window.fetch = function (input, init) {
		const url = typeof input === 'string' ? input : input.url;
		if (url && /index\\.wasm(\\?|$)/.test(url) && 'DecompressionStream' in window) {
			return realFetch(url.replace('index.wasm', 'index.wasm.gz'), init).then((res) => {
				if (!res.ok) return realFetch(input, init);
				const body = res.body.pipeThrough(new DecompressionStream('gzip'));
				return new Response(body, { status: 200, headers: { 'Content-Type': 'application/wasm' } });
			});
		}
		if (url && /index\\.pck(\\?|$)/.test(url)) {
			return realFetch(url + (url.includes('?') ? '&' : '?') + 'v=__STAMP__', init);
		}
		return realFetch(input, init);
	};
})();
</script>
'''
patch = patch.replace('__STAMP__', str(int(time.time())))
s = s.replace('<script src="index.js"></script>', patch + '<script src="index.js"></script>', 1)
open('index.html', 'w', encoding='utf-8').write(s)
PY
echo "build/web hazır"
