## 1. Packaging

- [x] 1.1 Define included and excluded source package contents.
- [x] 1.2 Stage a clean source tree without generated outputs or local secrets.
- [x] 1.3 Add a README with Simulator build instructions.
- [x] 1.4 Create a compressed archive on the Desktop.

## 2. Verification

- [x] 2.1 Validate the OpenSpec change.
- [x] 2.2 Inspect archive contents for required files and excluded folders.
- [x] 2.3 Report the final Desktop archive path.

## 3. Verification Notes

- Desktop archive created at `/Users/dongbu/Desktop/AuraVoiceAssistant-source-simulator-20260605-163749.zip`.
- Archive includes `README_SIMULATOR_BUILD.md`, app source, `VoiceCore`, tests, workspace/project metadata, `Podfile`, `Podfile.lock`, `project.yml`, and `Docs`.
- Archive excludes `Pods`, `tmp`, `build`, `VoiceCore/.build`, `.codex`, screenshots, old zip files, and `AuraVoiceAssistant/App/LocalConfig.xcconfig`.
- Verified from the archive by extracting to `/tmp`, copying `LocalConfig.sample.xcconfig` to `LocalConfig.xcconfig`, running `pod install`, and building `AuraVoiceAssistant` for the iPhone 17 Pro Simulator.
