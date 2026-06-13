from __future__ import annotations

import argparse
import json
import math
import subprocess
import wave
from dataclasses import dataclass
from enum import Enum
from pathlib import Path
from typing import Iterable

import numpy as np


TARGET_SAMPLE_RATE = 16_000


class Decision(str, Enum):
    ACCEPTED_CURRENT_USER = "accepted_current_user"
    REJECTED_NON_USER = "rejected_non_user"
    UNCERTAIN = "uncertain"


@dataclass(frozen=True)
class VoiceProfile:
    user_id: str
    embedding: np.ndarray
    sample_count: int
    extractor: str = "numpy-mfcc-prototype-v1"

    def to_json_dict(self) -> dict:
        return {
            "user_id": self.user_id,
            "sample_count": self.sample_count,
            "extractor": self.extractor,
            "embedding": self.embedding.tolist(),
        }

    @staticmethod
    def from_json_dict(data: dict) -> "VoiceProfile":
        return VoiceProfile(
            user_id=data["user_id"],
            embedding=np.array(data["embedding"], dtype=np.float32),
            sample_count=int(data["sample_count"]),
            extractor=data.get("extractor", "numpy-mfcc-prototype-v1"),
        )


@dataclass(frozen=True)
class VerificationResult:
    path: str
    score: float
    decision: Decision

    def to_json_dict(self) -> dict:
        return {
            "path": self.path,
            "score": round(float(self.score), 6),
            "decision": self.decision.value,
        }


def load_wav_mono(path: Path, target_sample_rate: int = TARGET_SAMPLE_RATE) -> tuple[np.ndarray, int]:
    with wave.open(str(path), "rb") as wav:
        channels = wav.getnchannels()
        sample_width = wav.getsampwidth()
        sample_rate = wav.getframerate()
        frames = wav.readframes(wav.getnframes())

    if sample_width != 2:
        raise ValueError(f"Only 16-bit PCM WAV is supported by the prototype: {path}")

    audio = np.frombuffer(frames, dtype=np.int16).astype(np.float32)
    if channels > 1:
        audio = audio.reshape(-1, channels).mean(axis=1)
    audio = audio / 32768.0

    if sample_rate != target_sample_rate:
        duration = audio.size / sample_rate
        old_t = np.linspace(0, duration, audio.size, endpoint=False)
        new_size = max(1, int(duration * target_sample_rate))
        new_t = np.linspace(0, duration, new_size, endpoint=False)
        audio = np.interp(new_t, old_t, audio).astype(np.float32)
        sample_rate = target_sample_rate

    return trim_silence(audio), sample_rate


def trim_silence(audio: np.ndarray, threshold: float = 0.01) -> np.ndarray:
    if audio.size == 0:
        return audio
    active = np.flatnonzero(np.abs(audio) >= threshold)
    if active.size == 0:
        return audio
    start = max(int(active[0]) - 400, 0)
    end = min(int(active[-1]) + 400, audio.size)
    return audio[start:end]


def extract_embedding(path: Path) -> np.ndarray:
    audio, sample_rate = load_wav_mono(path)
    if audio.size < sample_rate // 3:
        raise ValueError(f"Audio too short for speaker prototype: {path}")

    emphasized = np.append(audio[0], audio[1:] - 0.97 * audio[:-1])
    frames = frame_audio(emphasized, sample_rate)
    power = power_spectrum(frames, n_fft=512)
    mel = mel_filterbank(sample_rate, n_fft=512, n_filters=26)
    log_mel = np.log(np.maximum(np.dot(power, mel.T), 1e-10))
    coeffs = dct_type_ii(log_mel, keep=14)[:, 1:]

    delta = np.diff(coeffs, axis=0)
    if delta.size == 0:
        delta = np.zeros_like(coeffs)

    features = np.concatenate([
        coeffs.mean(axis=0),
        coeffs.std(axis=0),
        delta.mean(axis=0),
        spectral_shape_features(power, sample_rate),
    ])
    norm = np.linalg.norm(features)
    if norm <= 1e-9:
        return features
    return features / norm


def frame_audio(audio: np.ndarray, sample_rate: int) -> np.ndarray:
    frame_length = int(sample_rate * 0.025)
    hop = int(sample_rate * 0.010)
    if audio.size < frame_length:
        audio = np.pad(audio, (0, frame_length - audio.size))
    count = 1 + int((audio.size - frame_length) / hop)
    frames = np.stack([
        audio[i * hop:i * hop + frame_length]
        for i in range(max(count, 1))
    ])
    return frames * np.hamming(frame_length)


def power_spectrum(frames: np.ndarray, n_fft: int) -> np.ndarray:
    spectrum = np.fft.rfft(frames, n=n_fft)
    return (np.abs(spectrum) ** 2) / n_fft


def mel_filterbank(sample_rate: int, n_fft: int, n_filters: int) -> np.ndarray:
    low_mel = hz_to_mel(80)
    high_mel = hz_to_mel(sample_rate / 2)
    mel_points = np.linspace(low_mel, high_mel, n_filters + 2)
    hz_points = mel_to_hz(mel_points)
    bins = np.floor((n_fft + 1) * hz_points / sample_rate).astype(int)
    bank = np.zeros((n_filters, n_fft // 2 + 1))
    for i in range(1, n_filters + 1):
        left, center, right = bins[i - 1], bins[i], bins[i + 1]
        if center == left:
            center += 1
        if right == center:
            right += 1
        for j in range(left, min(center, bank.shape[1])):
            bank[i - 1, j] = (j - left) / max(center - left, 1)
        for j in range(center, min(right, bank.shape[1])):
            bank[i - 1, j] = (right - j) / max(right - center, 1)
    return bank


def hz_to_mel(hz: float | np.ndarray) -> float | np.ndarray:
    return 2595 * np.log10(1 + np.asarray(hz) / 700)


def mel_to_hz(mel: np.ndarray) -> np.ndarray:
    return 700 * (10 ** (mel / 2595) - 1)


def dct_type_ii(values: np.ndarray, keep: int) -> np.ndarray:
    n = values.shape[1]
    basis = np.cos(np.pi / n * (np.arange(n) + 0.5)[:, None] * np.arange(keep)[None, :])
    return np.dot(values, basis)


def spectral_shape_features(power: np.ndarray, sample_rate: int) -> np.ndarray:
    freqs = np.linspace(0, sample_rate / 2, power.shape[1])
    energy = np.maximum(power.sum(axis=1), 1e-12)
    centroid = (power * freqs[None, :]).sum(axis=1) / energy
    cumulative = np.cumsum(power, axis=1)
    rolloff_bins = (cumulative >= (0.85 * energy[:, None])).argmax(axis=1)
    rolloff = freqs[rolloff_bins]
    return np.array([
        centroid.mean() / (sample_rate / 2),
        centroid.std() / (sample_rate / 2),
        rolloff.mean() / (sample_rate / 2),
        rolloff.std() / (sample_rate / 2),
    ])


def enroll_profile(paths: Iterable[Path], user_id: str = "current-user") -> VoiceProfile:
    embeddings = [extract_embedding(Path(path)) for path in paths]
    if not embeddings:
        raise ValueError("At least one enrollment sample is required.")
    centroid = np.mean(np.stack(embeddings), axis=0)
    norm = np.linalg.norm(centroid)
    if norm > 1e-9:
        centroid = centroid / norm
    return VoiceProfile(user_id=user_id, embedding=centroid, sample_count=len(embeddings))


def verify_candidate(
    profile: VoiceProfile,
    path: Path,
    accept_threshold: float = 0.84,
    uncertain_margin: float = 0.04,
) -> VerificationResult:
    embedding = extract_embedding(Path(path))
    score = cosine_similarity(profile.embedding, embedding)
    if score >= accept_threshold:
        decision = Decision.ACCEPTED_CURRENT_USER
    elif score >= accept_threshold - uncertain_margin:
        decision = Decision.UNCERTAIN
    else:
        decision = Decision.REJECTED_NON_USER
    return VerificationResult(path=str(path), score=score, decision=decision)


def save_profile(profile: VoiceProfile, path: Path) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(profile.to_json_dict(), indent=2, ensure_ascii=False))
    return path


def load_profile(path: Path) -> VoiceProfile:
    return VoiceProfile.from_json_dict(json.loads(Path(path).read_text()))


def gate_candidate(
    profile: VoiceProfile,
    candidate_path: Path,
    mode: str = "normal",
    normal_accept_threshold: float = 0.84,
    playback_accept_threshold: float = 0.86,
    uncertain_margin: float = 0.04,
) -> dict:
    threshold = playback_accept_threshold if mode == "playback" else normal_accept_threshold
    result = verify_candidate(
        profile,
        candidate_path,
        accept_threshold=threshold,
        uncertain_margin=uncertain_margin,
    )
    should_submit = result.decision == Decision.ACCEPTED_CURRENT_USER
    return {
        **result.to_json_dict(),
        "mode": mode,
        "should_submit": should_submit,
        "threshold": threshold,
    }


def cosine_similarity(left: np.ndarray, right: np.ndarray) -> float:
    denominator = np.linalg.norm(left) * np.linalg.norm(right)
    if denominator <= 1e-9:
        return 0.0
    return float(np.dot(left, right) / denominator)


def mix_wavs(
    first_path: Path,
    second_path: Path,
    output_path: Path,
    first_gain: float = 0.7,
    second_gain: float = 0.7,
) -> Path:
    first, sample_rate = load_wav_mono(Path(first_path))
    second, second_rate = load_wav_mono(Path(second_path))
    if second_rate != sample_rate:
        raise ValueError("Resampling should have normalized sample rates.")
    size = max(first.size, second.size)
    first = np.pad(first, (0, size - first.size))
    second = np.pad(second, (0, size - second.size))
    mixed = first_gain * first + second_gain * second
    peak = np.max(np.abs(mixed))
    if peak > 0.98:
        mixed = mixed / peak * 0.98
    write_wav(output_path, mixed, sample_rate)
    return output_path


def write_wav(path: Path, audio: np.ndarray, sample_rate: int = TARGET_SAMPLE_RATE) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    pcm = np.clip(audio, -1, 1)
    pcm = (pcm * 32767).astype(np.int16)
    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(sample_rate)
        wav.writeframes(pcm.tobytes())


def generate_ai_speech(text: str, output_path: Path, voice: str | None = None) -> Path:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    aiff_path = output_path.with_suffix(".aiff")
    command = ["say", "-o", str(aiff_path)]
    if voice:
        command.extend(["-v", voice])
    command.append(text)
    subprocess.run(command, check=True)
    subprocess.run([
        "ffmpeg",
        "-y",
        "-i",
        str(aiff_path),
        "-ac",
        "1",
        "-ar",
        str(TARGET_SAMPLE_RATE),
        str(output_path),
    ], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return output_path


def run_report(
    enrollment_paths: list[Path],
    candidate_paths: list[Path],
    output_path: Path,
    accept_threshold: float = 0.84,
    uncertain_margin: float = 0.04,
    mode: str = "normal",
    profile_path: Path | None = None,
    save_profile_path: Path | None = None,
) -> dict:
    profile = load_profile(profile_path) if profile_path else enroll_profile(enrollment_paths, user_id="current-user")
    if save_profile_path:
        save_profile(profile, save_profile_path)
    candidates = [
        gate_candidate(
            profile,
            candidate,
            mode=mode,
            normal_accept_threshold=accept_threshold,
            playback_accept_threshold=accept_threshold,
            uncertain_margin=uncertain_margin,
        )
        for candidate in candidate_paths
    ]
    report = {
        "profile": {
            "user_id": profile.user_id,
            "sample_count": profile.sample_count,
            "extractor": profile.extractor,
        },
        "thresholds": {
            "accept_threshold": accept_threshold,
            "uncertain_margin": uncertain_margin,
            "mode": mode,
        },
        "candidates": candidates,
    }
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(report, indent=2, ensure_ascii=False))
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description="Prototype current-user speaker verification chain.")
    parser.add_argument("--enroll", nargs="+", type=Path)
    parser.add_argument("--profile", type=Path)
    parser.add_argument("--save-profile", type=Path)
    parser.add_argument("--candidate", nargs="+", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--mode", choices=["normal", "playback"], default="normal")
    parser.add_argument("--accept-threshold", type=float, default=0.84)
    parser.add_argument("--uncertain-margin", type=float, default=0.04)
    args = parser.parse_args()
    if not args.profile and not args.enroll:
        parser.error("Either --profile or --enroll is required.")
    run_report(
        enrollment_paths=args.enroll or [],
        candidate_paths=args.candidate,
        output_path=args.output,
        accept_threshold=args.accept_threshold,
        uncertain_margin=args.uncertain_margin,
        mode=args.mode,
        profile_path=args.profile,
        save_profile_path=args.save_profile,
    )
    print(args.output)


if __name__ == "__main__":
    main()
