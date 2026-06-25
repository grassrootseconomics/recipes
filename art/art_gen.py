from PIL import Image, ImageDraw
import os, zipfile, math

repo_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
out_dir = os.path.dirname(os.path.abspath(__file__))
client_ingredient_dir = os.path.join(repo_root, "client", "art", "ingredients")
os.makedirs(out_dir, exist_ok=True)
os.makedirs(client_ingredient_dir, exist_ok=True)

# Draw at 64x64 directly, no antialiasing, transparent canvas.
SIZE = 64

def canvas():
    return Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))

def save(img, name):
    path = os.path.join(out_dir, name)
    img.save(path)
    client_path = os.path.join(client_ingredient_dir, name)
    if os.path.isdir(client_ingredient_dir):
        img.save(client_path)
    return path

def dither_shadow(draw, cx=32, cy=52, rx=21, ry=6):
    # Pixel-art soft-ish oval shadow using flat transparent layers
    draw.ellipse((cx-rx, cy-ry, cx+rx, cy+ry), fill=(70, 38, 22, 70))
    draw.ellipse((cx-rx+5, cy-ry+2, cx+rx-5, cy+ry+1), fill=(70, 38, 22, 55))

outline = (83, 48, 31, 255)
deep = (60, 34, 25, 255)

# 1 Cheese wedge
img = canvas()
draw = ImageDraw.Draw(img)
dither_shadow(draw)
# cheese main body
draw.polygon([(10, 40), (33, 15), (54, 23), (53, 45), (10, 40)], fill=(244, 175, 49, 255), outline=outline)
draw.polygon([(33, 15), (54, 23), (53, 45), (41, 42), (40, 24)], fill=(196, 113, 42, 255), outline=outline)
draw.polygon([(10, 40), (33, 15), (40, 24), (41, 42)], fill=(255, 216, 93, 255), outline=outline)
# warm highlight strip
draw.polygon([(15, 37), (33, 18), (37, 21), (19, 39)], fill=(255, 235, 142, 255))
draw.line([(13, 41), (41, 44), (53, 46)], fill=(104, 58, 35, 255), width=2)
# holes
holes = [
    (20, 31, 26, 37), (31, 27, 36, 32), (33, 37, 40, 44),
    (43, 26, 48, 31), (45, 36, 50, 41)
]
for bb in holes:
    draw.ellipse(bb, fill=(176, 100, 38, 255), outline=(135, 75, 36, 255))
# tiny sparkle
draw.rectangle((20, 25, 23, 27), fill=(255, 242, 169, 255))
save(img, "cheese_64.png")

# 2 Open flour sack
img = canvas()
draw = ImageDraw.Draw(img)
dither_shadow(draw, cy=54, rx=22, ry=6)
# sack body behind
draw.polygon([(17, 21), (47, 21), (54, 34), (49, 55), (16, 55), (10, 34)],
             fill=(226, 202, 172, 255), outline=outline)
# side shadows and highlights
draw.polygon([(38, 22), (47, 21), (54, 34), (49, 55), (39, 55)], fill=(185, 139, 108, 255))
draw.polygon([(17, 22), (27, 22), (24, 54), (16, 55), (10, 34)], fill=(249, 235, 211, 255))
# rolled top lip
draw.polygon([(12, 20), (25, 14), (43, 14), (52, 20), (48, 27), (16, 27)],
             fill=(205, 163, 127, 255), outline=outline)
draw.polygon([(14, 18), (26, 12), (38, 13), (25, 24)], fill=(246, 228, 201, 255), outline=outline)
draw.polygon([(38, 13), (51, 18), (47, 25), (31, 24)], fill=(218, 184, 151, 255), outline=outline)
# flour mound inside
draw.ellipse((19, 8, 46, 26), fill=(239, 232, 215, 255), outline=outline)
draw.polygon([(23, 21), (29, 9), (37, 7), (44, 20), (39, 24), (28, 24)], fill=(255, 250, 238, 255))
draw.polygon([(32, 9), (46, 20), (39, 24), (34, 21)], fill=(232, 224, 207, 255))
draw.rectangle((27, 15, 34, 17), fill=(255, 255, 246, 255))
draw.rectangle((38, 17, 45, 19), fill=(255, 255, 246, 255))
# front label/creases
draw.line([(20, 31), (20, 51)], fill=(157, 108, 80, 255), width=1)
draw.line([(30, 32), (28, 53)], fill=(157, 108, 80, 255), width=1)
draw.line([(43, 31), (44, 52)], fill=(113, 72, 55, 255), width=2)
draw.rectangle((24, 34, 41, 44), fill=(236, 215, 182, 255), outline=(139, 88, 59, 255))
draw.rectangle((28, 37, 37, 39), fill=(255, 246, 220, 255))
# small spill
draw.ellipse((15, 52, 34, 59), fill=(238, 230, 213, 255))
draw.polygon([(18, 55), (26, 49), (32, 57)], fill=(255, 252, 240, 255))
save(img, "flour_open_sack_64.png")

# 3 Herbs tied bundle
img = canvas()
draw = ImageDraw.Draw(img)
dither_shadow(draw, cy=54, rx=18, ry=5)
# stems
stem = (118, 81, 44, 255)
for x2,y2 in [(25,18),(31,14),(37,17),(21,23),(42,22),(34,10)]:
    draw.line([(30,52),(x2,y2)], fill=stem, width=2)
# leaves, behind to front
leaf_dark = (58, 111, 53, 255)
leaf_mid = (92, 153, 67, 255)
leaf_light = (166, 208, 95, 255)
leaf_warm = (195, 213, 113, 255)
leaves = [
    (14, 22, 27, 35, leaf_dark), (20, 12, 34, 27, leaf_mid), (32, 13, 48, 27, leaf_mid),
    (10, 30, 25, 43, leaf_mid), (36, 28, 53, 42, leaf_dark), (25, 25, 41, 41, leaf_mid),
    (16, 8, 27, 20, leaf_dark), (36, 7, 47, 20, leaf_dark), (26, 6, 38, 18, leaf_mid),
    (21, 32, 36, 47, leaf_dark), (31, 30, 46, 47, leaf_mid)
]
for x1,y1,x2,y2,c in leaves:
    draw.ellipse((x1,y1,x2,y2), fill=c, outline=outline)
# leaf veins/highlights
for pts in [[(25,14),(30,25)], [(36,14),(40,25)], [(18,31),(26,39)], [(38,32),(45,40)], [(30,8),(32,17)]]:
    draw.line(pts, fill=leaf_light, width=1)
for bb in [(23,16,27,19),(34,16,38,19),(30,28,34,31),(39,33,43,36)]:
    draw.rectangle(bb, fill=leaf_warm)
# tie
draw.polygon([(23,42),(39,42),(42,48),(21,48)], fill=(207, 137, 64, 255), outline=outline)
draw.line([(22,45),(42,45)], fill=(253, 194, 104, 255), width=2)
save(img, "herbs_64.png")

# 4 Vegetables cluster
img = canvas()
draw = ImageDraw.Draw(img)
dither_shadow(draw, cy=54, rx=23, ry=6)
# leafy backdrop
for bb, c in [((12,20,29,39),(91,139,64,255)), ((25,14,43,35),(111,163,74,255)), ((38,22,54,42),(76,126,61,255))]:
    draw.ellipse(bb, fill=c, outline=outline)
draw.line([(20,23),(26,36)], fill=(166,204,96,255), width=1)
draw.line([(34,17),(35,34)], fill=(185,214,100,255), width=1)
# tomato
draw.ellipse((9,31,27,49), fill=(204, 61, 52, 255), outline=outline)
draw.polygon([(18,29),(16,33),(12,34),(16,36),(17,40),(20,36),(24,36),(21,33),(22,30)],
             fill=(87, 136, 58, 255), outline=outline)
draw.rectangle((14,35,18,39), fill=(245,129,100,255))
# carrot
draw.polygon([(36,25),(56,36),(43,53),(29,42)], fill=(229, 119, 42, 255), outline=outline)
draw.line([(38,30),(51,37)], fill=(250, 181, 91, 255), width=2)
draw.line([(35,36),(48,43)], fill=(250, 181, 91, 255), width=1)
draw.line([(34,41),(43,46)], fill=(250, 181, 91, 255), width=1)
# carrot greens
draw.line([(39,24),(38,16)], fill=(78,132,56,255), width=2)
draw.line([(39,24),(47,18)], fill=(78,132,56,255), width=2)
draw.line([(39,24),(31,17)], fill=(78,132,56,255), width=2)
# onion small
draw.ellipse((28,35,41,50), fill=(235, 207, 163, 255), outline=outline)
draw.rectangle((32,35,36,38), fill=(255, 236, 190, 255))
draw.line([(34,34),(33,29)], fill=(97, 135, 62, 255), width=1)
save(img, "vegetables_64.png")

# 5 Rice bowl
img = canvas()
draw = ImageDraw.Draw(img)
dither_shadow(draw, cy=54, rx=22, ry=6)
# bowl
draw.ellipse((13, 28, 51, 52), fill=(187, 101, 60, 255), outline=outline)
draw.rectangle((14, 37, 50, 45), fill=(187, 101, 60, 255))
draw.polygon([(14, 40), (50, 40), (43, 55), (21, 55)], fill=(145, 72, 48, 255), outline=outline)
draw.rectangle((19,43,45,46), fill=(208, 128, 75, 255))
# rice mound
draw.ellipse((15, 14, 49, 40), fill=(235, 229, 215, 255), outline=outline)
draw.polygon([(18,31),(26,18),(34,13),(45,25),(48,34),(28,37)], fill=(254, 249, 238, 255))
draw.polygon([(34,14),(46,25),(48,35),(38,36),(35,25)], fill=(226, 218, 204, 255))
# individual grains
for x,y in [(23,22),(28,19),(35,18),(40,23),(20,30),(31,28),(42,31),(26,34),(36,33)]:
    draw.rectangle((x,y,x+3,y+1), fill=(255,255,247,255))
    draw.point((x+4,y+1), fill=(216,204,188,255))
# chopsticks
draw.line([(48,12),(56,37)], fill=(112,76,43,255), width=2)
draw.line([(53,11),(58,36)], fill=(162,109,59,255), width=2)
save(img, "rice_64.png")

# 6 Beans
img = canvas()
draw = ImageDraw.Draw(img)
dither_shadow(draw, cy=54, rx=23, ry=6)
# small sack/bowl hybrid
draw.ellipse((12,34,52,55), fill=(154, 80, 53, 255), outline=outline)
draw.polygon([(13,41),(51,41),(45,56),(20,56)], fill=(116, 56, 42, 255), outline=outline)
draw.rectangle((19,44,45,47), fill=(186, 97, 61, 255))
# bean pile
bean_cols = [(134,62,49,255),(160,75,55,255),(104,49,40,255),(183,98,69,255)]
beans = [
    (13,27,23,37),(20,22,31,33),(29,25,40,36),(39,22,50,34),
    (18,34,29,45),(30,34,41,46),(42,32,53,44),(24,29,35,41)
]
for i,bb in enumerate(beans):
    draw.ellipse(bb, fill=bean_cols[i%len(bean_cols)], outline=outline)
    x1,y1,x2,y2 = bb
    draw.arc((x1+2,y1+3,x2-2,y2-2), start=180, end=330, fill=(213,124,92,255), width=1)
# loose beans
for bb in [(11,48,17,54),(48,49,56,55),(8,41,14,47)]:
    draw.ellipse(bb, fill=(160,75,55,255), outline=outline)
save(img, "beans_64.png")

# 7 Spices
img = canvas()
draw = ImageDraw.Draw(img)
dither_shadow(draw, cy=54, rx=22, ry=6)
# jar
draw.rectangle((30,14,49,46), fill=(231, 190, 144, 150), outline=outline)
draw.rectangle((30,14,49,20), fill=(129, 73, 45, 255), outline=outline)
draw.rectangle((32,24,47,44), fill=(205, 84, 43, 255), outline=outline)
draw.rectangle((33,25,37,42), fill=(247, 185, 105, 95))
draw.rectangle((41,25,47,44), fill=(144, 61, 41, 160))
draw.rectangle((35,17,45,18), fill=(218, 151, 81, 255))
# spoon with spice
draw.polygon([(11,42),(30,35),(33,39),(14,48)], fill=(151, 93, 58, 255), outline=outline)
draw.ellipse((9,36,24,49), fill=(202, 85, 42, 255), outline=outline)
draw.ellipse((13,39,22,46), fill=(235, 126, 54, 255))
draw.rectangle((15,40,20,42), fill=(255, 188, 95, 255))
# star anise / seeds
cx, cy = 23, 24
for ang in range(0,360,60):
    rad = math.radians(ang)
    x = cx + int(math.cos(rad)*8)
    y = cy + int(math.sin(rad)*5)
    draw.line([(cx,cy),(x,y)], fill=(110, 65, 38, 255), width=2)
draw.ellipse((20,21,26,27), fill=(166, 94, 50, 255), outline=outline)
for x,y,c in [(53,38,(238,183,77,255)),(55,42,(203,82,44,255)),(51,44,(119,72,42,255)),(25,50,(238,183,77,255))]:
    draw.rectangle((x,y,x+2,y+2), fill=c)
save(img, "spices_64.png")

# 8 Eggs
img = canvas()
draw = ImageDraw.Draw(img)
dither_shadow(draw, cy=54, rx=21, ry=6)
# small nest/bowl shadow
draw.ellipse((14,39,51,56), fill=(155, 95, 54, 255), outline=outline)
draw.arc((12,38,53,57), start=0, end=180, fill=(231, 168, 87, 255), width=3)
for pts in [[(16,46),(28,41),(40,48),(51,43)], [(14,50),(26,45),(42,52)], [(20,55),(34,48),(50,54)]]:
    draw.line(pts, fill=(103,65,38,255), width=2)
# back eggs first, then the front egg. Each egg keeps a full outline at card size.
egg_outline = (92, 55, 36, 255)
egg_shadow = (202, 171, 134, 255)
egg_mid = (233, 213, 183, 255)
egg_light = (255, 244, 217, 255)
draw.ellipse((13,20,32,50), fill=(245, 227, 196, 255), outline=egg_outline)
draw.polygon([(24,23),(31,31),(30,47),(23,50),(22,35)], fill=(225, 199, 165, 255))
draw.rectangle((18,26,22,31), fill=egg_light)
draw.ellipse((33,15,53,47), fill=(234, 213, 181, 255), outline=egg_outline)
draw.polygon([(46,18),(53,30),(50,44),(43,47),(44,31)], fill=egg_shadow)
draw.rectangle((38,22,42,27), fill=(249, 235, 206, 255))
draw.ellipse((23,23,44,54), fill=(252, 237, 207, 255), outline=egg_outline)
draw.polygon([(37,27),(44,39),(42,52),(34,54),(35,38)], fill=egg_mid)
draw.line([(25,48),(30,53),(40,54),(44,48)], fill=(113, 68, 43, 255), width=1)
draw.rectangle((29,30,34,35), fill=(255, 250, 226, 255))
save(img, "eggs_64.png")

# Create a preview sheet with a warm checker background behind each transparent asset
names = [
    ("Cheese", "cheese_64.png"),
    ("Flour", "flour_open_sack_64.png"),
    ("Herbs", "herbs_64.png"),
    ("Vegetables", "vegetables_64.png"),
    ("Rice", "rice_64.png"),
    ("Beans", "beans_64.png"),
    ("Spices", "spices_64.png"),
    ("Eggs", "eggs_64.png"),
]
tile = 96
sheet = Image.new("RGBA", (tile*4, tile*2), (0,0,0,0))
sd = ImageDraw.Draw(sheet)
for idx, (label, fn) in enumerate(names):
    x0 = (idx % 4) * tile
    y0 = (idx // 4) * tile
    # checkboard
    for yy in range(y0, y0+tile, 8):
        for xx in range(x0, x0+tile, 8):
            col = (245,230,210,255) if ((xx//8 + yy//8) % 2 == 0) else (235,215,190,255)
            sd.rectangle((xx, yy, xx+7, yy+7), fill=col)
    # paste icon centered
    icon = Image.open(os.path.join(out_dir, fn)).convert("RGBA")
    sheet.alpha_composite(icon, (x0+16, y0+10))
    # simple label
    sd.rectangle((x0, y0+76, x0+tile-1, y0+95), fill=(95, 59, 39, 230))
    sd.text((x0+6, y0+80), label, fill=(255, 237, 197, 255))
sheet_path = os.path.join(out_dir, "ingredient_8_icon_preview_sheet.png")
sheet.save(sheet_path)

# zip all individual transparent PNGs plus preview
zip_path = os.path.join(out_dir, "ingredient_pixel_art_8_pack.zip")
with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED) as z:
    for label, fn in names:
        z.write(os.path.join(out_dir, fn), arcname=fn)
    z.write(sheet_path, arcname="ingredient_8_icon_preview_sheet.png")

print("Created:")
for label, fn in names:
    print(f"{label}: {os.path.join(out_dir, fn)}")
print(f"Preview sheet: {sheet_path}")
print(f"ZIP: {zip_path}")
