from pathlib import Path

p = Path(r".\recovered_vehicle_images\vehicle_1783934205015-183514605.jpg")
b = p.read_bytes()

print("First 128 bytes:")
print(" ".join(f"{x:02X}" for x in b[:128]))

print()
print("UTF16 code units:")

for i in range(0, 128, 2):
    value = int.from_bytes(b[i:i+2], "little")
    print(f"U+{value:04X}", end=" ")

print()