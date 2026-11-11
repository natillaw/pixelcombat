extends Node
## UI smoke test: builds the real screens, performs a x10 summon, opens the roster.
##   godot --headless --path . res://tests/smoke_ui.tscn --quit-after 3000
## Prints SMOKE OK / SMOKE FAIL.

func _ready() -> void:
    Game.autosave = false
    Game.save_path = "user://smoke_save.json"
    Game.new_game()
    Game.gems = 100000                       # a x10 summon costs more than the starting gems now (#10)
    var screen := SummonScreen.new()
    add_child(screen)
    await get_tree().process_frame
    screen._pull(10)
    var waited := 0.0
    while screen._busy and waited < 15.0:   # reveal animations run on real time
        await get_tree().create_timer(0.2).timeout
        waited += 0.2
        for n in screen.get_children():
            if n is SummonReveal:
                n._skip_all = true                # D-063 reveal: skip, then Done on the summary
                if n.summary_shown:
                    n.close()
    var ok := screen._result.text != "" and Game.heroes.size() == 10 and Game.summon_log.size() == 10
    var roster := RosterScreen.new()
    add_child(roster)
    await get_tree().process_frame
    var party := PartyScreen.new()
    add_child(party)
    await get_tree().process_frame
    print("SMOKE ", "OK" if ok else "FAIL", " heroes=", Game.heroes.size(), " result=", screen._result.text.substr(0, 60))
    DirAccess.remove_absolute(ProjectSettings.globalize_path("user://smoke_save.json"))
    get_tree().quit(0 if ok else 1)
