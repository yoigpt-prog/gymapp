import sys
from PIL import Image

def process_image(input_path, output_path):
    try:
        img = Image.open(input_path).convert("RGBA")
        datas = img.getdata()

        newData = []
        for item in datas:
            # item is (R, G, B, A)
            if item[3] > 0:  # If pixel is not completely transparent
                newData.append((255, 255, 255, item[3]))  # White with original alpha
            else:
                newData.append(item)

        img.putdata(newData)
        
        # Resize if necessary (e.g., to 96x96 or something reasonable for a notification icon)
        img.thumbnail((96, 96), Image.Resampling.LANCZOS)
        
        img.save(output_path, "PNG")
        print("Success:", output_path)
    except Exception as e:
        print("Error:", e)

if __name__ == "__main__":
    if len(sys.argv) == 3:
        process_image(sys.argv[1], sys.argv[2])
    else:
        print("Usage: script.py input output")
