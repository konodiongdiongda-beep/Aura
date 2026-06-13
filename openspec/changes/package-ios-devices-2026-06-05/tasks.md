## 1. Packaging

- [x] 1.1 Inspect available signing identities and provisioning profiles for requested UDIDs.
- [ ] 1.2 Archive `AuraVoiceAssistant` for physical iOS devices.
- [ ] 1.3 Export an installable package for the requested devices.
- [x] 1.4 Report output path or exact signing blocker.

## 2. Verification

- [x] 2.1 Validate the OpenSpec change.
- [x] 2.2 Confirm generated package artifacts or failed signing evidence.

## 3. Blocker Notes

- Existing local provisioning profile is for `LH2TK8VVVG.app.parsnip5809.bear3414`, not `com.aura.voiceassistant`.
- Existing local provisioning profile contains device `00008140-00164C280C68801C`, not requested devices `00008150-00097D0A26F2401C` or `00008110-000C682C3CBA801E`.
- Automatic signing with team `LH2TK8VVVG` failed because Xcode has no logged-in account for that team and no matching profile for `com.aura.voiceassistant`.
- Automatic signing with team `TB64ADAV2T` also failed because Xcode has no logged-in account for that team and no matching profile/certificate chain for `com.aura.voiceassistant`.
