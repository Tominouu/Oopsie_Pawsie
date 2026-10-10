extends Node
## Oopsie Pawsie — banque de sons (autoload « Sons »). Sons CC0, voir assets/sounds/sfx/LICENCES.txt.
## Sons.play("plouf") joue une des variantes au hasard (plouf_1, plouf_2…), avec une légère
## variation de hauteur pour qu'un son répété ne lasse pas. Les sons continuent pendant
## les changements de scène (lecteurs gardés ici, dans l'autoload).

const DIR := "res://assets/sounds/sfx/"

## Nom → nombre de variantes (0 = un seul fichier sans numéro), volume (dB), variation de hauteur (±).
const BANK := {
	# Maison
	"pas": [5, -22.0, 0.12], "froissement": [3, -6.0, 0.1], "lancer_jeu": [0, -6.0, 0.0],
	"survol": [0, -14.0, 0.05], "tele_zap": [2, -14.0, 0.2],
	# Commun
	"popup_fermer": [0, -6.0, 0.0], "victoire": [3, -3.0, 0.0], "defaite": [3, -3.0, 0.0], "combo": [0, -4.0, 0.0],
	# Souris
	"swipe": [3, -8.0, 0.12], "coup": [3, -2.0, 0.1], "gicle": [6, -2.0, 0.12], "ecrasement": [0, 0.0, 0.08], "eclatement": [0, -2.0, 0.1], "patte_sol": [3, -8.0, 0.1],
	"snip": [0, -4.0, 0.05],
	# Aquarium
	"plouf": [6, -6.0, 0.12], "grosse_gerbe": [2, -2.0, 0.05], "bulles": [3, -12.0, 0.2], "flop": [2, -6.0, 0.15],
	# Croquettes
	"conserve": [3, -4.0, 0.1], "carton": [3, -6.0, 0.12], "chips": [2, -6.0, 0.1], "farine": [0, -4.0, 0.1],
	"pates": [0, -6.0, 0.1], "cereales": [0, -6.0, 0.1], "sac": [0, -6.0, 0.1], "toc": [0, -10.0, 0.1],
	"jackpot": [2, -3.0, 0.0],
	# Canapé
	"griffe": [5, -6.0, 0.12], "dechirure": [0, -6.0, 0.08], "note_ratee": [0, -12.0, 0.0],
	# Câble
	"prise": [0, -4.0, 0.0], "bzzt_metal": [0, -6.0, 0.05], "debranche": [0, -2.0, 0.0],
}
const POOL_SIZE := 16

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _cache := {}

## Musique de fond : un lecteur à part, qui retient où il en était.
const MUSIC_DIR := "res://assets/sounds/musique/"
var _music: AudioStreamPlayer
var _music_file := ""
var _music_pos := 0.0
var _music_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	add_child(_music)


## Joue le son `name` (une variante au hasard). volume_offset s'ajoute au volume de la banque.
func play(name: String, volume_offset := 0.0, pitch := 1.0) -> void:
	var entry: Array = BANK.get(name, [])
	if entry.is_empty():
		push_warning("Son inconnu : %s" % name)
		return
	var stream := _stream(name, entry[0])
	if stream == null:
		return
	var p := _free_player()
	p.stream = stream
	p.volume_db = float(entry[1]) + volume_offset
	p.pitch_scale = pitch * (1.0 + randf_range(-float(entry[2]), float(entry[2])))
	p.play()


## Lecteur en boucle à ajouter dans la scène (il s'arrête avec elle), ex. l'ambiance de l'aquarium.
func make_loop(file: String, volume_db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	var stream: AudioStream = load(DIR + file + ".ogg")
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	p.stream = stream
	p.volume_db = volume_db
	p.autoplay = true
	return p


func _stream(name: String, variants: int) -> AudioStream:
	var file := name if variants == 0 else "%s_%d" % [name, randi_range(1, variants)]
	if not _cache.has(file):
		# Les sons sont en .ogg ou en .mp3 selon la banque d'origine.
		var path := DIR + file + ".ogg"
		if not ResourceLoader.exists(path):
			path = DIR + file + ".mp3"
		_cache[file] = load(path)
	return _cache[file]


# --- Musique ------------------------------------------------------------------------

## Lance (ou reprend là où elle s'était arrêtée) une musique de fond en boucle, avec un fondu.
func play_music(file: String, volume_db: float, fade := 2.0) -> void:
	if _music.playing and _music_file == file:
		return
	if _music_file != file:
		var stream: AudioStream = load(MUSIC_DIR + file + ".ogg")
		if stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = true
		_music.stream = stream
		_music_file = file
		_music_pos = 0.0
	if _music_tween:
		_music_tween.kill()
	_music.volume_db = -60.0
	_music.play(_music_pos)
	_music_tween = create_tween()
	_music_tween.tween_property(_music, "volume_db", volume_db, fade)


## Coupe la musique en fondu ; elle reprendra au même endroit au prochain play_music().
func stop_music(fade := 0.6) -> void:
	if not _music.playing:
		return
	_music_pos = _music.get_playback_position()
	if _music_tween:
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.tween_property(_music, "volume_db", -60.0, fade)
	_music_tween.tween_callback(_music.stop)


func _free_player() -> AudioStreamPlayer:
	for i in POOL_SIZE:
		var p := _players[(_next + i) % POOL_SIZE]
		if not p.playing:
			_next = (_next + i + 1) % POOL_SIZE
			return p
	# Tous occupés : on coupe le plus ancien.
	var p := _players[_next]
	_next = (_next + 1) % POOL_SIZE
	return p
