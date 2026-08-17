from pathlib import Path

src = Path(r".\recovered_vehicle_images\vehicle_1783934205015-183514605.jpg")
b = src.read_bytes()

print("SIZE:", len(b))
print()
print("FIRST 64 BYTES:")
print(" ".join(f"{x:02X}" for x in b[:64]))

print()
print("UTF-16LE CODE UNITS:")
for i in range(0, min(64, len(b)), 2):
    value = int.from_bytes(b[i:i+2], "little")
    print(f"{i:04X}: U+{value:04X}")
