from pathlib import Path
from collections import Counter

ROOT = Path(r".\recovered_vehicle_images")

files = sorted(ROOT.glob("*.jpg"))

print("FILES:", len(files))
print()

for f in files:
    b = f.read_bytes()

    print("=" * 90)
    print(f.name)
    print("SIZE:", len(b))

    print("FIRST 32:")
    print(" ".join(f"{x:02X}" for x in b[:32]))

    print("LAST 32:")
    print(" ".join(f"{x:02X}" for x in b[-32:]))

    print("BOM UTF16LE:", b.startswith(b"\xff\xfe"))
    print("JPEG SOI:", b.find(b"\xff\xd8\xff"))
    print("JFIF ASCII:", b.find(b"JFIF"))
    print("JFIF UTF16LE:", b.find(b"J\x00F\x00I\x00F\x00"))
    print("EXIF ASCII:", b.find(b"Exif"))
    print("EXIF UTF16LE:", b.find(b"E\x00x\x00i\x00f\x00"))

print()
print("=" * 90)
print("SIZE FREQUENCY")
print("=" * 90)

sizes = Counter(f.stat().st_size for f in files)

for size, count in sorted(sizes.items()):
    print(f"{size:10} bytes -> {count} files")