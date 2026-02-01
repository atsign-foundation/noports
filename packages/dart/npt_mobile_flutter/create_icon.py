from PIL import Image, ImageDraw
import math

# Create 1024x1024 image
size = 1024
img = Image.new('RGB', (size, size), (240, 94, 62))  # Primary color background
draw = ImageDraw.Draw(img)

# Colors
white = (255, 255, 255, 255)
primary = (240, 94, 62)
center = size // 2

# Draw @ symbol in white
# Outer circle
outer_r = 280
line_width = 60
draw.ellipse([center-outer_r, center-outer_r, center+outer_r, center+outer_r], 
             outline=white, width=line_width)

# Inner dot
inner_r = 100
draw.ellipse([center-inner_r, center-inner_r, center+inner_r, center+inner_r], fill=white)

# Vertical tail
draw.line([(center, center+inner_r), (center, center+220)], fill=white, width=line_width)

# Curved part of tail
for i in range(90):
    angle1 = math.radians(270 + i)
    angle2 = math.radians(270 + i + 1)
    r = 170
    x1 = center + 170 + int(r * math.cos(angle1))
    y1 = center + 220 + int(r * math.sin(angle1))
    x2 = center + 170 + int(r * math.cos(angle2))
    y2 = center + 220 + int(r * math.sin(angle2))
    draw.line([(x1, y1), (x2, y2)], fill=white, width=line_width)

# Save
img.save('assets/app_icon.png')
print('App icon created at assets/app_icon.png')
