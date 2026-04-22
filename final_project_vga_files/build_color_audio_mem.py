from pathlib import Path

import numpy as np
from scipy.io import wavfile


ROOT = Path(__file__).resolve().parent
SOUND_DIR = ROOT.parent / "sound_effects"
OUT_MEM = ROOT / "color_audio.mem"

TARGET_SR = 8000
ORDER = [
    ("White", 1),
    ("Pink", 2),
    ("Red", 3),
    ("Orange", 4),
    ("Yellow", 5),
    ("Green", 6),
    ("Blue", 7),
    ("Purple", 8),
    ("Brown", 9),
    ("Black", 10),
]


def resample_linear(data: np.ndarray, src_sr: int, dst_sr: int) -> np.ndarray:
    if src_sr == dst_sr:
        return data.astype(np.float32)
    src_idx = np.arange(len(data), dtype=np.float32)
    dst_len = int(round(len(data) * dst_sr / src_sr))
    dst_idx = np.linspace(0, len(data) - 1, dst_len, dtype=np.float32)
    return np.interp(dst_idx, src_idx, data.astype(np.float32))


def main() -> None:
    samples = []
    offsets = {}
    lengths = {}
    cursor = 0

    for color_name, color_id in ORDER:
        wav_path = SOUND_DIR / f"{color_name}.wav"
        sr, data = wavfile.read(wav_path)
        if data.ndim > 1:
            data = data.mean(axis=1)
        data = resample_linear(data, sr, TARGET_SR)
        peak = float(np.max(np.abs(data))) or 1.0
        data = np.clip(data / peak, -1.0, 1.0)
        pcm_u8 = np.round((data * 127.0) + 128.0).astype(np.uint8)

        offsets[color_id] = cursor
        lengths[color_id] = len(pcm_u8)
        cursor += len(pcm_u8)
        samples.append(pcm_u8)

    merged = np.concatenate(samples)
    with OUT_MEM.open("w", encoding="ascii") as fh:
        for value in merged:
            fh.write(f"{int(value):02x}\n")

    print(f"wrote {OUT_MEM} with {len(merged)} samples at {TARGET_SR} Hz")
    for color_name, color_id in ORDER:
        print(
            f"{color_name:6s} color={color_id:2d} "
            f"offset={offsets[color_id]:6d} length={lengths[color_id]:6d}"
        )


if __name__ == "__main__":
    main()
