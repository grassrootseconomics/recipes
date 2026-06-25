from PIL import Image, ImageDraw
import os


repo_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
out_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "avatars")
client_out_dir = os.path.join(repo_root, "client", "art", "avatars")
os.makedirs(out_dir, exist_ok=True)
os.makedirs(client_out_dir, exist_ok=True)

SIZE = 32

OUTLINE = (64, 42, 31, 255)
DEEP = (45, 30, 24, 255)
SHADOW = (70, 45, 28, 78)


def canvas():
    return Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))


def save(img, name):
    path = os.path.join(out_dir, name)
    img.save(path)
    img.save(os.path.join(client_out_dir, name))
    return path


def shadow(draw):
    draw.ellipse((8, 26, 24, 31), fill=SHADOW)


def head(draw, x, y, skin, hair=None):
    if hair:
        draw.ellipse((x - 5, y - 5, x + 5, y + 5), fill=hair, outline=OUTLINE)
    draw.ellipse((x - 4, y - 4, x + 4, y + 5), fill=skin, outline=OUTLINE)
    draw.rectangle((x - 2, y + 5, x + 2, y + 8), fill=skin)


def legs(draw, x, y, color):
    draw.rectangle((x - 4, y, x - 2, y + 5), fill=color, outline=OUTLINE)
    draw.rectangle((x + 2, y, x + 4, y + 5), fill=color, outline=OUTLINE)
    draw.rectangle((x - 5, y + 5, x - 1, y + 6), fill=DEEP)
    draw.rectangle((x + 1, y + 5, x + 5, y + 6), fill=DEEP)


def cook_1():
    img = canvas()
    d = ImageDraw.Draw(img)
    shadow(d)
    skin = (195, 126, 81, 255)
    # Very tall chef hat, square white coat, and a dark ladle.
    d.rectangle((9, 5, 21, 9), fill=(245, 238, 221, 255), outline=OUTLINE)
    d.ellipse((6, 0, 14, 9), fill=(255, 252, 240, 255), outline=OUTLINE)
    d.ellipse((12, -1, 21, 9), fill=(255, 252, 240, 255), outline=OUTLINE)
    d.ellipse((19, 1, 27, 9), fill=(239, 231, 214, 255), outline=OUTLINE)
    head(d, 16, 11, skin)
    d.rectangle((8, 18, 24, 28), fill=(237, 231, 214, 255), outline=OUTLINE)
    d.line((16, 19, 16, 28), fill=(177, 163, 145, 255), width=1)
    d.rectangle((11, 21, 21, 24), fill=(69, 132, 153, 255), outline=OUTLINE)
    d.line((25, 13, 28, 25), fill=DEEP, width=2)
    d.ellipse((26, 23, 30, 28), fill=DEEP)
    legs(d, 16, 27, (57, 77, 92, 255))
    return img


def cook_2():
    img = canvas()
    d = ImageDraw.Draw(img)
    shadow(d)
    skin = (91, 54, 38, 255)
    hair = (35, 24, 20, 255)
    # Two big side buns, squat green apron, and bright sleeves.
    d.ellipse((4, 8, 13, 18), fill=hair, outline=OUTLINE)
    d.ellipse((19, 8, 28, 18), fill=hair, outline=OUTLINE)
    head(d, 16, 10, skin, hair)
    d.rectangle((7, 18, 25, 27), fill=(73, 147, 83, 255), outline=OUTLINE)
    d.rectangle((8, 16, 13, 25), fill=(240, 218, 154, 255), outline=OUTLINE)
    d.rectangle((19, 16, 24, 25), fill=(240, 218, 154, 255), outline=OUTLINE)
    d.rectangle((13, 20, 19, 23), fill=(44, 91, 58, 255))
    d.rectangle((4, 22, 8, 24), fill=(240, 218, 154, 255), outline=OUTLINE)
    d.rectangle((24, 22, 28, 24), fill=(240, 218, 154, 255), outline=OUTLINE)
    legs(d, 16, 27, (51, 80, 56, 255))
    return img


def cook_3():
    img = canvas()
    d = ImageDraw.Draw(img)
    shadow(d)
    skin = (118, 72, 48, 255)
    hair = (39, 31, 27, 255)
    # Angular yellow head wrap, long red dress, and raised arms.
    d.polygon([(6, 6), (17, 0), (27, 7), (22, 12), (10, 11)], fill=(242, 195, 82, 255), outline=OUTLINE)
    d.rectangle((10, 8, 22, 11), fill=(207, 120, 49, 255), outline=OUTLINE)
    head(d, 16, 12, skin, hair)
    d.polygon([(8, 18), (24, 18), (28, 30), (4, 30)], fill=(191, 58, 48, 255), outline=OUTLINE)
    d.rectangle((12, 21, 20, 25), fill=(255, 217, 126, 255), outline=OUTLINE)
    d.line((9, 18, 3, 13), fill=OUTLINE, width=2)
    d.line((23, 18, 29, 13), fill=OUTLINE, width=2)
    legs(d, 16, 28, (84, 48, 46, 255))
    return img


def cook_4():
    img = canvas()
    d = ImageDraw.Draw(img)
    shadow(d)
    skin = (216, 143, 91, 255)
    hair = (33, 31, 30, 255)
    # Wide blue cap, narrow overalls, and a long spatula.
    d.rectangle((8, 4, 22, 8), fill=(77, 111, 169, 255), outline=OUTLINE)
    d.rectangle((20, 6, 29, 8), fill=(77, 111, 169, 255), outline=OUTLINE)
    head(d, 16, 11, skin, hair)
    d.rectangle((11, 18, 21, 28), fill=(61, 111, 170, 255), outline=OUTLINE)
    d.rectangle((12, 16, 14, 25), fill=(237, 217, 159, 255), outline=OUTLINE)
    d.rectangle((18, 16, 20, 25), fill=(237, 217, 159, 255), outline=OUTLINE)
    d.rectangle((13, 20, 19, 24), fill=(44, 75, 116, 255))
    d.line((8, 19, 3, 29), fill=(153, 91, 47, 255), width=2)
    d.rectangle((1, 27, 6, 30), fill=(153, 91, 47, 255), outline=OUTLINE)
    legs(d, 16, 27, (42, 68, 106, 255))
    return img


def cook_5():
    img = canvas()
    d = ImageDraw.Draw(img)
    shadow(d)
    skin = (109, 72, 45, 255)
    # Tall purple hair silhouette and wide skirt.
    d.ellipse((8, 0, 24, 15), fill=(54, 34, 30, 255), outline=OUTLINE)
    d.rectangle((9, 8, 23, 16), fill=(54, 34, 30, 255))
    head(d, 16, 12, skin)
    d.polygon([(10, 18), (22, 18), (30, 30), (2, 30)], fill=(134, 85, 159, 255), outline=OUTLINE)
    d.rectangle((13, 20, 19, 24), fill=(230, 199, 119, 255), outline=OUTLINE)
    d.line((9, 20, 3, 18), fill=(109, 72, 45, 255), width=2)
    d.line((23, 20, 29, 18), fill=(109, 72, 45, 255), width=2)
    legs(d, 16, 28, (74, 45, 92, 255))
    return img


def cook_6():
    img = canvas()
    d = ImageDraw.Draw(img)
    shadow(d)
    skin = (167, 98, 57, 255)
    hair = (56, 34, 25, 255)
    # Large turban, orange tunic, pointed beard.
    d.ellipse((6, 1, 26, 13), fill=(231, 232, 207, 255), outline=OUTLINE)
    d.rectangle((7, 6, 25, 10), fill=(217, 162, 79, 255), outline=OUTLINE)
    head(d, 16, 12, skin, hair)
    d.polygon([(11, 16), (21, 16), (18, 24), (14, 24)], fill=hair, outline=OUTLINE)
    d.rectangle((7, 19, 25, 28), fill=(214, 112, 51, 255), outline=OUTLINE)
    d.line((16, 19, 16, 28), fill=(111, 62, 40, 255), width=1)
    d.rectangle((11, 21, 21, 24), fill=(244, 195, 89, 255), outline=OUTLINE)
    d.line((25, 20, 30, 16), fill=(244, 195, 89, 255), width=2)
    legs(d, 16, 27, (93, 59, 42, 255))
    return img


def cook_7():
    img = canvas()
    d = ImageDraw.Draw(img)
    shadow(d)
    skin = (228, 166, 106, 255)
    hair = (39, 33, 30, 255)
    # Big curly hair, glasses, teal coat, and open arms.
    for bb in [(6, 5, 14, 13), (12, 1, 20, 10), (18, 5, 26, 13), (8, 10, 24, 18)]:
        d.ellipse(bb, fill=hair, outline=OUTLINE)
    head(d, 16, 12, skin)
    d.rectangle((11, 12, 14, 15), outline=DEEP)
    d.rectangle((18, 12, 21, 15), outline=DEEP)
    d.line((14, 13, 18, 13), fill=DEEP)
    d.rectangle((8, 19, 24, 28), fill=(63, 154, 147, 255), outline=OUTLINE)
    d.rectangle((12, 20, 20, 26), fill=(239, 224, 179, 255), outline=OUTLINE)
    d.line((8, 21, 2, 26), fill=OUTLINE, width=2)
    d.line((24, 21, 30, 26), fill=OUTLINE, width=2)
    legs(d, 16, 27, (44, 92, 91, 255))
    return img


def cook_8():
    img = canvas()
    d = ImageDraw.Draw(img)
    shadow(d)
    skin = (146, 84, 50, 255)
    hair = (35, 23, 20, 255)
    # Green bandana, striped shirt, brown apron, and tiny pan.
    d.polygon([(6, 6), (17, 1), (27, 7), (23, 12), (9, 10)], fill=(77, 142, 91, 255), outline=OUTLINE)
    d.rectangle((9, 8, 24, 11), fill=(231, 196, 92, 255), outline=OUTLINE)
    head(d, 16, 12, skin, hair)
    d.rectangle((7, 19, 25, 28), fill=(239, 215, 153, 255), outline=OUTLINE)
    for y in [20, 23, 26]:
        d.line((8, y, 24, y), fill=(169, 63, 52, 255), width=1)
    d.rectangle((10, 18, 22, 28), fill=(122, 74, 48, 210), outline=OUTLINE)
    d.rectangle((13, 21, 19, 24), fill=(189, 122, 73, 255), outline=OUTLINE)
    d.line((5, 20, 1, 17), fill=DEEP, width=2)
    d.ellipse((0, 15, 6, 19), fill=(68, 54, 45, 255), outline=OUTLINE)
    legs(d, 16, 27, (70, 50, 43, 255))
    return img


COOKS = [cook_1, cook_2, cook_3, cook_4, cook_5, cook_6, cook_7, cook_8]


def make_preview():
    tile = 48
    sheet = Image.new("RGBA", (tile * 4, tile * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(sheet)
    for index in range(8):
        x = (index % 4) * tile
        y = (index // 4) * tile
        for yy in range(y, y + tile, 8):
            for xx in range(x, x + tile, 8):
                color = (245, 230, 210, 255) if ((xx // 8 + yy // 8) % 2 == 0) else (235, 215, 190, 255)
                d.rectangle((xx, yy, xx + 7, yy + 7), fill=color)
        img = Image.open(os.path.join(out_dir, f"cook_{index + 1}_32.png")).convert("RGBA")
        sheet.alpha_composite(img, (x + 8, y + 4))
        d.text((x + 5, y + 37), f"Cook {index + 1}", fill=(55, 38, 28, 255))
    sheet.save(os.path.join(out_dir, "cook_avatar_preview_sheet.png"))


def main():
    print("Created:")
    for index, maker in enumerate(COOKS, start=1):
        path = save(maker(), f"cook_{index}_32.png")
        print(path)
    make_preview()
    print(os.path.join(out_dir, "cook_avatar_preview_sheet.png"))


if __name__ == "__main__":
    main()
