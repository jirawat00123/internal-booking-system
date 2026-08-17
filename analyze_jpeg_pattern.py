from pathlib import Path

p = Path(r".\recovered_vehicle_images\vehicle_1783934205015-183514605.jpg")
b = p.read_bytes()

print("File:", p.name)
print("Size:", len(b))
print()

patterns = {
    "JPEG SOI FF D8 FF": bytes.fromhex("FF D8 FF"),
    "JPEG APP0 FF E0": bytes.fromhex("FF E0"),
    "JFIF ASCII": b"JFIF",
    "JFIF UTF16LE": b"J\x00F\x00I\x00F\x00",
    "Exif ASCII": b"Exif",
    "Exif UTF16LE": b"E\x00x\x00i\x00f\x00",
    "TIFF MM UTF16LE": b"M\x00M\x00",
}

for name, pattern in patterns.items():
    positions = []
    start = 0

    while True:
        pos = b.find(pattern, start)

        if pos == -1:
            break

        positions.append(pos)
        start = pos + 1

    print(f"{name}: {positions[:20]}")

print()
print("Bytes around JFIF:")

pos = b.find(b"J\x00F\x00I\x00F\x00")

if pos >= 0:
    start = max(0, pos - 32)
    end = min(len(b), pos + 64)

    print("Position:", pos)
    print(" ".join(f"{x:02X}" for x in b[start:end]))