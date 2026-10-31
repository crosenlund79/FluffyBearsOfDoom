## Replaceable art loader.
## For "bears/bear" it loads assets/sprites/bears/bear.png when present and
## otherwise falls back to assets/sprites/bears/template_bear.png.
extends Node

const ROOT := "res://assets/sprites/"

# Sprite sheet layouts (cells in a single row; the cell size is derived from
# the image, so replacements may use any resolution).
const BEAR_CELLS := 10      # body, belly, head, ear, arm, leg, face x4
const TILE_CELLS := 9       # rug, rug alt, ice, honey, bouncy, conveyor, pillar, cushion block, border
const POWERUP_CELLS := 4    # extra bomb, blast range, springy stitching, biome shuffle
const EFFECT_CELLS := 6     # blast centre, blast arm, blast end, star, dust, sparkle

var _cache := {}


func tex(rel: String) -> Texture2D:
	if _cache.has(rel):
		return _cache[rel]
	var folder := rel.get_base_dir()
	var file := rel.get_file()
	var t: Texture2D = null
	for candidate in [ROOT + rel + ".png", ROOT + folder + "/template_" + file + ".png"]:
		t = _load(candidate)
		if t:
			break
	if t == null:
		push_warning("Missing sprite: " + rel)
		var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
		img.fill(Color.MAGENTA)
		t = ImageTexture.create_from_image(img)
	_cache[rel] = t
	return t


func _load(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var r = load(path)
		if r is Texture2D:
			return r
	if FileAccess.file_exists(path):
		# Not yet imported (e.g. a freshly dropped-in replacement): read raw.
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img and not img.is_empty():
			return ImageTexture.create_from_image(img)
	return null


## Rect of cell `index` in a single-row sheet with `cells` cells.
func region(t: Texture2D, cells: int, index: int) -> Rect2:
	var w := float(t.get_width()) / cells
	return Rect2(w * index, 0, w, t.get_height())
