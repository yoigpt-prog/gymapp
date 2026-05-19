import re

file_path = '/Users/apple/Desktop/gymguide_app/lib/pages/profile_page.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace border colors in the two premium cards
old_border = """        border: Border.all(
          color: isDark ? Colors.white24 : Colors.black12,
          width: 1,
        ),"""

new_border = """        border: Border.all(
          color: isDark ? Colors.white : Colors.black,
          width: 1,
        ),"""

if old_border in content:
    content = content.replace(old_border, new_border)
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("Successfully updated borders.")
else:
    print("Border pattern not found!")

