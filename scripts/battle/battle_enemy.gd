extends Resource
class_name BattleEnemy
## Configurable enemy statistics for a battle.
##
## Create one of these as a .tres file (or inline in a BattleUI scene) and
## assign it to BattleManager.enemy. The manager never mutates this resource;
## current HP lives in BattleManager so the same resource can be reused.

@export var display_name: String = "Enemy"
@export_range(1, 9999, 1) var max_hp: int = 60

## Base damage before variance is applied.
@export_range(0, 999, 1) var attack_damage: int = 12

## Each attack rolls attack_damage +/- this amount. Use 0 for fixed damage.
@export_range(0, 999, 1) var damage_variance: int = 2

## Flavour lines used by the Talk action. The manager cycles through them.
@export var talk_lines: PackedStringArray = PackedStringArray([
	"It stares back, unimpressed.",
])

## Text used when talk_lines is empty.
@export var no_talk_lines_text: String = "It does not respond."

@export_group("Talk victory")
## When true, using Talk enough times wins the battle peacefully.
## Leave false for enemies that can only be defeated by damage.
@export var can_win_by_talking: bool = false

## Talk actions required before a peaceful victory. Clamped to at least 1.
@export_range(1, 99, 1) var talks_to_win: int = 3

## Optional message shown when talking wins. Leave empty for a default line.
@export_multiline var talk_victory_text: String = ""

@export_group("Battle text")
## Lines shown at the start of each player turn. Used in order and cycles if
## the battle runs longer than the list. Leave empty for the default message.
@export var turn_lines: PackedStringArray = PackedStringArray()

## Optional custom line for the first player turn. Only used when turn_lines is
## empty. Leave empty for the default "A <name> blocks your path!".
@export_multiline var intro_text: String = ""

## Optional artwork shown above the battle UI. Leave empty to show the
## placeholder label instead.
@export var texture: Texture2D

@export_multiline var description: String = ""
