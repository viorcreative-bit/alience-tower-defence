extends SceneTree

# Net'i sahte bir Realtime sunucusuyla sınar: iki istemci aynı odaya girer, yayınlar birbirine ulaşır,
# iki DuelLink el sıkışıp aynı tohumla başlar. Kullanım: godot --headless --script tests/net_mock.gd

const PORT := 18765

var server := TCPServer.new()
var peers := []  # {ws, topics}
var a: Net
var b: Net
var la: DuelLink
var lb: DuelLink
var seeds := []
var got := []
var frames := 0
var first_url := ""


func _initialize() -> void:
	assert(server.listen(PORT, "127.0.0.1") == OK)
	a = Net.new()
	b = Net.new()
	for n in [a, b]:
		n.url = "http://127.0.0.1:%d" % PORT
		n.key = "eyJsahte"
		root.add_child(n)
	la = DuelLink.new("a", "Ali", "ottoman")
	lb = DuelLink.new("b", "Veli", "hungary")
	la.outgoing.connect(a.send)
	lb.outgoing.connect(b.send)
	a.message.connect(la.handle)
	b.message.connect(lb.handle)
	for l in [la, lb]:
		l.started.connect(func(s):
			seeds.append(s)
			var g := Game.new()
			g.set_duel(true)
			g.reset()
			l.game = g)
	b.message.connect(func(m): got.append(m))
	la.begin("ABCD")
	lb.begin("ABCD")
	a.join("ABCD")
	b.join("abcd")


func _process(dt: float) -> bool:
	frames += 1
	while server.is_connection_available():
		var w := WebSocketPeer.new()
		w.accept_stream(server.take_connection())
		peers.append({"ws": w, "topics": {}})
	for p in peers:
		var w: WebSocketPeer = p.ws
		w.poll()
		if first_url == "" and w.get_ready_state() == WebSocketPeer.STATE_OPEN:
			first_url = w.get_requested_url()
		while w.get_available_packet_count():
			var d: Dictionary = JSON.parse_string(w.get_packet().get_string_from_utf8())
			match d.event:
				"phx_join":
					assert(d.payload.access_token == "eyJsahte")
					p.topics[d.topic] = true
					w.send_text(JSON.stringify({"topic": d.topic, "event": "phx_reply", "ref": d.ref, "payload": {"status": "ok", "response": {}}}))
				"broadcast":
					for o in peers:
						if o != p and o.topics.has(d.topic):
							o.ws.send_text(JSON.stringify({"topic": d.topic, "event": "broadcast", "ref": null, "payload": d.payload}))
	for l in [la, lb]:
		l.tick(dt)
	if seeds.size() == 2 or frames > 600:
		assert(a.joined and b.joined, "odaya girilemedi")
		assert(a.topic == b.topic and a.topic == "realtime:kale-abcd")
		assert(first_url.contains("apikey=eyJsahte") and first_url.contains("/realtime/v1/websocket"), first_url)
		assert(seeds.size() == 2 and seeds[0] == seeds[1], "el sıkışma: %s" % str(seeds))
		assert(got.size() > 0 and got[0].t == "hello")
		print("ağ tamam: %d karede başladı, tohum %d" % [frames, seeds[0]])
		quit()
	return false
