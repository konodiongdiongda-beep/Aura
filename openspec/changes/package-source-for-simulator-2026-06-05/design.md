## Design

Stage a clean source tree with app sources, `VoiceCore`, tests, Xcode project/workspace metadata, dependency manifests, OpenSpec context, and documentation. Exclude `Pods`, SwiftPM build outputs, DerivedData, temporary folders, screenshots, local Codex state, and `LocalConfig.xcconfig`.

Use `LocalConfig.sample.xcconfig` as the template for local values. The README should tell the receiver to copy it to `LocalConfig.xcconfig` and run `pod install` before building the workspace.

## Verification

Validate the OpenSpec change, inspect the staged archive contents, and confirm the archive exists on the Desktop.
