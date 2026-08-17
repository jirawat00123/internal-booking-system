from pathlib import Path

src = Path(r".\recovered_vehicle_images\vehicle_1783934205015-183514605.jpg")
out = Path(r".\recovered_jpeg_attempt\utf16_reverse_test.bin")

b = src.read_bytes()

print("Original size:", len(b))
print("BOM:", b[:2].hex(" "))

# Decode current file as UTF-16LE
text = b.decode("utf-16le")

print("Characters:", len(text))
print("First 20 code points:")

for i, ch in enumerate(text[:20]):
    print(f"{i:02d}: U+{ord(ch):04X} {repr(ch)}")

# Encode characters back as UTF-8 ONLY FOR INSPECTION
utf8 = text.encode("utf-8")

print()
print("UTF-8 size:", len(utf8))
print("UTF-8 first 64:")
print(utf8[:64].hex(" "))

# Write UTF-8 diagnostic output
out.write_bytes(utf8)

print()
print("Written:", out)
