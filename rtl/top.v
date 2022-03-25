/*
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Copyright 2022 Tom Storey <https://github.com/tomstorey/vga_crtc>
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 1. Redistributions of source code must retain the above copyright
 * notice, this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright
 * notice, this list of conditions and the following disclaimer in the
 * documentation and/or other materials provided with the distribution.
 *
 * 3. Neither the name of the copyright holder nor the names of its
 * contributors may be used to endorse or promote products derived from
 * this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

`timescale 1ns/1ns

module CRTC
(
    input wire n_reset,                 /* Active low async reset */
    input wire pixel_clk,               /* 28.322MHz pixel clock */
    
    /* CPU interface to provide reading/writing of internal registers */
    input wire [7:0] cpu_data,          /* CPU data bus */
    input wire [1:0] cpu_address,       /* CPU address bus */
    input wire n_write,                 /* Write signal from decode logic */
    
    /* Character generation interface */
    input wire [7:0] attribute_data,    /* Colour attributes from VRAM */
    input wire [7:0] font_data,         /* Pixel data from font ROM */
    input wire [2:0] char_msbs,         /* 3 MSbs of the character code (7-5) */
    output wire [10:0] vram_address,    /* VRAM address */
    output wire [3:0] scanline,         /* Scanline for the current text row */

    /* Display control interface */
    input wire n_blank_in,              /* Blanking input */
    output wire n_blank_out,            /* Blanking output, to RAMDAC */
    output wire n_hsync,                /* Horizontal sync */
    output wire vsync,                  /* Vertical sync */
    output wire [3:0] colour_index      /* Colour index output to RAMDAC */
);
    /* Horizontal state machine
     *
     * Generates horizontal timing, including the horizontal sync signal that
     * is sent to the display. */
    wire hsync_backporch;
    wire hsync_active;
    wire hsync_frontporch;
    wire hsync_sync;
    
    sync_gen #(
        .WIDTH(10),
        .ACTIVE_COUNT(50),
        .FRONT_COUNT(770),
        .SYNC_COUNT(785),
        .RESET_COUNT(894)
    )
    hsync_gen(
        .reset(~n_reset),
        .clk(pixel_clk),
        .backporch(hsync_backporch),
        .active(hsync_active),
        .frontporch(hsync_frontporch),
        .sync(hsync_sync)
    );
    
    /* Vertical state machine
     *
     * Generates vertical timing, including the vertical sync signal that is
     * sent to the display. */
    wire vsync_backporch;
    wire vsync_active;
    wire vsync_sync;
    
    sync_gen #(
        .WIDTH(9),
        .ACTIVE_COUNT(30),
        .FRONT_COUNT(430),
        .SYNC_COUNT(441),
        .RESET_COUNT(444)
    )
    vsync_gen(
        .reset(~n_reset),
        .clk(hsync_sync),
        .backporch(vsync_backporch),
        .active(vsync_active),
        .sync(vsync_sync)
    );
    
    /* Character pixel counter
     *
     * Counts the number of pixels for each character that is being written to
     * the screen. Certain counts influence how other parts of the CRTC operate,
     * for example:
     *
     *  - At count 0, font pixel data presented from the font ROM, and colour
     *    attributes from VRAM are latched into the pixel shift register inside
     *    the pixel generator module
     *  - At count 2, the VRAM address is advanced one column to setup the
     *    colour attributes and font pixel data for the next character */
    wire [3:0] char_pix_count;
    
    upcounter #(
        .WIDTH(4),
        .MAX_COUNT(8),
        .RESET_VALUE(8)
    )
    char_pix(
        .reset(~hsync_active),
        .enable(1'b1),
        .clk(pixel_clk),
        .count(char_pix_count)
    );
    
    /* Scanline counter
     *
     * Counts the scanlines that make up a text row. Each row is 16 pixels high,
     * and thus comprises 16 scanlines.
     *
     * The scanline value is fed to the font ROM, along with the character code
     * that is stored in VRAM, to select the appropriate "slice" of font data
     * for a character. */
    wire [3:0] scanline_val;
    
    upcounter #(
        .WIDTH(4)
    )
    scanline_ctr(
        .reset(~vsync_active),
        .enable(1'b1),
        .clk(hsync_frontporch),
        .count(scanline_val)
    );
    
    /* Text row counter
     *
     * The text row is tracked by the offset into VRAM. Each row is 80 bytes
     * wide, so the text row counter increments 80 at a time.
     *
     * The row counter is advanced after 16 scanlines have been completed. */
    wire [10:0] text_row_val;
    wire text_row_inc = (scanline_val == 0);
    
    upcounter #(
        .WIDTH(11),
        .INCREMENT(80)
    )
    text_row(
        .reset(~vsync_active),
        .enable(1'b1),
        .clk(text_row_inc),
        .count(text_row_val)
    );
    
    /* Text column counter
     *
     * The text column counter is loaded from the text row counter at the
     * beginning of each scanline, and is incremented by 1 for each character
     * on the row. This results in an address which is calculated as:
     *
     *   address = (row * 80) + col
     *
     * The value of the column counter is presented to the VRAM to select the
     * character code (which feeds to the font ROM) and colour attributes for
     * the next character to be displayed.
     *
     * Incrementing happens shortly after the font/attribute data is latched
     * to allow the VRAM and font ROM enough time to resolve the new address and
     * stabilise their output data in time for the next character.
     *
     * Each text row is iterated 16 times, once for each scanline. */
    wire [10:0] text_col_val;
    wire text_col_inc = (char_pix_count == 2);
    
    loadable_upcounter #(
        .WIDTH(11)
    )
    text_col(
        .reset(~vsync_active),
        .clk(text_col_inc | hsync_sync),
        .load(~hsync_active),
        .value(text_row_val),
        .count(text_col_val)
    );
    
    /* A counter used to clock blinking text and the cursor when active. Bit 4
     * provides the clock for blinking text, while bit 3 provides a faster clock
     * for the cursor. */
    wire [4:0] blink_val;
    
    upcounter #(
        .WIDTH(5)
    )
    blink(
        .reset(~n_reset),
        .enable(1'b1),
        .clk(vsync_sync),
        .count(blink_val)
    );
    
    /* CRTC configuration register file
     *
     * The register file provides configuration bits and fields for the cursor
     * and other functions:
     *
     *  - cursor position on the screen
     *  - cursor disabled
     *  - start and end scanlines of the cursor
     *  - extended background colour mode, which trades blinking text for 16
     *    background colours
     *  - display blank
     *
     * The register file is write-only and its values cannot be read back,
     * therefore the application/OS must keep track of the settings applied to
     * the CRTC registers. */
    wire [10:0] match_address;
    wire cursor_disable;
    wire [3:0] start_scanline;
    wire [3:0] end_scanline;
    wire screen_blank;
    wire extended_bg_colours;
    
    register_file registers(
        .reset(~n_reset),
        .cpu_data(cpu_data),
        .cpu_address(cpu_address),
        .n_write(n_write),
        
        .match_address(match_address),
        .cursor_disable(cursor_disable),
        .start_scanline(start_scanline),
        .end_scanline(end_scanline),
        
        .screen_blank(screen_blank),
        
        .extended_bg_colours(extended_bg_colours)
    );
    
    /* Hardware cursor
     *
     * The cursor is a moveable indicator that typically represents the location
     * where the next character will appear on the screen. However, it is
     * completely independent of any output processes, and is thus a purely
     * software controllable indicator.
     *
     * It is configurable in terms of number of scanlines that is occupies, and
     * also the corresponding VRAM address at which it appears. The address
     * where the cursor should be placed is calculated as follows:
     *
     *   address = (row * 80) + col
     *
     * It outputs a signal which feeds to the pixel generator, indicating when
     * the cursor should be active, and forces the foreground colour to be
     * displayed when it is active. */
    wire cursor_active;
    
    cursor cursor(
        .vram_address(text_col_val),
        .scanline(scanline_val),
        .blink_state(blink_val[3]),
        .match_address(match_address),
        .cursor_disable(cursor_disable),
        .start_scanline(start_scanline),
        .end_scanline(end_scanline),
        .cursor_active(cursor_active)
    );
    
    /* Pixel generator
     *
     * The pixel generator is responsible for latching font pixel data and
     * colour attributes, along with other signals such as cursor active and
     * blink counter stages, to produce a colour index to the RAMDAC to display
     * the correct colour for each pixel on the screen.
     *
     * It implements a shift register to cycle throuch each pixel of font data
     * supplied by the font ROM, with 1 bits indicating foreground and 0 bits
     * indicating background, and combines blinking text and cursor active
     * signals to produce various effects. */
    pixel_generator pix_gen(
        .reset(~vsync_active),
        .clk(pixel_clk),
        .load(char_pix_count == 8),
        .attribute_data(attribute_data),
        .font_data(font_data),
        .char_msbs(char_msbs),
        .blink_state(blink_val[4]),
        .cursor_active(cursor_active),
        .extended_bg_colours(extended_bg_colours),
        .colour_index(colour_index)
    );
    
    /* The HSYNC pin is active low during horizontal sync */
    assign n_hsync = ~hsync_sync;
    
    /* The VSYNC pin is active high during veritcal sync */
    assign vsync = vsync_sync;
    
    /* Assert n_blank_out when ever:
     *
     *  - horizontal or vertical state machines are outside of active areas; or
     *  - the n_blank_in pin is asserted; or
     *  - the screen blank bit of control register 3 is set */
    assign n_blank_out = hsync_active & vsync_active & n_blank_in &
                         ~screen_blank;
    
    /* The VRAM address is the value of the text column counter */
    assign vram_address = text_col_val;
    
    /* Scanline counter output */
    assign scanline = scanline_val;
endmodule
