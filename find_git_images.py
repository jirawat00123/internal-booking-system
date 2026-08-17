import subprocess
from pathlib import Path
import hashlib

OUT = Path(".git-recovery")
OUT.mkdir(exist_ok=True)

# Get unreachable blobs
result = subprocess.run(
    ["git", "fsck", "--full", "--no-reflogs", "--unreachable"],
    capture_output=True,
    text=True,
    encoding="utf-8",
    errors="replace",
)

hashes = []

for line in result.stdout.splitlines():
    parts = line.split()

    if len(parts) == 3 and parts[0] == "unreachable" and parts[1] == "blob":
        hashes.append(parts[2])

print(f"Unreachable blobs: {len(hashes)}")

found = []

for i, h in enumerate(hashes, 1):
    try:
        data = subprocess.check_output(
            ["git", "cat-file", "blob", h]
        )

        # JPEG
        if data.startswith(b"\xff\xd8\xff"):
            ext = ".jpg"

        # PNG
        elif data.startswith(b"\x89PNG\r\n\x1a\n"):
            ext = ".png"

        # WebP
        elif data.startswith(b"RIFF") and data[8:12] == b"WEBP":
            ext = ".webp"

        else:
            continue

        path = OUT / f"{h}{ext}"

        path.write_bytes(data)

        found.append((h, ext, len(data), path))

        print(
            f"[IMAGE] {h} | {len(data):,} bytes | {ext}"
        )

    except Exception as e:
        print(f"[ERROR] {h}: {e}")

print()
print("=" * 70)
print(f"IMAGE BLOBS FOUND: {len(found)}")
print("=" * 70)

for h, ext, size, path in sorted(found, key=lambda x: x[2], reverse=True):
    print(f"{h} {size:>10,} {ext}")

print()
print(f"Recovered candidates are in: {OUT.resolve()}")