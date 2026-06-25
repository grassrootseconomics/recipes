extends RefCounted

const INGREDIENTS := {
	"cheese": {
		"mark": "CH",
		"color": Color(0.96, 0.82, 0.34),
		"ink": Color(0.16, 0.11, 0.03),
		"texture_path": "res://art/ingredients/cheese_64.png"
	},
	"flour": {
		"mark": "FL",
		"color": Color(0.91, 0.84, 0.70),
		"ink": Color(0.16, 0.12, 0.08),
		"texture_path": "res://art/ingredients/flour_open_sack_64.png"
	},
	"herbs": {
		"mark": "HB",
		"color": Color(0.31, 0.62, 0.33),
		"ink": Color(0.94, 1, 0.93),
		"texture_path": "res://art/ingredients/herbs_64.png"
	},
	"vegetables": {
		"mark": "VG",
		"color": Color(0.72, 0.47, 0.24),
		"ink": Color(1, 0.95, 0.88),
		"texture_path": "res://art/ingredients/vegetables_64.png"
	},
	"rice": {
		"mark": "RI",
		"color": Color(0.95, 0.91, 0.74),
		"ink": Color(0.16, 0.14, 0.10),
		"texture_path": "res://art/ingredients/rice_64.png"
	},
	"beans": {
		"mark": "BE",
		"color": Color(0.54, 0.28, 0.20),
		"ink": Color(1, 0.95, 0.88),
		"texture_path": "res://art/ingredients/beans_64.png"
	},
	"spices": {
		"mark": "SP",
		"color": Color(0.78, 0.19, 0.13),
		"ink": Color(1, 0.94, 0.90),
		"texture_path": "res://art/ingredients/spices_64.png"
	},
	"eggs": {
		"mark": "EG",
		"color": Color(0.93, 0.88, 0.66),
		"ink": Color(0.16, 0.14, 0.08),
		"texture_path": "res://art/ingredients/eggs_64.png"
	}
}

const UNITS := {
	"slice": {"mark": "SL", "color": Color(0.95, 0.78, 0.50), "ink": Color(0.18, 0.10, 0.04)},
	"slices": {"mark": "SL", "color": Color(0.95, 0.78, 0.50), "ink": Color(0.18, 0.10, 0.04)},
	"cup": {"mark": "CP", "color": Color(0.65, 0.82, 0.95), "ink": Color(0.05, 0.12, 0.18)},
	"cups": {"mark": "CP", "color": Color(0.65, 0.82, 0.95), "ink": Color(0.05, 0.12, 0.18)},
	"scoop": {"mark": "SC", "color": Color(0.90, 0.66, 0.42), "ink": Color(0.16, 0.09, 0.04)},
	"scoops": {"mark": "SC", "color": Color(0.90, 0.66, 0.42), "ink": Color(0.16, 0.09, 0.04)},
	"piece": {"mark": "PC", "color": Color(0.80, 0.72, 0.58), "ink": Color(0.13, 0.10, 0.06), "texture_path": "res://art/dishes/cheese_frittata_64.png"},
	"pieces": {"mark": "PC", "color": Color(0.80, 0.72, 0.58), "ink": Color(0.13, 0.10, 0.06), "texture_path": "res://art/dishes/cheese_frittata_64.png"},
	"portion": {"mark": "PT", "color": Color(0.72, 0.80, 0.66), "ink": Color(0.08, 0.13, 0.06)},
	"portions": {"mark": "PT", "color": Color(0.72, 0.80, 0.66), "ink": Color(0.08, 0.13, 0.06)},
	"serving": {"mark": "SV", "color": Color(0.76, 0.70, 0.90), "ink": Color(0.10, 0.07, 0.16)},
	"servings": {"mark": "SV", "color": Color(0.76, 0.70, 0.90), "ink": Color(0.10, 0.07, 0.16)}
}

const FALLBACK := {"mark": "??", "color": Color(0.78, 0.80, 0.82), "ink": Color(0.08, 0.09, 0.10)}

const SHORT_DISH_NAMES := {
	"Cheese Frittata": "Frittata",
	"Cheese Quesadilla": "Quesadilla",
	"Cheesy Rice Bake": "Cheesy Bake",
	"Bean Enchilada Bake": "Enchilada",
	"Vegetable Flatbread": "Flatbread",
	"Bean Pupusa": "Pupusa",
	"Herb Dumplings": "Dumplings",
	"Rice Pancakes": "Pancakes",
	"Herb Rice Bowl": "Herb Bowl",
	"Green Rice": "Green Rice",
	"Bean Herb Salad": "Bean Salad",
	"Herb Casserole": "Herb Bake",
	"Veg Fried Rice": "Veg Rice",
	"Vegetable Chili": "Chili",
	"Veggie Omelet": "Veg Omelet",
	"Vegetable Pot Pie": "Pot Pie",
	"Fried Rice": "Fried Rice",
	"Rice Bean Bowl": "Bean Bowl",
	"Rice Cakes": "Rice Cakes",
	"Rice Casserole": "Rice Bake",
	"Bean Shakshuka": "Shakshuka",
	"Bean Burrito": "Burrito",
	"Bean Dip": "Bean Dip",
	"Bean Egg Skillet": "Skillet",
	"Spiced Rice Pilaf": "Pilaf",
	"Bean Tacos": "Tacos",
	"Masala Omelet": "Masala Egg",
	"Spiced Pancakes": "Spiced Cakes",
	"Breakfast Burrito": "Breakfast",
	"Egg Fried Rice": "Egg Rice",
	"Cheese Omelet": "Cheese Egg",
	"Egg Casserole": "Egg Bake"
}

const DISH_NAME_PREFIXES := [
	"Cheese ",
	"Cheesy ",
	"Bean ",
	"Vegetable ",
	"Veggie ",
	"Veg ",
	"Herb ",
	"Rice ",
	"Egg ",
	"Spiced "
]

static var _texture_cache := {}


static func ingredient_meta(ingredient_id: String) -> Dictionary:
	return _with_texture(INGREDIENTS.get(ingredient_id, FALLBACK))


static func unit_meta(unit_name: String) -> Dictionary:
	return _with_texture(UNITS.get(unit_name.to_lower(), FALLBACK))


static func dish_meta(dish_name: String, unit_name: String) -> Dictionary:
	var meta := unit_meta(unit_name)
	var slug := _slugify(dish_name)
	if slug != "":
		var texture_path := "res://art/dishes/%s_64.png" % slug
		if ResourceLoader.exists(texture_path):
			meta["texture_path"] = texture_path
	return _with_texture(meta)


static func avatar_texture(index: int) -> Texture2D:
	var normalized := posmod(index, 8) + 1
	return _texture_for_path("res://art/avatars/cook_%s_32.png" % normalized)


static func short_dish_name(dish_name: String) -> String:
	var name := dish_name.strip_edges()
	if name == "":
		return "Dish"
	if SHORT_DISH_NAMES.has(name):
		return str(SHORT_DISH_NAMES.get(name))
	for prefix in DISH_NAME_PREFIXES:
		if name.begins_with(prefix) and name.length() > prefix.length() + 3:
			return name.substr(prefix.length())
	return name


static func _slugify(value: String) -> String:
	var out := ""
	var last_was_separator := true
	for index in range(value.length()):
		var character := value.substr(index, 1).to_lower()
		var code := character.unicode_at(0)
		var is_alnum := (code >= 48 and code <= 57) or (code >= 97 and code <= 122)
		if is_alnum:
			out += character
			last_was_separator = false
		elif not last_was_separator:
			out += "_"
			last_was_separator = true
	if out.ends_with("_"):
		out = out.substr(0, out.length() - 1)
	return out


static func _with_texture(raw_meta: Dictionary) -> Dictionary:
	var meta := raw_meta.duplicate()
	var texture_path := str(meta.get("texture_path", ""))
	if texture_path != "":
		var texture := _texture_for_path(texture_path)
		if texture is Texture2D:
			meta["texture"] = texture
	return meta


static func _texture_for_path(texture_path: String) -> Texture2D:
	if _texture_cache.has(texture_path):
		return _texture_cache[texture_path]
	var texture: Texture2D = null
	if ResourceLoader.exists(texture_path):
		var resource := ResourceLoader.load(texture_path)
		texture = resource as Texture2D
	if texture == null:
		var image := Image.new()
		if image.load(texture_path) != OK:
			return null
		texture = ImageTexture.create_from_image(image)
	_texture_cache[texture_path] = texture
	return texture


static func clear_cache() -> void:
	_texture_cache.clear()
