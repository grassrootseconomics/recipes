#!/usr/bin/env python3
from __future__ import annotations

import json
import math
import random
import re
import shutil
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
CATALOG_PATH = ROOT / "client" / "data" / "recipe_catalog.json"
CLIENT_OUT = ROOT / "client" / "art" / "dishes"
ART_OUT = ROOT / "art" / "dishes"
SIZE = 64

OUTLINE = (83, 48, 31, 255)
DEEP = (60, 34, 25, 255)
HIGHLIGHT = (255, 239, 176, 255)

INGREDIENT_COLORS = {
    "cheese": (244, 175, 49, 255),
    "flour": (226, 202, 172, 255),
    "herbs": (92, 153, 67, 255),
    "vegetables": (214, 86, 53, 255),
    "rice": (239, 232, 215, 255),
    "beans": (154, 80, 53, 255),
    "spices": (205, 84, 43, 255),
    "eggs": (238, 210, 128, 255),
}


def slugify(value: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "_", value.lower()).strip("_")
    return slug or "dish"


def canvas() -> Image.Image:
    return Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))


def shadow(draw: ImageDraw.ImageDraw, cx: int = 32, cy: int = 54, rx: int = 21, ry: int = 6) -> None:
    draw.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=(70, 38, 22, 62))
    draw.ellipse((cx - rx + 5, cy - ry + 2, cx + rx - 5, cy + ry + 1), fill=(70, 38, 22, 46))


def darken(color: tuple[int, int, int, int], amount: int = 38) -> tuple[int, int, int, int]:
    return (max(0, color[0] - amount), max(0, color[1] - amount), max(0, color[2] - amount), color[3])


def lighten(color: tuple[int, int, int, int], amount: int = 34) -> tuple[int, int, int, int]:
    return (min(255, color[0] + amount), min(255, color[1] + amount), min(255, color[2] + amount), color[3])


def recipe_colors(recipe: dict) -> list[tuple[int, int, int, int]]:
    colors: list[tuple[int, int, int, int]] = []
    for requirement in recipe.get("requirements", []):
        ingredient_id = requirement.get("ingredientId", "")
        color = INGREDIENT_COLORS.get(ingredient_id)
        if color:
            colors.append(color)
    return colors or [(210, 170, 110, 255)]


def primary_color(recipe: dict) -> tuple[int, int, int, int]:
    owner = recipe.get("ownerIngredientId", "")
    if owner in INGREDIENT_COLORS:
        return INGREDIENT_COLORS[owner]
    return recipe_colors(recipe)[0]


def topping_points(seed: str, count: int, area: tuple[int, int, int, int]) -> list[tuple[int, int]]:
    rng = random.Random(seed)
    x1, y1, x2, y2 = area
    return [(rng.randint(x1, x2), rng.randint(y1, y2)) for _ in range(count)]


def draw_toppings(
    draw: ImageDraw.ImageDraw,
    recipe: dict,
    area: tuple[int, int, int, int],
    count: int = 7,
    size: int = 3,
) -> None:
    colors = recipe_colors(recipe)
    for index, (x, y) in enumerate(topping_points(recipe["dishName"], count, area)):
        color = colors[index % len(colors)]
        if recipe.get("requirements", [])[index % len(recipe.get("requirements", [1]))].get("ingredientId") == "herbs":
            draw.ellipse((x - 2, y - 1, x + 2, y + 2), fill=color, outline=darken(color, 45))
        elif recipe.get("requirements", [])[index % len(recipe.get("requirements", [1]))].get("ingredientId") == "rice":
            draw.rectangle((x - 2, y, x + 2, y + 1), fill=lighten(color, 12))
        else:
            draw.rectangle((x, y, x + size, y + size), fill=color)


def draw_slice(draw: ImageDraw.ImageDraw, recipe: dict) -> None:
    base = primary_color(recipe)
    name = recipe["dishName"].lower()
    if "pot pie" in name:
        crust = (219, 164, 92, 255)
        filling = (179, 132, 77, 255)
        draw.polygon([(12, 45), (31, 15), (52, 30), (50, 49)], fill=crust, outline=OUTLINE)
        draw.polygon([(17, 43), (31, 21), (47, 32), (45, 44)], fill=filling, outline=OUTLINE)
        draw.line([(21, 39), (40, 30)], fill=HIGHLIGHT, width=2)
    elif "omelet" in name or "frittata" in name:
        egg = INGREDIENT_COLORS["eggs"]
        draw.polygon([(9, 42), (34, 17), (55, 31), (50, 48)], fill=egg, outline=OUTLINE)
        draw.polygon([(34, 17), (55, 31), (50, 48), (40, 42), (39, 25)], fill=darken(egg, 42), outline=OUTLINE)
        draw.polygon([(13, 40), (34, 20), (39, 25), (39, 42)], fill=lighten(egg, 25))
    else:
        draw.polygon([(10, 43), (34, 15), (55, 28), (51, 49)], fill=base, outline=OUTLINE)
        draw.polygon([(34, 15), (55, 28), (51, 49), (40, 43), (39, 25)], fill=darken(base, 45), outline=OUTLINE)
        draw.polygon([(13, 41), (34, 19), (39, 25), (39, 42)], fill=lighten(base, 26))
    draw_toppings(draw, recipe, (19, 24, 45, 40), 8, 2)
    draw.line([(13, 44), (40, 47), (51, 49)], fill=(104, 58, 35, 255), width=2)


def draw_bowl(draw: ImageDraw.ImageDraw, fill: tuple[int, int, int, int]) -> None:
    draw.ellipse((12, 30, 52, 52), fill=(179, 96, 58, 255), outline=OUTLINE)
    draw.rectangle((13, 39, 51, 45), fill=(179, 96, 58, 255))
    draw.polygon([(14, 41), (50, 41), (43, 56), (21, 56)], fill=(130, 68, 48, 255), outline=OUTLINE)
    draw.ellipse((14, 18, 50, 42), fill=fill, outline=OUTLINE)


def draw_scoop(draw: ImageDraw.ImageDraw, recipe: dict) -> None:
    name = recipe["dishName"].lower()
    fill = INGREDIENT_COLORS["rice"] if "rice" in name or "pilaf" in name else lighten(primary_color(recipe), 18)
    draw_bowl(draw, fill)
    if "rice" in name or "pilaf" in name:
        for x, y in topping_points(recipe["dishName"] + " grains", 14, (19, 22, 44, 35)):
            draw.rectangle((x, y, x + 3, y + 1), fill=(255, 255, 246, 255))
    draw_toppings(draw, recipe, (18, 21, 45, 36), 9, 2)


def draw_cup(draw: ImageDraw.ImageDraw, recipe: dict) -> None:
    name = recipe["dishName"].lower()
    cup = (222, 205, 169, 255)
    stew = INGREDIENT_COLORS["beans"] if "bean" in name or "chili" in name else primary_color(recipe)
    draw.polygon([(15, 21), (50, 21), (45, 55), (20, 55)], fill=cup, outline=OUTLINE)
    draw.ellipse((14, 16, 51, 30), fill=lighten(cup, 18), outline=OUTLINE)
    draw.ellipse((18, 19, 47, 30), fill=stew, outline=OUTLINE)
    draw.rectangle((20, 29, 45, 48), fill=darken(cup, 18), outline=OUTLINE)
    draw.rectangle((25, 33, 40, 42), fill=lighten(cup, 14), outline=(139, 88, 59, 255))
    draw_toppings(draw, recipe, (20, 20, 45, 29), 7, 2)


def draw_taco(draw: ImageDraw.ImageDraw, recipe: dict) -> None:
    shell = (232, 184, 92, 255)
    draw.arc((10, 18, 54, 58), 180, 360, fill=OUTLINE, width=3)
    draw.pieslice((10, 18, 54, 58), 180, 360, fill=shell, outline=OUTLINE)
    draw.polygon([(15, 38), (49, 38), (44, 52), (20, 52)], fill=darken(shell, 35), outline=OUTLINE)
    draw_toppings(draw, recipe, (17, 27, 47, 39), 11, 3)


def draw_wrap(draw: ImageDraw.ImageDraw, recipe: dict) -> None:
    tortilla = (232, 202, 153, 255)
    draw.polygon([(13, 23), (50, 18), (55, 41), (20, 52)], fill=tortilla, outline=OUTLINE)
    draw.polygon([(20, 27), (43, 24), (47, 39), (24, 45)], fill=lighten(tortilla, 16), outline=(154, 102, 62, 255))
    draw.line([(22, 27), (24, 45)], fill=(171, 109, 64, 255), width=2)
    draw.line([(43, 24), (47, 39)], fill=(171, 109, 64, 255), width=2)
    draw_toppings(draw, recipe, (25, 27, 45, 38), 8, 2)


def draw_dumpling(draw: ImageDraw.ImageDraw, recipe: dict) -> None:
    dough = (232, 213, 180, 255)
    for x, y in [(13, 35), (25, 28), (37, 35)]:
        draw.ellipse((x, y, x + 19, y + 17), fill=dough, outline=OUTLINE)
        draw.line([(x + 5, y + 4), (x + 13, y + 14)], fill=(173, 132, 88, 255), width=1)
    draw_toppings(draw, recipe, (18, 31, 49, 45), 5, 2)


def draw_pancake(draw: ImageDraw.ImageDraw, recipe: dict) -> None:
    cake = (211, 159, 83, 255)
    for y in [41, 34, 27]:
        draw.ellipse((15, y, 50, y + 13), fill=cake, outline=OUTLINE)
        draw.rectangle((17, y + 4, 48, y + 8), fill=lighten(cake, 18))
    if "rice" in recipe["dishName"].lower():
        draw_toppings(draw, recipe, (19, 25, 46, 39), 8, 2)
    else:
        syrup = INGREDIENT_COLORS["spices"]
        draw.rectangle((30, 25, 38, 33), fill=INGREDIENT_COLORS["eggs"], outline=OUTLINE)
        draw.line([(34, 33), (32, 45)], fill=syrup, width=2)


def draw_flat_piece(draw: ImageDraw.ImageDraw, recipe: dict) -> None:
    bread = (219, 176, 104, 255)
    draw.polygon([(12, 34), (33, 19), (54, 32), (46, 50), (17, 48)], fill=bread, outline=OUTLINE)
    draw.polygon([(18, 35), (33, 25), (47, 33), (42, 43), (21, 43)], fill=lighten(bread, 15), outline=(154, 102, 62, 255))
    draw_toppings(draw, recipe, (19, 29, 45, 41), 9, 2)


def draw_serving(draw: ImageDraw.ImageDraw, recipe: dict) -> None:
    pan = (89, 91, 88, 255)
    draw.ellipse((12, 30, 52, 55), fill=pan, outline=DEEP)
    draw.rectangle((48, 39, 61, 44), fill=pan, outline=DEEP)
    draw.ellipse((16, 25, 48, 47), fill=primary_color(recipe), outline=OUTLINE)
    draw_toppings(draw, recipe, (18, 27, 46, 42), 10, 2)


def draw_piece(draw: ImageDraw.ImageDraw, recipe: dict) -> None:
    name = recipe["dishName"].lower()
    family = recipe.get("dishFamily", "").lower()
    if "taco" in name:
        draw_taco(draw, recipe)
    elif "burrito" in name or "wrap" in family:
        draw_wrap(draw, recipe)
    elif "dumpling" in name:
        draw_dumpling(draw, recipe)
    elif "pancake" in name or "cake" in name:
        draw_pancake(draw, recipe)
    elif "quesadilla" in name or "flatbread" in name or "pupusa" in name:
        draw_flat_piece(draw, recipe)
    else:
        draw_flat_piece(draw, recipe)


def draw_recipe(recipe: dict) -> Image.Image:
    img = canvas()
    draw = ImageDraw.Draw(img)
    shadow(draw)
    unit = recipe.get("partUnitSingular", "piece")
    if unit == "slice":
        draw_slice(draw, recipe)
    elif unit == "scoop":
        draw_scoop(draw, recipe)
    elif unit == "cup":
        draw_cup(draw, recipe)
    elif unit == "serving":
        draw_serving(draw, recipe)
    else:
        draw_piece(draw, recipe)
    return img


def clear_pngs(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)
    for png in path.glob("*.png"):
        png.unlink()


def make_preview(recipes: list[dict], source_dir: Path, target: Path) -> None:
    tile_w, tile_h = 96, 92
    columns = 8
    rows = math.ceil(len(recipes) / columns)
    sheet = Image.new("RGBA", (tile_w * columns, tile_h * rows), (0, 0, 0, 0))
    draw = ImageDraw.Draw(sheet)
    for index, recipe in enumerate(recipes):
        x0 = (index % columns) * tile_w
        y0 = (index // columns) * tile_h
        bg = (245, 230, 210, 255) if index % 2 == 0 else (235, 215, 190, 255)
        draw.rectangle((x0, y0, x0 + tile_w - 1, y0 + tile_h - 1), fill=bg)
        slug = slugify(recipe["dishName"])
        icon = Image.open(source_dir / f"{slug}_64.png").convert("RGBA")
        sheet.alpha_composite(icon, (x0 + 16, y0 + 4))
        draw.rectangle((x0, y0 + 68, x0 + tile_w - 1, y0 + tile_h - 1), fill=(95, 59, 39, 225))
        label = recipe["dishName"]
        if len(label) > 14:
            label = label[:13] + "."
        draw.text((x0 + 4, y0 + 72), label, fill=(255, 237, 197, 255))
        draw.text((x0 + 4, y0 + 82), recipe["partUnitSingular"], fill=(255, 237, 197, 255))
    sheet.save(target)


def main() -> None:
    with CATALOG_PATH.open("r", encoding="utf-8") as handle:
        catalog = json.load(handle)
    recipes = catalog.get("recipes", [])
    if len(recipes) != 32:
        raise SystemExit(f"Expected 32 recipes, found {len(recipes)}")

    clear_pngs(CLIENT_OUT)
    clear_pngs(ART_OUT)

    seen: set[str] = set()
    for recipe in recipes:
        slug = slugify(recipe["dishName"])
        if slug in seen:
            raise SystemExit(f"Duplicate dish art slug: {slug}")
        seen.add(slug)
        image = draw_recipe(recipe)
        client_path = CLIENT_OUT / f"{slug}_64.png"
        art_path = ART_OUT / f"{slug}_64.png"
        image.save(client_path)
        shutil.copy2(client_path, art_path)

    make_preview(recipes, CLIENT_OUT, ART_OUT / "dish_piece_preview_sheet.png")
    print(f"Generated {len(recipes)} dish piece icons in {CLIENT_OUT}")
    print(f"Preview sheet: {ART_OUT / 'dish_piece_preview_sheet.png'}")


if __name__ == "__main__":
    main()
