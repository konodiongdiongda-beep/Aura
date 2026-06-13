## Why

The project source should be delivered as a compact archive that another machine can build for Simulator without carrying generated artifacts or local secrets.

## What Changes

- Create a source-only package on the Desktop.
- Include a README with Simulator build steps.
- Exclude generated dependencies, build outputs, temporary files, local machine metadata, and secret-bearing local config.

## Impact

- Affects packaging artifacts only.
- Does not change app runtime behavior.
