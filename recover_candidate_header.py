from pathlib import Path
from PIL import Image

src = Path(r".\recovered_vehicle_images\vehicle_1783934205015-183514605.jpg")
dst = Path(r".\recovered_jpeg_attempt\candidate_header_fixed.jpg")

b = src.read_bytes()

# Extract even-position bytes
candidate = bytearray(b[0::2])

print("Candidate length:", len(candidate))
print("Before:")
print(" ".join(f"{x:02X}" for x in candidate[:32]))

# Reconstruct standard JPEG/JFIF header
candidate[:5] = bytes.fromhex("FF D8 FF E0 00")

print()
print("After:")
print(" ".join(f"{x:02X}" for x in candidate[:32]))

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