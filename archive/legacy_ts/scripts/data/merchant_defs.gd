class_name MerchantDefs
extends RefCounted
## Master prompt B (2026-10-31): a merchant in the town trades old materials for newer ones. Its stock
## rotates every town day (OFFERS_PER_DAY picked from OFFERS with the day as seed). Starting values.

const OFFERS_PER_DAY := 3
const TRADES_PER_OFFER := 2          # per day
const OFFERS := [
    {"give": {"ore": 10}, "get": {"mat_iron_ore": 1}},
    {"give": {"herb": 12}, "get": {"mat_moon_flower": 1}},
    {"give": {"hide": 8, "silk": 4}, "get": {"mat_enchanted_cloth": 1}},
    {"give": {"essence": 4}, "get": {"mat_resonant_crystal": 1}},
    {"give": {"mat_iron_ore": 6, "essence": 2}, "get": {"mat_rune_plate": 1}},
    {"give": {"bone": 10}, "get": {"essence": 1}},
]
