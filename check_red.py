from PIL import Image
im = Image.open('assets/avatar1.png').convert('RGBA')
red_pixels = []
for y in range(im.height):
    for x in range(im.width):
        r, g, b, a = im.getpixel((x, y))
        if r > 200 and g < 50 and b < 50 and a > 200:
            red_pixels.append((x, y))
print(f"Found {len(red_pixels)} red pixels")
if len(red_pixels) > 0:
    print(f"First red pixel at: {red_pixels[0]}")
    print(f"Last red pixel at: {red_pixels[-1]}")
