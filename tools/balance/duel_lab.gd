## DuelLab — duelos 1c1 entre las cuatro clases con bots, en modo de reglas PvP (stats normalizados, sin equipo).
##
## Dos jugadores en el mismo mundo (`CombatWorld.add_opponent`), cada uno llevado por un BotBrain que usa sus skills,
## esquiva los golpes avisados del rival y abre sus posturas. Para quitar la ventaja de lado, cada pareja se juega
## con los dos intercambiados. `matrix()` da el porcentaje de victorias de cada clase contra cada otra; el objetivo
## de diseño es que ninguna pareja se salga de 40-60 %. Limitacion conocida: las skills que buscan enemigos del PvE
## (teletransporte a la espalda, aturdir con el parry) todavia no ven a los rivales.
##
##   godot --headless --path . --script tools/balance/run_duels.gd
class_name DuelLab
extends RefCounted

const DT := 1.0 / 60.0
const START_A := Vector2(300, 320)
const START_B := Vector2(660, 320)


## Un duelo entre `class_a` y `class_b`. El mundo siempre simula primero al jugador principal y despues al rival,
## asi que quien actua primero en un mismo tick tiene una ligera ventaja: con `swap_sides` los papeles se cambian
## (b es el jugador principal) y `win_rate` reparte las rondas entre las dos opciones para anularla.
## Devuelve {winner: "a"|"b"|"draw", seconds, hp_a, hp_b} (hp = fraccion de vida al acabar).
static func duel(class_a: String, class_b: String, seed_value: int = 1, max_seconds: float = 75.0, swap_sides: bool = false) -> Dictionary:
	var main_class := class_b if swap_sides else class_a
	var rival_class := class_a if swap_sides else class_b
	var world := CombatWorld.new(seed_value)
	world.player.safe_zone = true
	world.player.switch_class(main_class)
	world.player.enter_rules("pvp")
	world.player.safe_zone = false
	var jitter := RandomNumberGenerator.new()
	jitter.seed = seed_value * 7919 + 17
	# Cada duelo empieza a una distancia y altura algo distintas (misma semilla, mismo duelo).
	var gap := jitter.randf_range(-90.0, 130.0)
	var lift := jitter.randf_range(-70.0, 70.0)
	var opponent := world.add_opponent(rival_class, START_B + Vector2(gap * 0.5, -lift))
	world.player.reset(START_A + Vector2(-gap * 0.5, lift))
	var main_bot := _bot(null)
	var rival_bot := _bot(opponent)
	var seconds := 0.0
	while seconds < max_seconds and world.player.alive and opponent.alive:
		world.submit_input(main_bot.decide(world))
		world.submit_opponent_input(opponent, rival_bot.decide(world))
		world.step(DT)
		seconds += DT
	var hp_main: float = world.player.health / maxf(world.player.max_health, 1.0)
	var hp_rival: float = opponent.health / maxf(opponent.max_health, 1.0)
	var winner := "draw"                          # "a" = gana el jugador principal, "b" = gana el rival (antes de cambiar papeles)
	if world.player.alive and not opponent.alive:
		winner = "a"
	elif opponent.alive and not world.player.alive:
		winner = "b"
	elif world.player.alive and opponent.alive and absf(hp_main - hp_rival) > 0.02:
		winner = "a" if hp_main > hp_rival else "b"
	if swap_sides and winner != "draw":
		winner = "b" if winner == "a" else "a"
	return {"winner": winner, "seconds": seconds, "hp_a": hp_rival if swap_sides else hp_main, "hp_b": hp_main if swap_sides else hp_rival}


static func _bot(me: PlayerSim) -> BotBrain:
	var bot := BotBrain.new()
	bot.me = me
	bot.dodge_enemies = true
	bot.use_stances = true
	return bot


## Porcentaje de victorias de `class_a` contra `class_b` en `rounds` duelos (la mitad con los lados cambiados).
## Un empate cuenta medio punto para cada uno.
static func win_rate(class_a: String, class_b: String, rounds: int = 10, seed_base: int = 100) -> float:
	var points := 0.0
	for i: int in range(rounds):
		var result := duel(class_a, class_b, seed_base + i, 75.0, i % 2 == 1)
		match String(result["winner"]):
			"a":
				points += 1.0
			"draw":
				points += 0.5
	return points / float(rounds)


## Matriz completa: {a: {b: porcentaje de victorias de a contra b}} y la media de cada clase contra las demas.
static func matrix(rounds: int = 10) -> Dictionary:
	var ids: Array = ClassCatalog.all_ids()
	var table: Dictionary = {}
	var average: Dictionary = {}
	for a: String in ids:
		table[a] = {}
		var total := 0.0
		var count := 0
		for b: String in ids:
			if a == b:
				continue
			var rate := win_rate(a, b, rounds)
			(table[a] as Dictionary)[b] = rate
			total += rate
			count += 1
		average[a] = total / float(maxi(count, 1))
	return {"table": table, "average": average, "classes": ids}
