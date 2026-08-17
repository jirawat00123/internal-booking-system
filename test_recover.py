from pathlib import Path

src = Path(r".\recovered_vehicle_images\vehicle_1783934205015-183514605.jpg")
dst = Path(r".\recovered_jpeg_attempt\test1.jpg")

b = src.read_bytes()

print("Original:", len(b), "bytes")
print("Header:", b[:32].hex(" "))

out = bytearray()

for i in range(0, len(b) - 1, 2):
    out.append(b[i])

print("Candidate:", len(out), "bytes")
print("Candidate header:", out[:32].hex(" "))

dst.write_bytes(out)

print("Written:", dst)
