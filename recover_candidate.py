from pathlib import Path
from PIL import Image

src = Path(r".\recovered_vehicle_images\vehicle_1783934205015-183514605.jpg")
dst = Path(r".\recovered_jpeg_attempt\candidate_even_bytes.jpg")

b = src.read_bytes()

# เอา byte ตำแหน่ง 0,2,4,6,... ออกมา
candidate = b[0::2]

print("Original:", len(b))
print("Candidate:", len(candidate))
print("Candidate first 32 bytes:")
print(" ".join(f"{x:02X}" for x in candidate[:32]))

dst.parent.mkdir(parents=True, exist_ok=True)
dst.write_bytes(candidate)

print()
print("Written:", dst)

try:
    im = Image.open(dst)

    print("FORMAT:", im.format)
    print("SIZE:", im.size)

    im.verify()

    print("JPEG VALID")

except Exception as e:
    print("JPEG INVALID")
    print(type(e).__name__ + ":", e)