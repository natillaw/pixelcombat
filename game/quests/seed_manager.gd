## SeedManager — semillas deterministas para el marco de misiones. Nada de aleatoriedad global: cada decision
## importante (ofertas de un piso, parametros de una mision, su recompensa) sale de una semilla derivada de la
## semilla de la partida y de claves estables, asi que la misma entrada reproduce el mismo resultado.
class_name SeedManager
extends RefCounted


## Entero positivo estable a partir de una lista de claves (numeros o textos).
static func seed_for(parts: Array) -> int:
	return absi(hash(str(parts))) % 2147483647


static func rng(parts: Array) -> RandomNumberGenerator:
	var generator := RandomNumberGenerator.new()
	generator.seed = seed_for(parts)
	return generator
