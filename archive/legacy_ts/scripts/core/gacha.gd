class_name Gacha
extends RefCounted
## Rarity rolls + pity, driven by a banner dictionary from SummonConfig.
## Pity: a 4-star-or-better is guaranteed within pity4 pulls and a 5-star within pity5 pulls.

## pity4 / pity5 = pulls since the last 4+ / 5 star. Returns the new counters too.
static func roll_stars(rng: RandomNumberGenerator, pity4: int, pity5: int, banner: Dictionary = {}) -> Dictionary:
    if banner.is_empty():
        banner = SummonConfig.default_banner()
    var rates: Array = banner["rates"]
    var limit4: int = int(banner["pity4"])
    var limit5: int = int(banner["pity5"])
    var n4 := pity4 + 1
    var n5 := pity5 + 1
    var stars := 1
    if n5 >= limit5:
        stars = 5
    elif n4 >= limit4:
        # same ratio as the normal 4-star / 5-star rates
        var w4 := float(rates[3])
        var w5 := float(rates[4])
        stars = 4 if rng.randf() * (w4 + w5) < w4 else 5
    else:
        var total := 0.0
        for r in rates:
            total += float(r)
        var roll := rng.randf() * total
        for i in rates.size():
            roll -= float(rates[i])
            if roll <= 0.0:
                stars = i + 1
                break
    return {
        "stars": stars,
        "pity4": 0 if stars >= 4 else n4,
        "pity5": 0 if stars == 5 else n5,
    }
