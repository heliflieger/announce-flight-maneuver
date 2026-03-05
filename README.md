# Flight Announcer

Flight Announcer is a modular Lua system tool for FrSky ETHOS that announces flight phases/manoeuvres with configurable WAV sequences.

It includes:
- a transmitter/runtime script (`scripts/FlightAnnouncer`),
- user config/audio storage (`scripts/FlightAnnouncer.user`),
- and a simulator mirror for fast iteration (`simulator/X20S_FCC/scripts/...`).

## User Documentation

- German: [Benutzerdokumentation](doc/Benutzerdokumentation.de.md)
- English: [User Documentation](doc/User-Documentation.en.md)

## Features

- Multiple announcer profiles (`*.user`) with quick switching
- Automatic UI language based on system locale (`de`/`en`, fallback `en`)
- Global trigger source (switch/button/slider) shared across profiles
- Ordered WAV playlist per profile
- WAV row actions: move up/down, duplicate, delete
- Persistent active profile and trigger state
- Background task support for continuous trigger handling

## Repository Layout

- `scripts/FlightAnnouncer/main.lua` — tool entry point and task registration
- `scripts/FlightAnnouncer/modules/app_logic.lua` — runtime logic and trigger/audio behavior
- `scripts/FlightAnnouncer/modules/ui_form.lua` — ETHOS form UI
- `scripts/FlightAnnouncer/modules/config_store.lua` — profile persistence (`*.user` files)
- `scripts/FlightAnnouncer/modules/common.lua` — shared utilities/constants/source conversion
- `scripts/FlightAnnouncer/i18n/` — translation packs (`de.lua`, `en.lua`)
- `scripts/FlightAnnouncer.user/` — default profile 
- `scripts/FlightAnnouncer.user/audio` — user audio folder
- `simulator/X20S_FCC/scripts/` — simulator deployment target

## Requirements

- FrSky ETHOS environment (radio or simulator)
- WAV files stored in `SCRIPTS:/FlightAnnouncer.user/audio`

## Installation (Radio)

1. Copy `scripts/FlightAnnouncer` to `SCRIPTS:/FlightAnnouncer`.
2. Copy `scripts/FlightAnnouncer.user` to `SCRIPTS:/FlightAnnouncer.user`.
3. Open ETHOS System Tools and start **Flight Announcer**.

## Simulator Workflow

In this workspace, deploy and launch using the VS Code task:
- `Deploy & Launch [SIM]`

This task deploys scripts and restarts the ETHOS simulator chain.

## Configuration Files

Profiles are stored as Lua-return tables in:
- `SCRIPTS:/FlightAnnouncer.user/<name>.user`

Example:

```lua
return {
  name = "F3C Program",
  wav_files = {
    "SCRIPTS:/FlightAnnouncer.user/audio/start.wav",
    "SCRIPTS:/FlightAnnouncer.user/audio/figure1.wav"
  }
}
```

Notes:
- The trigger is persisted globally (not per profile file).
- `default.user` is created automatically if missing.

## Versioning

Current script header version in source is `0.5.0`.
(Manifest files in simulator folders may still show an earlier value.)

## Contributing

Issues and pull requests are welcome.
Please keep changes focused and simulator-validated where possible.

## License

Choose and add a license file before publishing (recommendation below).