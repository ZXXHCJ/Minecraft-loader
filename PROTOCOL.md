# Installer protocol and interface

The public Lua installer uses a small device character interface. The private native implementation and firmware bindings are intentionally outside this repository.

## Device interface

The installer opens the device endpoint supplied by the host watchface and exchanges framed requests. A frame contains:

- magic: `CPC2` (`0x43504332`)
- protocol header size
- protocol major version
- total frame size
- command number
- monotonically increasing request sequence
- signed result code
- phase/status value
- payload length

The public loader uses the following commands:

- `13`: request installation/registration of the resident application
- `14`: query application visibility state
- `15`: request a visibility change

The Lua code validates the magic, header fields, command, sequence, response length, result, and phase before displaying success. A device-side implementation must provide the endpoint and the corresponding native service; this repository does not contain that service.

## Host contract

The watchface host supplies the selected device profile, the endpoint path, and the resources directory. The Lua installer is responsible for UI state, progress reporting, request framing, and response validation. Native payload loading and firmware-specific recovery remain project-private and are not part of this public source release.
