# Simple VGA CRTC in Verilog
In this repo you will find some Verilog code implementing a simple VGA CRTC.

The CRTC was designed to fit into a 128 macrocell CPLD, specifically the Altera EPM7128 and Atmel ATF1508.

A summary of features supported by this CRTC include:

* 28.322MHz pixel clock providing a resolution of 720x400 @ 70hz
* 80x25 characters, with each character being 8x16 in the font ROM and formatted as 9x16 on the screen
* A hardware cursor
	* Movable to any position on the screen independent of VRAM accesses
	* Configurable start and end scanlines to allow size and position within a character box to be adjusted as required
	* Can be disabled in-place via a configuration register
* 16 colour palette to be provided by an external RAMDAC or other circuitry
* Configurable colour mode:
	* 16 foreground and 8 background colours with blinking text
	* 16 foreground and background colours without blinking text
* Software configurable screen blank via a configuration register

The current implementation consumes 121 macrocells.

## Configuration Registers
Configuration registers are distributed across 4 memory addresses. Registers are write-only. A larger CPLD or different pin arrangement may permit registers to also be readable.

| Address | Register |
|--|--|
| 0x0 | Cursor control register #1 |
| 0x1 | Cursor control register #2 |
| 0x2 | Cursor control register #3 |
| 0x3 | CRTC control register |

### Conventions
 * A forward slash (/) after a signal name indicates that the signal is active low, or negative logic
 * In register bit tables:
	 * R indicates that a bit is readable
	 * W indicates that a bit is writable
	 * U indicates that a bit is unimplemented, the value is undefined on read
	 * -0 indicates the bit reads as 0 on reset, and -1 reads as a 1. -? means the bit value is indeterminate on reset

### Cursor control register #1
| 7 |  |  |  |  |  |  | 0 |
|--|--|--|--|--|--|--|--|
| W-0 | U | U | U | U | W-0 | W-0 | W-0 |
| CDIS |  |  |  |  | POS10 | POS9 | POS8 |

Bit 7: CDIS: Cursor Disable<br>
&nbsp;&nbsp;&nbsp;&nbsp;0: Cursor is enabled<br>
&nbsp;&nbsp;&nbsp;&nbsp;1: Cursor is disabled<br>
Bits 2-0: POS: Upper bits of cursor position<br>

### Cursor control register #2
| 7 |  |  |  |  |  |  | 0 |
|--|--|--|--|--|--|--|--|
| W-0 | W-0 | W-0 | W-0 | W-0 | W-0 | W-0 | W-0 |
| POS7 | POS6 | POS5 | POS4 | POS3 | POS2 | POS1 | POS0 |

Bits 7-0: POS: Lower bits of cursor position

### Cursor control register #3
| 7 |  |  |  |  |  |  | 0 |
|--|--|--|--|--|--|--|--|
| W-1 | W-1 | W-1 | W-0 | W-1 | W-1 | W-0 | W-1 |
| END3 | END2 | END1 | END0 | START3 | START2 | START1 | START0 |

Bit 7-4: Cursor end scanline<br>
&nbsp;&nbsp;&nbsp;&nbsp;0000: Cursor ends on scanline 0<br>
&nbsp;&nbsp;&nbsp;&nbsp;0001: Cursor ends on scanline 1<br>
&nbsp;&nbsp;&nbsp;&nbsp;...<br>
&nbsp;&nbsp;&nbsp;&nbsp;1111: Cursor ends on scanline 15<br>
Bit 3-0: Cursor start scanline<br>
&nbsp;&nbsp;&nbsp;&nbsp;0000: Cursor starts on scanline 0<br>
&nbsp;&nbsp;&nbsp;&nbsp;0001: Cursor starts on scanline 1<br>
&nbsp;&nbsp;&nbsp;&nbsp;...<br>
&nbsp;&nbsp;&nbsp;&nbsp;1111: Cursor starts on scanline 15<br>

### CRTC control register
| 7 |  |  |  |  |  |  | 0 |
|--|--|--|--|--|--|--|--|
| U | U | U | W-0 | U | U | U | W-0 |
|  |  |  | BLANK |  |  |  | EXTBG |

Bit 4: BLANK: Screen blanking control<br>
&nbsp;&nbsp;&nbsp;&nbsp;0: Screen is enabled<br>
&nbsp;&nbsp;&nbsp;&nbsp;1: Screen is blanked<br>
Bits 0: EXTBG: Extended background colour option<br>
&nbsp;&nbsp;&nbsp;&nbsp;0: 16 FG, 8 BG, blinking text<br>
&nbsp;&nbsp;&nbsp;&nbsp;1: 16 FG and BG, no blinking text<br>

## Description of operation
The CRTC is a free-running controller which does not need any special initialisation from an external CPU to function. It is clocked separately to the main CPU by an external 28.322MHz oscillator, which is the pixel clock, and from which all horizontal and vertical timing is derived to drive  a connected display.

The controller resets with defaults that permit it to function as long as external memories are connected and filled with appropriate contents to display.

Colour generation for pixels is to be provided by an external RAMDAC or other circuitry. The CRTC provides a 4 bit colour index which is determined by the colour attributes stored in VRAM for the current character being written to the screen. Examples of RAMDACs are Samsung KDA0476 or INMOS G171 or equivalent, and should be suitably rated for the 28.322MHz pixel clock used by the CRTC.

The CRTC outputs an 11 bit address which is fed to external VRAM memory devices. VRAM is to be of 16 bit width, with one byte forming the attribute byte, and a second byte being the character code. The attribute byte is to be provided directly from the VRAM to the CRTC, while the character code is to be provided to the font ROM along with the scanline counter, which then provides the font pixels for a character to the CRTC. The upper 3 bits of the character code are to be provided to the CRTC, and these bits allow the CRTC to effectively "stretch" characters in the 0xC0-DF range to 9 bits wide. All other characters are 8 bits wide. All characters are formatted as 9 pixels wide on the screen.

A simple processor interface is provided to allow configuration of various options consisting of an 8 bit data bus, 2 bit address bus, and an active low write strobe which may be easily generated by external decoding logic. If this interface is unused, the write strobe should be tied high, and all data and address pins tied either high or low.

An external blanking input is provided to allow external circuitry to blank the screen. If unused, this input should be tied high.

**Simplified block diagram of CRTC and associated components**

<img src="CRTC block.png">

### Configuration register descriptions
In register at address 0x0, bit 4 represents the cursor disable bit. Setting this bit allows the cursor to be disabled in-place, i.e. it does not need to be moved off the active screen area. Clearing the bit will enable the cursor.

In register at address 0x2, the start and end scanlines of the cursor can be configured. The cursor is configurable to be visible from 1 to 16 scanlines, permitting various sizes and positioning to be achieved. At reset, the cursor will be visible on scanlines 13 and 14. Setting the start scanline to be later than the end scanline may result in undefined behaviour of the cursor.

The lower 3 bits of register address 0x0 and all 8 bits of register address 0x1 form the cursor position, expressed as an 11 bit address within the 2000 byte visible area of the screen. The address where the cursor is to be positioned may be determined using the following formula:

    address = (row * 80) + col

Consequently, the cursor can also be effectively disabled by moving it to an address which would position it outside of the visible screen area.

The cursor is independently controlled by software, and its position is not affected by, and has no effect on, the contents written to VRAM.

At reset, the cursor is positioned at the top left corner of the screen.

The register at address 0x3 contains two bits that select the colour mode, and enable or disable screen blanking.

At reset, the colour mode provides 16 foreground colours, 8 background colours, and permits blinking text by setting bit 7 of the attribute byte. Setting bit 0 of this register causes bit 7 of the attribute byte to act as an intensity bit for the background colour, allowing 16 background colours to be used at the loss of blinking text.

**Format of attribute byte when EXTBG = 0**

    |  7                                           0  |
    +-------+-----+-----+-----+-----+-----+-----+-----+
    | BLINK | BG2 | BG1 | BG0 | FG3 | FG2 | FG1 | FG0 |
    +-------+-----+-----+-----+-----+-----+-----+-----+

**Format of attribute byte when EXTBG = 1**

    |  7                                         0  |
    +-----+-----+-----+-----+-----+-----+-----+-----+
    | BG3 | BG2 | BG1 | BG0 | FG3 | FG2 | FG1 | FG0 |
    +-----+-----+-----+-----+-----+-----+-----+-----+


Bit 4 allows software to blank the screen. Setting this bit is intended to immediately cause the screen to be blanked from the current pixel position by inhibiting colour generation by the RAMDAC or external colour circuitry. Clearing the bit should immediately re-enable colour generation by the RAMDAC or external circuitry. An external blanking input is provided, which can enable blanking synced to horizontal or vertical sync periods.

### VRAM format and access details
VRAM stores the character and attribute data to be displayed. The character code is an 8 bit value, while attribute data provides colour and extended information to the CRTC.

VRAM is considered to be 16 bits wide, and each character position on the screen consumes two bytes of VRAM to provide the character and attribute data.

The endianess of the VRAM bytes is inconsequential to the CRTC as long as the correct data is provided to the appropriate CRTC busses in the expected order, and therefore it is independent of the endianess of the host computer system.

The CRTC provides no arbitration between itself and the host computer system for access to VRAM, and occupies the VRAM interface 100% of the time. External circuitry may be used to alternate access between the CRTC and the CPU during blanking intervals.

Memories may be dual-port RAMs, and due to the fact the CRTC only ever reads VRAM, this provides a clean solution to allow both the CRTC and host computer uncontended access to VRAM. Alternatively, multiple banks of memory may be provided, with external circuitry to switch banks during e.g. the verical sync period.