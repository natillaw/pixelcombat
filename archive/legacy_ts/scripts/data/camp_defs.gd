class_name CampDefs
extends RefCounted
## D-090 camp. Health does not regenerate out of combat and mana only slowly: to recover fully in the tower the squad camps. The Master
## pings "Camp here" (wheel): it needs a camp kit, no awake creature within SAFE_RADIUS, and lasts DURATION s.
## Every hero within GATHER_RADIUS of the fire when it ends eats its own meal (one FOOD_ID from its bag): back
## to full health and mana + "well fed" for FED_TIME s; without a meal only NO_FOOD share. The fire draws
## eyes: creatures within LURE_RADIUS notice heroes from DETECT_MULT further. An awake creature within
## INTERRUPT_RADIUS, or a blow on a camper, ends the camp (the kit is spent).
## The kit is pista D's item (KIT_ID); while it does not exist, each expedition has TEST_KITS kits.
## Every value is a tuning placeholder.

const KIT_ID := "camp_kit"
const TEST_KITS := 1
const FOOD_IDS := ["food"]
const SAFE_RADIUS := 320.0
const INTERRUPT_RADIUS := 220.0
const GATHER_RADIUS := 120.0
const DURATION := 25.0
const HEAL := 1.0
const MANA := 1.0
const NO_FOOD := 0.6
const FED_TIME := 240.0
const SONG_TIME := 180.0
const LURE_RADIUS := 480.0
const DETECT_MULT := 1.6


## True when the kit is a real item (pista D defined it); otherwise the test counter is used.
static func kit_is_item() -> bool:
    return EconomyDefs.RESOURCES.has(KIT_ID)
