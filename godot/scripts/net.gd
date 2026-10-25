class_name Net
extends Node

# Supabase bağlantısı: çevrimiçi sıralama REST ile (scores tablosu), düello odaları Realtime yayın
# kanalıyla (Phoenix protokolü, WebSocket). Sunucuda oyun mantığı yoktur; iki oyuncu birbirine
# kısa iletiler yollar. Adres ve anahtar net_config.gd'dedir.

const CONFIG := preload("res://scripts/net_config.gd")
const HEARTBEAT := 25.0

signal message(msg: Dictionary)
signal status(s: String)  # connecting | joined | closed | error

var ws: WebSocketPeer
var topic := ""
var ref := 0
var join_ref := ""
var joined := false
var heartbeat := 0.0
var queue := []  # odaya girmeden yollananlar
var url: String = CONFIG.URL  # sınamada sahte sunucuya çevrilir
var key: String = CONFIG.KEY


static func configured() -> bool:
	return CONFIG.URL != "" and CONFIG.KEY != ""


# Eski anon anahtarları JWT'dir ("eyJ..."); yeni publishable anahtarlar Authorization'a yazılmaz
func _jwt() -> bool:
	return key.begins_with("eyJ")


func _base() -> String:
	return url.strip_edges().trim_suffix("/")


func _ready_to_go() -> bool:
	return url != "" and key != ""


# ---------------------------------------------------------------- düello odası

func join(room: String) -> void:
	leave()
	if not _ready_to_go():
		status.emit("error")
		return
	topic = "realtime:kale-" + room.to_lower()
	ws = WebSocketPeer.new()
	var url := _base().replace("https://", "wss://").replace("http://", "ws://") + "/realtime/v1/websocket?apikey=%s&vsn=1.0.0" % key.uri_encode()
	join_ref = ""
	queue = []
	if ws.connect_to_url(url) != OK:
		ws = null
		status.emit("error")
		return
	status.emit("connecting")


func leave() -> void:
	if ws:
		if joined:
			_send_raw(topic, "phx_leave", {})
		ws.close()
	ws = null
	joined = false
	queue = []


func send(msg: Dictionary) -> void:
	if joined:
		_send_raw(topic, "broadcast", {"type": "broadcast", "event": "m", "payload": msg})
	else:
		queue.append(msg)


func _send_raw(t: String, event: String, payload: Dictionary) -> String:
	ref += 1
	var r := str(ref)
	ws.send_text(JSON.stringify({"topic": t, "event": event, "payload": payload, "ref": r, "join_ref": join_ref if join_ref != "" else null}))
	return r


func _process(dt: float) -> void:
	if ws == null:
		return
	ws.poll()
	match ws.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			if join_ref == "":
				var p := {"config": {"broadcast": {"self": false, "ack": false}, "presence": {"key": ""}, "private": false}}
				if _jwt():
					p.access_token = key
				join_ref = _send_raw(topic, "phx_join", p)
				heartbeat = HEARTBEAT
			heartbeat -= dt
			if heartbeat <= 0.0:
				heartbeat = HEARTBEAT
				_send_raw("phoenix", "heartbeat", {})
			while ws and ws.get_available_packet_count():
				var d = JSON.parse_string(ws.get_packet().get_string_from_utf8())
				if d is Dictionary:
					_on(d)
		WebSocketPeer.STATE_CLOSED:
			ws = null
			joined = false
			status.emit("closed")


func _on(d: Dictionary) -> void:
	if d.get("topic") != topic:
		return
	var p = d.get("payload", {})
	match d.get("event"):
		"phx_reply":
			if d.get("ref") == join_ref and not joined:
				if p is Dictionary and p.get("status") == "ok":
					joined = true
					status.emit("joined")
					for m in queue:
						send(m)
					queue = []
				else:
					push_warning("Odaya girilemedi: %s" % str(p))
					status.emit("error")
		"broadcast":
			if p is Dictionary and p.get("payload") is Dictionary:
				message.emit(p.payload)
		"phx_error", "phx_close":
			joined = false
			status.emit("closed")


# ---------------------------------------------------------------- çevrimiçi sıralama

func _headers(extra := []) -> PackedStringArray:
	var h := ["apikey: " + key, "Content-Type: application/json"]
	if _jwt():
		h.append("Authorization: Bearer " + key)
	return PackedStringArray(h + extra)


func _request(path: String, method: int, body: String, extra: Array, cb: Callable) -> void:
	if not _ready_to_go():
		cb.call(null)
		return
	var h := HTTPRequest.new()
	h.timeout = 10.0
	add_child(h)
	h.request_completed.connect(func(result: int, code: int, _hd, data: PackedByteArray):
		h.queue_free()
		var ok := result == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 300
		cb.call(JSON.parse_string(data.get_string_from_utf8()) if ok and data.size() else ([] if ok else null)))
	if h.request(_base() + path, _headers(extra), method, body) != OK:
		h.queue_free()
		cb.call(null)


# En çok şerefli 20 oyuncu; bağlantı yoksa cb(null)
func fetch_top(cb: Callable) -> void:
	_request("/rest/v1/scores?select=name,honor,stars,best_wave,duel_wins&order=honor.desc,stars.desc&limit=20",
		HTTPClient.METHOD_GET, "", [], cb)


# Bu cihazdaki hesabın satırını yazar ya da günceller (cihaz + ad tektir)
func submit(row: Dictionary, cb := func(_r): pass) -> void:
	_request("/rest/v1/scores?on_conflict=device,name", HTTPClient.METHOD_POST, JSON.stringify([row]),
		["Prefer: resolution=merge-duplicates,return=minimal"], cb)
