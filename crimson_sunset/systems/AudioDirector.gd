# AudioDirector — процедурный звук и музыка (синтвейв/эмбиент), без внешних файлов.
# Все звуки генерируются как AudioStreamSample при старте — проект самодостаточен.
extends Node

var _music_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _alarm_level: float = 0.0
var _cache: Dictionary = {}


func _ready() -> void:
	set_process(false)
	_music_player = AudioStreamPlayer.new()
	_music_player.volume_db = -14.0
	add_child(_music_player)
	for i in 12:
		var p := AudioStreamPlayer.new()
		p.volume_db = -6.0
		add_child(p)
		_sfx_players.append(p)
	play_music()


# ---------- генерация ----------

func _tone(freq: float, dur: float, vol: float = 0.5, wave: int = 0) -> AudioStreamSample:
	var rate := 22050
	var n := int(rate * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / rate
		var env := clampf(1.0 - t / dur, 0.0, 1.0)
		var s := sin(TAU * freq * t)
		if wave == 1: s = signf(s)                      # квадрат
		if wave == 2: s = randf_range(-1, 1)            # шум
		var v := int(clampf(s * env * vol, -1, 1) * 15000)
		data.encode_s16(i * 2, v)
	var asm := AudioStreamSample.new()
	asm.data = data
	asm.mix_rate = rate
	asm.format = AudioStreamSample.FORMAT_16_BITS
	return asm


func _make_music() -> AudioStreamSample:
	# медленная тёмная петля: бас + арпеджио (A minor, синтвейв-настроение)
	var rate := 22050
	var bpm := 70.0
	var beat := 60.0 / bpm
	var bars := 4
	var total := beat * 4 * bars
	var n := int(rate * total)
	var data := PackedByteArray()
	data.resize(n * 2)
	var bass := [55.0, 55.0, 65.4, 49.0]        # A A C G
	var arp := [220.0, 261.6, 329.6, 261.6]
	for i in n:
		var t := float(i) / rate
		var b := int(t / (beat * 4)) % bars
		var bs := sin(TAU * bass[b] * t) * 0.5
		var ai := int(t / (beat * 0.5)) % 4
		var at := fmod(t, beat * 0.5)
		var ae := clampf(1.0 - at / (beat * 0.5), 0.0, 1.0)
		var as_ := sin(TAU * arp[ai] * t) * 0.18 * ae
		var pad := sin(TAU * 110.0 * t + sin(t * 0.7) * 2.0) * 0.08
		var v := int(clampf(bs + as_ + pad, -1, 1) * 12000)
		data.encode_s16(i * 2, v)
	var asm := AudioStreamSample.new()
	asm.data = data
	asm.mix_rate = rate
	asm.format = AudioStreamSample.FORMAT_16_BITS
	asm.loop_mode = AudioStreamSample.LOOP_FORWARD
	asm.loop_begin = 0
	asm.loop_end = n
	return asm


func play_music() -> void:
	if not _cache.has("music"):
		_cache["music"] = _make_music()
	_music_player.stream = _cache["music"]
	if not _music_player.playing:
		_music_player.play()


func set_tension(v: float) -> void:
	# v 0..1 — тревожность миссии, поднимает громкость/тон музыки
	_alarm_level = clampf(v, 0, 1)
	_music_player.volume_db = lerpf(-14.0, -6.0, _alarm_level)


func play(kind: String) -> void:
	var stream: AudioStreamSample = null
	match kind:
		"step":     stream = _get_cached("step", func(): return _tone(90, 0.05, 0.25, 2))
		"run_step": stream = _get_cached("run_step", func(): return _tone(70, 0.07, 0.45, 2))
		"door":     stream = _get_cached("door", func(): return _tone(180, 0.12, 0.35, 1))
		"click":    stream = _get_cached("click", func(): return _tone(900, 0.03, 0.2, 1))
		"terminal": stream = _get_cached("terminal", func(): return _tone(1400, 0.05, 0.15, 1))
		"alert":    stream = _tone(880, 0.18, 0.6, 1)   # резкий звук обнаружения
		"siren":    stream = _tone(520, 0.5, 0.4, 1)
		"pickup":   stream = _get_cached("pickup", func(): return _tone(660, 0.08, 0.3, 0))
		"success":  stream = _get_cached("success", func(): return _tone(523, 0.25, 0.35, 0))
		"fail":     stream = _get_cached("fail", func(): return _tone(140, 0.35, 0.4, 1))
		"message":  stream = _get_cached("message", func(): return _tone(1040, 0.07, 0.2, 0))
		"hide":     stream = _get_cached("hide", func(): return _tone(240, 0.1, 0.3, 2))
		"connect":  stream = _tone(330, 0.2, 0.3, 1)
		_: return
	for p in _sfx_players:
		if not p.playing:
			p.stream = stream
			p.play()
			return


func _get_cached(key: String, maker: Callable) -> AudioStreamSample:
	if not _cache.has(key):
		_cache[key] = maker.call()
	return _cache[key]
