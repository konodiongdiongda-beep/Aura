import json
import tempfile
import unittest
import wave
from pathlib import Path

import numpy as np

from tools.speaker_verification.speaker_verification import (
    Decision,
    enroll_profile,
    gate_candidate,
    load_profile,
    mix_wavs,
    run_report,
    save_profile,
    verify_candidate,
)


class SpeakerVerificationTests(unittest.TestCase):
    def test_accepts_matching_candidate_and_rejects_distinct_voice(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            sample_a1 = root / "speaker-a-1.wav"
            sample_a2 = root / "speaker-a-2.wav"
            sample_b = root / "speaker-b.wav"
            write_tone_voice(sample_a1, fundamentals=[180, 260])
            write_tone_voice(sample_a2, fundamentals=[182, 262])
            write_tone_voice(sample_b, fundamentals=[420, 690])

            profile = enroll_profile([sample_a1, sample_a2], user_id="current-user")
            match = verify_candidate(profile, sample_a1, accept_threshold=0.88, uncertain_margin=0.04)
            mismatch = verify_candidate(profile, sample_b, accept_threshold=0.88, uncertain_margin=0.04)

            self.assertEqual(match.decision, Decision.ACCEPTED_CURRENT_USER)
            self.assertEqual(mismatch.decision, Decision.REJECTED_NON_USER)
            self.assertGreater(match.score, mismatch.score)

    def test_report_includes_ai_and_mixed_candidates(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            user_a = root / "user-a.wav"
            user_b = root / "user-b.wav"
            ai = root / "ai.wav"
            other = root / "other-speaker.wav"
            mixed = root / "mixed.wav"
            report_path = root / "report.json"

            write_tone_voice(user_a, fundamentals=[180, 260])
            write_tone_voice(user_b, fundamentals=[184, 264])
            write_tone_voice(ai, fundamentals=[520, 780])
            write_tone_voice(other, fundamentals=[430, 710])
            mix_wavs(user_a, ai, mixed, first_gain=0.7, second_gain=0.7)

            run_report(
                enrollment_paths=[user_a, user_b],
                candidate_paths=[user_a, ai, other, mixed],
                output_path=report_path,
                accept_threshold=0.88,
                uncertain_margin=0.04,
            )

            report = json.loads(report_path.read_text())
            labels = {Path(item["path"]).name: item for item in report["candidates"]}
            self.assertEqual(labels["user-a.wav"]["decision"], Decision.ACCEPTED_CURRENT_USER.value)
            self.assertIn(labels["ai.wav"]["decision"], {
                Decision.REJECTED_NON_USER.value,
                Decision.UNCERTAIN.value,
            })
            self.assertFalse(labels["other-speaker.wav"]["should_submit"])
            self.assertIn(labels["other-speaker.wav"]["decision"], {
                Decision.REJECTED_NON_USER.value,
                Decision.UNCERTAIN.value,
            })
            self.assertIn("score", labels["mixed.wav"])
            self.assertEqual(report["profile"]["user_id"], "current-user")

    def test_saved_profile_can_drive_strict_playback_gate(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            user_a = root / "user-a.wav"
            user_b = root / "user-b.wav"
            ai = root / "ai.wav"
            profile_path = root / "profile.json"

            write_tone_voice(user_a, fundamentals=[180, 260])
            write_tone_voice(user_b, fundamentals=[184, 264])
            write_tone_voice(ai, fundamentals=[520, 780])

            profile = enroll_profile([user_a, user_b], user_id="current-user")
            save_profile(profile, profile_path)
            loaded = load_profile(profile_path)

            accepted = gate_candidate(
                loaded,
                user_a,
                mode="playback",
                playback_accept_threshold=0.86,
                uncertain_margin=0.04,
            )
            rejected = gate_candidate(
                loaded,
                ai,
                mode="playback",
                playback_accept_threshold=0.86,
                uncertain_margin=0.04,
            )

            self.assertTrue(accepted["should_submit"])
            self.assertEqual(accepted["decision"], Decision.ACCEPTED_CURRENT_USER.value)
            self.assertFalse(rejected["should_submit"])
            self.assertIn(rejected["decision"], {
                Decision.REJECTED_NON_USER.value,
                Decision.UNCERTAIN.value,
            })


def write_tone_voice(path: Path, fundamentals: list[float], sample_rate: int = 16_000, seconds: float = 2.0):
    t = np.linspace(0, seconds, int(sample_rate * seconds), endpoint=False)
    signal = np.zeros_like(t)
    for fundamental in fundamentals:
        signal += 0.55 * np.sin(2 * np.pi * fundamental * t)
        signal += 0.25 * np.sin(2 * np.pi * fundamental * 2.02 * t)
        signal += 0.15 * np.sin(2 * np.pi * fundamental * 3.01 * t)
    envelope = np.clip(np.sin(np.pi * np.linspace(0, 1, signal.size)) * 1.25, 0, 1)
    signal *= envelope
    signal = signal / max(np.max(np.abs(signal)), 1e-6)
    pcm = (signal * 24_000).astype(np.int16)
    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(sample_rate)
        wav.writeframes(pcm.tobytes())


if __name__ == "__main__":
    unittest.main()
