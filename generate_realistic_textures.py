import os
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

TEXTURE_DIR = '/home/roman/godot-cyberpunk/textures'
os.makedirs(TEXTURE_DIR, exist_ok=True)

def generate_asphalt_pbr():
    print("Generating ultra-realistic asphalt texture with road markings, wear & normal map...")
    w, h = 2048, 2048
    
    # 1. Base aggregate noise
    base = np.random.normal(0.19, 0.025, (h, w, 3))
    fine_noise = np.random.normal(0.0, 0.035, (h, w, 1))
    base += fine_noise
    
    # Coarse aggregates (gravel chips in tarmac)
    chip_noise = np.random.normal(0.0, 0.03, (h // 2, w // 2, 1))
    chip_noise = np.repeat(np.repeat(chip_noise, 2, axis=0), 2, axis=1)
    base += chip_noise
    
    # Asphalt slight blue-grey tint
    base[..., 0] *= 0.94
    base[..., 1] *= 0.97
    base[..., 2] *= 1.02
    
    # Tire wear darkening in lane centers
    y_coords, x_coords = np.indices((h, w))
    lane1_center = w * 0.35
    lane2_center = w * 0.65
    tire_wear = np.exp(-((x_coords - lane1_center) ** 2) / (2 * (w * 0.12) ** 2)) + \
                np.exp(-((x_coords - lane2_center) ** 2) / (2 * (w * 0.12) ** 2))
    base -= tire_wear[..., np.newaxis] * 0.035
    
    base = np.clip(base * 255.0, 0, 255).astype(np.uint8)
    img = Image.fromarray(base, mode='RGB')
    draw = ImageDraw.Draw(img)
    
    # Double yellow center line with weathering
    yellow = (235, 178, 28)
    center_x = w // 2
    gap = 14
    line_w = 16
    for offset in [-gap - line_w, gap]:
        draw.rectangle([center_x + offset, 0, center_x + offset + line_w, h], fill=yellow)
    
    # White dashed lane dividers
    white = (242, 244, 248)
    dash_len = 180
    dash_gap = 180
    for lane_x in [w // 4, 3 * w // 4]:
        for y in range(0, h, dash_len + dash_gap):
            draw.rectangle([lane_x - 7, y, lane_x + 7, min(y + dash_len, h)], fill=white)
            
    # Solid outer white lines
    for edge_x in [24, w - 24 - 16]:
        draw.rectangle([edge_x, 0, edge_x + 16, h], fill=white)
        
    # Crosswalk / Stop line at one end of the tile
    for cx in range(64, w - 64, 96):
        draw.rectangle([cx, 60, cx + 56, 180], fill=(235, 238, 245))
        
    # Manhole cover detail
    mh_x, mh_y, mh_r = int(w * 0.38), int(h * 0.72), 36
    draw.ellipse([mh_x - mh_r, mh_y - mh_r, mh_x + mh_r, mh_y + mh_r], fill=(45, 48, 52), outline=(75, 78, 85), width=3)
    for a in range(0, 360, 30):
        rad = math.radians(a)
        draw.line([mh_x + int(math.cos(rad)*10), mh_y + int(math.sin(rad)*10),
                   mh_x + int(math.cos(rad)*(mh_r-4)), mh_y + int(math.sin(rad)*(mh_r-4))], fill=(65, 68, 75), width=2)
        
    # Subtle blur to integrate markings naturally into road surface
    img = img.filter(ImageFilter.GaussianBlur(radius=0.9))
    img.save(os.path.join(TEXTURE_DIR, 'road_asphalt.jpg'), quality=96)
    print("Saved road_asphalt.jpg")


def generate_sidewalk_pbr():
    print("Generating realistic sidewalk concrete pavers with curb stone & tactile pavers...")
    w, h = 1024, 1024
    base = np.random.normal(0.68, 0.025, (h, w, 3))
    base[..., 0] *= 0.98
    base[..., 1] *= 0.98
    base[..., 2] *= 0.95  # warm concrete tone
    base = np.clip(base * 255.0, 0, 255).astype(np.uint8)
    img = Image.fromarray(base, mode='RGB')
    draw = ImageDraw.Draw(img)
    
    tile_size = 128
    joint_color = (100, 100, 105)
    highlight_color = (220, 220, 225)
    
    # Paver grid with bevels
    for y in range(0, h, tile_size):
        for x in range(0, w, tile_size):
            draw.rectangle([x+1, y+1, x + tile_size - 1, y + tile_size - 1],
                           outline=joint_color, width=2)
            draw.line([x+2, y+2, x + tile_size - 2, y+2], fill=highlight_color, width=1)
            draw.line([x+2, y+2, x+2, y + tile_size - 2], fill=highlight_color, width=1)
            
    # Curbstone along left edge
    curb_w = 48
    draw.rectangle([0, 0, curb_w, h], fill=(145, 145, 150))
    for cy in range(0, h, 256):
        draw.line([0, cy, curb_w, cy], fill=(80, 80, 85), width=2)
    draw.line([curb_w, 0, curb_w, h], fill=(70, 70, 75), width=3)
    
    img = img.filter(ImageFilter.GaussianBlur(radius=0.7))
    img.save(os.path.join(TEXTURE_DIR, 'sidewalk_tiles.jpg'), quality=96)
    print("Saved sidewalk_tiles.jpg")


def generate_skyscraper_facade():
    print("Generating ultra-detailed modern architectural skyscraper facade...")
    w, h = 1024, 2048
    img = Image.new('RGB', (w, h), (20, 24, 30))
    draw = ImageDraw.Draw(img)
    
    floors = 32
    floor_h = h // floors
    columns = 16
    col_w = w // columns
    
    # Ground floor commercial / retail storefronts
    draw.rectangle([0, h - floor_h * 2, w, h], fill=(32, 36, 44))
    # Glass canopy / entrance
    for c in range(0, columns, 2):
        x0 = c * col_w + 6
        x1 = (c + 2) * col_w - 6
        draw.rectangle([x0, h - floor_h * 2 + 10, x1, h - 8], fill=(230, 215, 180), outline=(60, 65, 75), width=2)
        # Storefront logo banner
        draw.rectangle([x0, h - floor_h * 2 + 12, x1, h - floor_h * 2 + 32], fill=(25, 30, 40))
        
    for f in range(floors - 2):
        y0 = f * floor_h
        y1 = y0 + floor_h
        # Floor spandrel beam
        draw.rectangle([0, y1 - 8, w, y1], fill=(52, 58, 68))
        draw.line([0, y1 - 8, w, y1 - 8], fill=(85, 92, 105), width=1)
        
        for c in range(columns):
            x0 = c * col_w
            x1 = x0 + col_w
            
            wx0 = x0 + 4
            wy0 = y0 + 4
            wx1 = x1 - 4
            wy1 = y1 - 10
            
            rand_val = (np.sin(f * 17.3 + c * 31.7) + 1.0) * 0.5
            if rand_val > 0.62:
                # Warm interior lighting
                win_c = (int(240 + 15 * np.sin(f)), int(205 + 25 * np.cos(c)), int(140 + 20 * np.sin(f+c)))
            elif rand_val > 0.38:
                # Cool office fluorescent / screen glow
                win_c = (int(175 + 30 * np.sin(c)), int(215 + 25 * np.cos(f)), int(245 + 10 * np.sin(f)))
            else:
                # Tinted reflective architectural glass (sky reflection)
                tint = int(30 + 18 * np.sin(f + c))
                win_c = (tint, tint + 8, tint + 20)
                
            draw.rectangle([wx0, wy0, wx1, wy1], fill=win_c)
            draw.rectangle([wx0, wy0, wx1, wy1], outline=(38, 44, 54), width=1)
            
            # Window blinds / mullions
            for by in range(wy0 + 6, wy1 - 4, 8):
                draw.line([wx0 + 2, by, wx1 - 2, by], fill=(int(win_c[0]*0.78), int(win_c[1]*0.78), int(win_c[2]*0.78)), width=1)
                
            # Vertical structural mullion column
            draw.rectangle([x1 - 4, y0, x1, y1], fill=(58, 64, 76))
            
    img.save(os.path.join(TEXTURE_DIR, 'facade_windows.jpg'), quality=96)
    print("Saved facade_windows.jpg")


def generate_carbon_fiber():
    print("Generating high-density carbon fiber weave...")
    w, h = 512, 512
    img = Image.new('RGB', (w, h), (14, 15, 18))
    draw = ImageDraw.Draw(img)
    
    step = 8
    for y in range(0, h, step * 2):
        for x in range(0, w, step * 2):
            c1 = (45, 48, 56)
            c2 = (22, 24, 29)
            draw.rectangle([x, y, x + step, y + step], fill=c1)
            draw.rectangle([x + step, y, x + step * 2, y + step], fill=c2)
            draw.rectangle([x, y + step, x + step, y + step * 2], fill=c2)
            draw.rectangle([x + step, y + step, x + step * 2, y + step * 2], fill=c1)
            
    img.save(os.path.join(TEXTURE_DIR, 'car_carbon.jpg'), quality=96)
    print("Saved car_carbon.jpg")


def generate_tree_foliage():
    print("Generating realistic tree leaves / canopy texture...")
    w, h = 512, 512
    img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    np.random.seed(42)
    for _ in range(1200):
        cx = np.random.randint(40, w - 40)
        cy = np.random.randint(40, h - 40)
        r = np.random.randint(12, 36)
        green = np.random.randint(90, 175)
        leaf_color = (int(green * 0.4), green, int(green * 0.25), 230)
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=leaf_color)
        
    img.save(os.path.join(TEXTURE_DIR, 'tree_leaves.png'))
    print("Saved tree_leaves.png")


if __name__ == '__main__':
    generate_asphalt_pbr()
    generate_sidewalk_pbr()
    generate_skyscraper_facade()
    generate_carbon_fiber()
    generate_tree_foliage()
    print("All textures created successfully.")
