## Why

A device-installable build is needed for the requested iPhone 17 Pro and iPhone 13 device UDIDs.

## What Changes

- Produce an iOS device archive/export for `AuraVoiceAssistant` using the current runtime configuration.
- Use signing/provisioning that includes the requested device UDIDs when available.
- Report any signing/profile blocker with the specific missing profile/device condition.

## Impact

- Affects packaging output only.
- Does not change app runtime behavior or source code.
