## ADDED Requirements

### Requirement: Source archive is clean and simulator-buildable
The packaging workflow SHALL produce a Desktop archive that includes source, project metadata, dependency manifests, and a Simulator build README while excluding generated outputs and local secrets.

#### Scenario: Archive contents are staged
- **GIVEN** the project contains generated folders and local config
- **WHEN** the source package is created
- **THEN** the archive SHALL exclude generated folders such as `Pods`, `tmp`, `build`, `.build`, and local config files containing machine-specific secrets.

#### Scenario: README guides Simulator build
- **GIVEN** a developer unpacks the archive
- **WHEN** they follow the README
- **THEN** they SHALL know how to install dependencies, open the workspace, and build/run on an iOS Simulator.
