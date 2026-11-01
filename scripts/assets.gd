## Replaceable art loader. For "bears/bear" in the current mode (normal/horror)
## it uses the first file that exists:
##   1. assets/sprites/bears/<mode>/bear.png           your mode-specific art
##   2. assets/sprites/bears/bear.png                  your shared art
##   3. assets/sprites/bears/<mode>/template_bear.png  built-in mode placeholder
##   4. assets/sprites/bears/template_bear.png         built-in placeholder
## Creator files always win over templates; templates never overwrite anything.
## Custom mode first looks in assets/sprites/<folder>/custom/<name>.png and
## otherwise uses exactly what Normal mode would. Nothing in custom/ is ever
## read in Normal or Horror, and the placeholder generator never writes there.
extends Node

const ROOT := "res://assets/sprites/"

# Sprite sheet layouts (cells in a single row; the cell size is derived from
# the image, so replacements may use any resolution).
const BEAR_CELLS := 10      # body, belly, head, ear, arm, leg, face x4
const TILE_CELLS := 9       # rug, rug alt, ice, honey, bouncy, conveyor, pillar, cushion block, border
const POWERUP_CELLS := 10    # bomb, blast, speed, shuffle, kick, line, rubber, immortal, reverse, diarrhea
const EFFECT_CELLS := 8     # blast centre, blast arm, blast end, star, dust, sparkle, bird, floor splat

var _cache := {}


func tex(rel: String) -> Texture2D:
	var key: String = Settings.mode + ":" + rel
	if _cache.has(key):
		return _cache[key]
	var t: Texture2D = null
	var path := resolve(rel)
	if path != "":
		t = _load(path)
	if t == null:
		push_warning("Missing sprite: " + rel)
		var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
		img.fill(Color.MAGENTA)
		t = ImageTexture.create_from_image(img)
	_cache[key] = t
	return t


## The file `tex(rel)` will use in the current mode ("" if none exists).
func resolve(rel: String) -> String:
	var mode: String = Settings.mode
	var folder := ROOT + rel.get_base_dir() + "/"
	var file := rel.get_file()
	var candidates := []
	if mode == "custom":
		candidates.append(folder + "custom/" + file + ".png")
		mode = "normal"
	candidates.append_array([folder + mode + "/" + file + ".png", folder + file + ".png",
			folder + mode + "/template_" + file + ".png", folder + "template_" + file + ".png"])
	for candidate in candidates:
		if ResourceLoader.exists(candidate) or FileAccess.file_exists(candidate):
			return candidate
	return ""


func _load(path: String) -> Texture2D:
	var img: Image = null
	if ResourceLoader.exists(path):
		var r = load(path)
		if r is Texture2D:
			img = r.get_image()
	if img == null and FileAccess.file_exists(path):
		# Not yet imported (e.g. a freshly dropped-in replacement): read raw.
		img = Image.load_from_file(ProjectSettings.globalize_path(path))
	if img == null or img.is_empty():
		return null
	# Sheets are drawn at 1/4 of their pixel size (or smaller): mipmaps plus the
	# project's linear-mipmap canvas filter keep the downscaled art crisp
	# instead of shimmering or turning mushy. Works for any replacement size.
	if img.is_compressed():
		img.decompress()
	if not img.has_mipmaps():
		img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Rect of cell `index` in a single-row sheet with `cells` cells.
func region(t: Texture2D, cells: int, index: int) -> Rect2:
	var w := float(t.get_width()) / cells
	return Rect2(w * index, 0, w, t.get_height())
