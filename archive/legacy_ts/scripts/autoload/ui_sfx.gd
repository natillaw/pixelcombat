extends Node
## UI sounds (Kenney Interface Sounds, D-063) and music with crossfade (xDeviruchi). Autoloads "UiSfx"
## and "Music" share this script: UiSfx.play("click"), Music.play_track("town"). Volumes are per bus
## (Options screen): "Music", "SFX", "UI"; created at start if the project has no audio bus layout.

const UI_SOUNDS := {
    "hover": "tick_001.ogg", "click": "click_002.ogg", "confirm": "confirmation_001.ogg", "cancel": "back_001.ogg",
    "error": "error_004.ogg", "open": "open_001.ogg", "close": "close_001.ogg", "level_up": "confirmation_004.ogg",
    "pull_common": "select_001.ogg", "pull_rare": "confirmation_002.ogg", "pull_epic": "confirmation_003.ogg",
    "pull_legendary": "maximize_008.ogg",
}
const FADE := 1.2                   # seconds of music crossfade
const BUSES := ["Music", "SFX", "UI"]

var _players: Array[AudioStreamPlayer] = []
var _music_a: AudioStreamPlayer = null
var _music_b: AudioStreamPlayer = null
var current_track: String = ""
var _last_hover_ms: int = 0


func _ready() -> void:
    for b in BUSES:
        if AudioServer.get_bus_index(b) < 0:
            AudioServer.add_bus()
            AudioServer.set_bus_name(AudioServer.bus_count - 1, b)
            AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
    for i in 4:
        var p := AudioStreamPlayer.new()
        p.bus = "UI"
        add_child(p)
        _players.append(p)
    _music_a = AudioStreamPlayer.new()
    _music_b = AudioStreamPlayer.new()
    for m in [_music_a, _music_b]:
        m.bus = "Music"
        m.volume_db = -80.0
        add_child(m)


## A UI sound by name (silently nothing if the file is missing or we run headless tests).
func play(id: String) -> void:
    if DisplayServer.get_name() == "headless" or not UI_SOUNDS.has(id):
        return
    if id == "hover":
        var now := Time.get_ticks_msec()
        if now - _last_hover_ms < 60:
            return                      # sweeping the mouse over a list does not rattle
        _last_hover_ms = now
    var path := AssetCatalog.UI_SFX + String(UI_SOUNDS[id])
    if not ResourceLoader.exists(path):
        return
    for p in _players:
        if not p.playing:
            p.stream = load(path)
            p.play()
            return


## Crossfades to a music role: title, town, explore, dungeon, battle, boss, results.
func play_track(role: String) -> void:
    if role == current_track or DisplayServer.get_name() == "headless":
        return
    var path := AssetCatalog.MUSIC + role + ".ogg"
    if not ResourceLoader.exists(path):
        return
    current_track = role
    var stream := load(path) as AudioStream
    if stream is AudioStreamOggVorbis:
        (stream as AudioStreamOggVorbis).loop = true
    var incoming := _music_b if _music_a.playing and _music_a.volume_db > -40.0 else _music_a
    var outgoing := _music_a if incoming == _music_b else _music_b
    incoming.stream = stream
    incoming.volume_db = -40.0
    incoming.play()
    var t := create_tween().set_parallel(true)
    t.tween_property(incoming, "volume_db", 0.0, FADE)
    t.tween_property(outgoing, "volume_db", -80.0, FADE)
    t.chain().tween_callback(func(): outgoing.stop())


## Linear volume 0..1 of a bus (Options screen).
func set_volume(bus: String, v: float) -> void:
    var i := AudioServer.get_bus_index(bus)
    if i >= 0:
        AudioServer.set_bus_volume_db(i, linear_to_db(maxf(0.0001, v)))
        AudioServer.set_bus_mute(i, v <= 0.001)


func get_volume(bus: String) -> float:
    var i := AudioServer.get_bus_index(bus)
    return db_to_linear(AudioServer.get_bus_volume_db(i)) if i >= 0 else 1.0
