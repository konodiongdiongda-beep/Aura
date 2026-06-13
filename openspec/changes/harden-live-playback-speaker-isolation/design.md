## Context

The app now attaches speaker evidence to Azure final recognition events, but two live policy gaps remain:

- The adaptive provider enrolls before a trusted current-user profile exists, even if the audio was captured while the assistant was speaking.
- The coordinator can treat unknown voice activity during assistant playback as an interruption before speaker evidence is available, which turns assistant playback echo into an "interrupted" final path.

Rejected speaker verification should be a filter result, not a call-ending error.

## Goals / Non-Goals

**Goals:**
- Ensure assistant playback cannot become current-user enrollment.
- Ensure assistant playback echo cannot be promoted to user input by an early unknown VAD interruption.
- Ensure `.otherSpeaker`, `.uncertain`, `.unavailable`, or playback-echo rejections keep the voice session alive.
- Preserve current-user speech submission when the user is in a normal listening turn.

**Non-Goals:**
- Do not add a production ECAPA/CoreML/ONNX model in this change.
- Do not add a new enrollment UI in this change.
- Do not remove the existing adaptive provider replacement seam.

## Decisions

- Treat unknown energy during playback as insufficient for immediate barge-in.
  - Rationale: the app-owned microphone stream cannot distinguish assistant speaker output from a nearby user based on energy alone.

- Only allow adaptive enrollment from safe listening-context finals.
  - Rationale: enrollment is a privilege; playback-window samples and interrupted finals are contaminated by assistant audio.

- Keep rejection handling inside coordinator state transitions.
  - Rationale: speaker verification failure is expected filtering behavior, not a recognizer failure.

## Risks / Trade-offs

- Real user barge-in may wait until final speaker evidence instead of cancelling on the earliest unknown energy event.
- Without a production speaker model, hard acoustic cases can still be uncertain. The correct behavior is to reject uncertain playback input and keep the call alive.
