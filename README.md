# Archimedes Keyboard & Mouse Emulator

An old Archimedes was gathering dust in a school cupboard. This project got it working again.

A hardware adapter that translates PS/2 keyboard and mouse input into the Acorn Archimedes' proprietary serial protocol, running on an Arduino Uno R3 (or any sufficiently small Arduino-compatible board).

## Features

- Full PS/2 keyboard support with complete keymap translation to Archimedes scan codes
- Full PS/2 mouse support including X/Y movement and all three mouse buttons
- Compatible with USB keyboards and mice that present as PS/2 (tested and confirmed working)
- Handles the Archimedes handshake sequence including `HRST`, `RAK1/RAK2`, `RQID`, and dynamic ACK state management (`NACK`, `SACK`, `MACK`, `SMAK`)
- Correct encoding of signed 7-bit mouse movement data per the Archimedes serial spec
- Extended key handling for special keys (arrow keys, Print Screen, Home, End, Insert, Delete, numpad)
- Hold-key deduplication via a linked list to prevent phantom repeat events
- Hardware jumper header for selecting boot-time key sequences without a physical keyboard

## Hardware Requirements

- Arduino Uno R3 (or similar small Arduino-compatible board)
- PS/2 keyboard (or USB keyboard with PS/2 compatibility mode)
- PS/2 mouse (or USB mouse with PS/2 compatibility mode)
- **Use low-power peripherals where possible** — the Archimedes keyboard port has limited current capacity and may struggle to power hungry devices

## Bootloader

This section is only relevant if you are using the boot mode jumper header. If your Archimedes has a working CMOS battery and you do not need the jumpers, the default Arduino bootloader is fine.

The default Arduino Uno bootloader waits ~500ms before handing off to user code. The Archimedes expects the keyboard reset handshake to begin within 100ms of power-on, so this is too slow for the jumper pins to be read in time.

If you need the jumpers, flash Optiboot compiled with a timeout of **32–64ms**. This ensures your code starts running well within the handshake window before the Archimedes begins its handshake sequence.

## Pin Wiring

### Arduino → PS/2 Devices

| Signal | Arduino Pin |
|---|---|
| Keyboard Data (PS/2 D-) | 6 |
| Keyboard Clock (PS/2 D+) | 3 |
| Mouse Data (PS/2 D-) | 4 |
| Mouse Clock (PS/2 D+) | 5 |

> **Note:** The keyboard clock line must be connected to a hardware interrupt pin. On the Uno, pin 3 is used for this reason. If porting to a different board, ensure the keyboard clock is assigned to a pin that supports hardware interrupts, or the keyboard will not function correctly.

### Arduino → Archimedes Keyboard Connector

The Archimedes keyboard port is a 6-pin connector. Only pins 3–6 are used:

```
            Connector                  Arduino
            ------------------------------------
  ,--_--.   1: NC
 / o6 5o \  2: NC
| o4   3o | 3: GND                     GND
 - 2o o1 - 4: 5V                       Vin
  `-___-'   5: In (From Arduino)       Pin 8 (STX)
            6: Out (To Arduino)        Pin 9 (SRX)
```

The Archimedes serial line runs at **31250 baud**, inverted logic — handled automatically by `SoftwareSerial` in inverted mode.

### Boot Mode Jumper Header

This header is entirely optional. If your Archimedes has a working CMOS battery and a known-good configuration, you can ignore this section entirely — the adapter will work without it.

If you do need it, a 7-pin header provides hardware selection of boot-time key sequences. Bridge the GND pin to one of the signal pins before powering on. The Arduino reads the bridged pin at startup and automatically sends the corresponding key sequence to the Archimedes during the boot handshake — no physical keyboard required. All signal pins use internal pullups, so no external resistors are needed.

```
[ GND | A0 | A1 | A2 | A3 | A4 | A5 ]
```

| Pin | Key Sent | Effect |
|---|---|---|
| A0 | Delete | Resets CMOS RAM to factory defaults. Essential if the internal NiCd/Varta battery has died, leaked, or failed — a dead battery causes a blank screen or un-syncable signal on power-on. Wait until you see a black screen with a red border. |
| A1 | R | Resets CMOS but preserves the configured Monitor Type. Useful if your machine is connected to a finicky multi-sync CRT that requires specific timing values. |
| A2 | 0 (number row) | Forces display output to video channel 0 — use this if a video expansion podule is installed but you want to force output through the stock motherboard video jack. |
| A3 | Shift | Bypasses the hard drive `!Boot` sequence and drops into a raw unconfigured desktop. Use this if a broken boot script or user configuration is crashing the GUI on startup. |
| A4 | Keypad * | Bypasses the Desktop GUI entirely and drops directly into the CLI supervisor prompt (`*`). |
| A5 | Shift + Break | Forces a floppy disk boot from drive `:0`. Not yet tested on real hardware. |

## Key Mapping Notes

The PS/2 scan code set is translated to Archimedes row/column matrix coordinates. A few non-obvious mappings apply:

- **End** → triggers the Archimedes **Copy** key. To send a true End, use **Shift + End**
- **\`** (backtick, under Escape) + **Shift** → produces `~`
- The `#` key produces `#` as expected

## Known Limitations & Stability

The adapter is fully functional for general use — typing, cursor movement, and all mouse buttons work correctly on real hardware. However, under heavy simultaneous keyboard and mouse input, the Arduino can occasionally lose sync. This is a known hardware-level limitation: the PS/2 keyboard library uses pin-change interrupts which can conflict with `SoftwareSerial`'s timing when a keypress arrives mid-transmission.

If the adapter stops responding, unplug and replug the Arduino to trigger a clean reset and re-handshake with the Archimedes.

A more robust long-term fix would be to introduce a buffer between the keyboard and the Arduino that holds scan codes and only forwards them once the serial lines are idle — though the practicality of this on limited hardware is yet to be determined.

## Dependencies

- [`PS2Keyboard`](https://github.com/PaulStoffregen/PS2Keyboard)
- [`PS2MouseHandler`](https://github.com/ByteArray/PS2MouseHandler)
- [`LinkedList`](https://github.com/ivanseidel/LinkedList)
- `SoftwareSerial` (Arduino built-in)

## Tested On

- Acorn Archimedes A310
- Should work on any Acorn machine using the same keyboard serial protocol
