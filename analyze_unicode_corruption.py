from pathlib import Path

src = Path(r".\recovered_vehicle_images\vehicle_1783934205015-183514605.jpg")
b = src.read_bytes()

print("FILE:", src.name)
print("SIZE:", len(b))
print()

# 1. UTF-16LE decode
text = b.decode("utf-16-le", errors="replace")

print("UTF-16LE characters:", len(text))
print("First 100 characters:")
print(repr(text[:100]))
print()

# 2. Show Unicode code points
print("First 40 code points:")
for i, ch in enumerate(text[:40]):
    print(
        f"{i:02d}: "
        f"U+{ord(ch):04X} "
        f"{repr(ch)}"
    )

print()

# 3. Try encoding the Unicode text back using UTF-16LE
roundtrip = text.encode("utf-16-le")

print("Roundtrip size:", len(roundtrip))
print("Original size :", len(b))
print("Same bytes    :", roundtrip == b)

print()

# 4. Look for important JPEG markers in Unicode code points
targets = {
    "JFIF": "JFIF",
    "Exif": "Exif",
}

for name, target in targets.items():
    pos = text.find(target)
    print(f"{name} position:", pos)

print()

# 5. Inspect characters around JFIF
pos = text.find("JFIF")

if pos >= 0:
    print("Characters around JFIF:")
    print(repr(text[max(0, pos - 20):pos + 40]))

    print()
    print("Code points around JFIF:")

    for i, ch in enumerate(text[max(0, pos - 20):pos + 40], start=max(0, pos - 20)):
        print(f"{i:04d}: U+{ord(ch):04X} {repr(ch)}")