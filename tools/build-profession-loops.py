#!/usr/bin/env python3
"""Bake forward-only profession loops from the recorded client BLPs.

Build-only dependencies: numpy, Pillow, ImageMagick. No runtime addon dependency.
Input files: <source-dir>/pyresin-atlas-<fileDataID>.blp, extracted from the client.
"""
import argparse
import hashlib
from io import BytesIO
import json
from pathlib import Path
import struct
import subprocess
import tempfile

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'Media' / 'CastBar'


def blend(first, second, weight):
    """Interpolate premultiplied RGBA, then store straight alpha for WoW BLEND."""
    alpha = first[..., 3:4] * (1 - weight) + second[..., 3:4] * weight
    color = first[..., :3] * first[..., 3:4] * (1 - weight) + second[..., :3] * second[..., 3:4] * weight
    color = np.divide(color, alpha, out=np.zeros_like(color), where=alpha > 0)
    return np.concatenate((color, alpha), axis=-1)


def make_loop(frames):
    overlap = int(len(frames) * .15 + .5)  # 300 ms of the original two-second cycle.
    result = frames[:-overlap].copy()
    t = np.linspace(0, 1, overlap).reshape(-1, 1, 1, 1)
    t = t * t * (3 - 2 * t)
    result[:overlap] = blend(frames[-overlap:], frames[:overlap], t)
    result[0], result[overlap - 1] = frames[-overlap], frames[overlap - 1]
    # The loop boundary now traverses two adjacent original frames.
    assert np.allclose(result[-1], frames[-overlap - 1])
    assert np.allclose(result[0], frames[-overlap])
    return result


def check():
    first = np.array([.7, .4, .1, .45])
    second = np.array([.1, .8, .3, .8])
    for weight in np.linspace(0, 1, 101):
        pixel = blend(first, second, weight)
        for opacity in (.2, 1):
            for background in (0, .2, .8):
                actual = pixel[:3] * pixel[3] * opacity + background * (1 - pixel[3] * opacity)
                a = first[:3] * first[3] * opacity + background * (1 - first[3] * opacity)
                b = second[:3] * second[3] * opacity + background * (1 - second[3] * opacity)
                assert np.allclose(actual, a * (1 - weight) + b * weight)
        assert np.allclose(blend(first, first, weight), first)
    frames = np.random.default_rng(0).random((60, 2, 3, 4))
    loop = make_loop(frames)
    assert len(loop) == 51 and np.array_equal(loop[9:], frames[9:51])
    transparent = np.zeros_like(frames)
    assert np.isfinite(make_loop(transparent)).all()
    print('PASS: original color/coverage reference, transparent pixels, forward sequence and adjacent-frame wrap')


def build(source_dir):
    sources = json.loads((DEST / 'sources.json').read_text())['sources']
    for source in sources:
        data = (source_dir / f"pyresin-atlas-{source['id']}.blp").read_bytes()
        assert hashlib.sha256(data).hexdigest() == source['sha256'], f"Source changed: {source['id']}"
        magic, version, encoding, depth, _, _, width, height = struct.unpack_from('<4sI4BII', data)
        assert (magic, version, encoding, depth) == (b'BLP2', 1, 3, 8)
        offset = struct.unpack_from('<I', data, 20)[0]
        pixels = np.frombuffer(data, dtype=np.uint8, offset=offset, count=width * height * 4).reshape(height, width, 4)[..., [2, 1, 0, 3]]
        x, y, w, h = (source[key] for key in ('x', 'y', 'width', 'height'))
        rows = h // 34
        frames = pixels[y:y+h, x:x+w].reshape(rows, 34, 2, w // 2, 4).transpose(0, 2, 1, 3, 4).reshape(rows * 2, 34, w // 2, 4)
        frames = make_loop(frames.astype(np.float64) / 255)
        assert len(frames) <= 64
        atlas = Image.new('RGBA', (1024, 1024))
        for index, frame in enumerate(frames):
            cell = Image.fromarray(np.rint(frame * 255).astype(np.uint8)).resize((512, 32), Image.Resampling.LANCZOS)
            atlas.paste(cell, ((index % 2) * 512, (index // 2) * 32))
        with tempfile.TemporaryDirectory() as directory:
            png, dds = Path(directory) / 'loop.png', Path(directory) / 'loop.dds'
            atlas.save(png)
            subprocess.run(['magick', str(png), '-define', 'dds:compression=dxt5', '-define', 'dds:cluster-fit=true', '-define', 'dds:mipmaps=0', str(dds)], check=True)
            compressed = dds.read_bytes()
        assert compressed[:4] == b'DDS ' and compressed[84:88] == b'DXT5'
        blocks = compressed[128:]
        assert len(blocks) == 1024 * 1024
        header = struct.pack('<4sI4BII', b'BLP2', 1, 2, 8, 7, 0, 1024, 1024)
        header += struct.pack('<16I', 148, *([0] * 15))
        header += struct.pack('<16I', len(blocks), *([0] * 15))
        target = DEST / f"Loop-{source['id']}.blp"
        target.write_bytes(header + blocks)
        # Decode the shipped format, not just the intermediate image.
        # Pillow's BLP decoder truncates RGB565 (255 becomes 248). Decode
        # the identical BC3 blocks via its native DDS decoder instead.
        decoded = np.asarray(Image.open(BytesIO(compressed[:128] + target.read_bytes()[148:]))).astype(float) / 255
        reference = np.asarray(atlas).astype(float) / 255
        for background in (0, .8):
            def composite(image):
                return image[..., :3] * image[..., 3:4] + background * (1 - image[..., 3:4])
            error = np.mean(np.abs(composite(decoded) - composite(reference)))
            bias = np.abs(np.mean(composite(decoded) - composite(reference), axis=(0, 1))).max()
            assert error < .01 and bias < .003
        print(f"{source['name']}: {rows * 2} -> {len(frames)} frames, {2 * len(frames) / (rows * 2):.3f}s, {target.stat().st_size} bytes")


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-dir', type=Path)
    args = parser.parse_args()
    check()
    if args.source_dir:
        build(args.source_dir)
