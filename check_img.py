from PIL import Image
im = Image.open('assets/avatar1.png').convert('RGBA')
print(im.getpixel((im.width//2, 20)))
print(im.getpixel((im.width//2, 50)))
