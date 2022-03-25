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

module pixel_generator
(
    input wire reset,                   /* Async reset */
    input wire clk,                     /* Pixel clock, for shifting */
    input wire load,                    /* Sync load of new pixel data */
    input wire [7:0] attribute_data,    /* Colour attributes from VRAM */
    input wire [7:0] font_data,         /* Font pixel data, from font ROM */
    input wire [2:0] char_msbs,         /* 3 MSbs of character code */
    input wire blink_state,             /* For generating blinking text */
    input wire cursor_active,           /* For drawing the cursor */
    input wire extended_bg_colours,     /* 16 BG colour mode */
    
    output wire [3:0] colour_index      /* 4 bit colour index to RAMDAC */
);

    /* The pixel shift register is 9 bits wide. Depending on the upper 3 bits of
     * the character code (supplied by char_msbs), bits [1:0] may be loaded with
     * the same value. This is because some characters, such as box drawing
     * characters in the range 0xC0 to 0xDF may stretched to the right to join
     * with neighboring characters, thus making them 9 pixels wide instead of 8.
     * All other character codes will result in bit 0 of the shift register
     * being loaded with a 0, making them 8 bits wide. */
    reg [8:0] pixels;
    
    /* This register holds a copy of the colour attributes for the current
     * character */
    reg [7:0] attributes;
    
    /* Latched copy of the cursor active signal used to determine if the cursor
     * should be displayed on the screen */
    reg cursor_active_latch;
    
    /* Conditions under which the foreground colour index should be selected for
     * output to the RAMDAC:
     *
     *  - If the cursor is active at this row/col and scanline, as determined by
     *    cursor logic
     *  - Blink attribute is false the the current pixel is a 1
     *  - Blink attribute is true, the text blink state is 1, and the current
     *    pixel is a 1
     *
     * In all other conditions, the background colour is selected. */
    wire foreground = cursor_active_latch |
                      ~attributes[7] & pixels[8] |
                      ~extended_bg_colours & attributes[7] & blink_state & pixels[8] |
                      extended_bg_colours & pixels[8];
    
    /* This mux will output either the foreground or background colour index to
     * the RAMDAC */
    wire [3:0] foreground_colour = attributes[3:0];
    wire [3:0] background_colour =
        extended_bg_colours ? attributes[7:4] : {1'b0, attributes[6:4]};
        
    assign colour_index = foreground ? foreground_colour : background_colour;
    
    /* Shift register implementation */
    always @(posedge reset, posedge clk) begin
        if (reset) begin
            /* When reset is asserted, the shift register is cleared */
            pixels <= 9'b000000000;
        end
        else begin
            if (load) begin
                if (char_msbs == 3'b110) begin
                    /* Character code is in the range 0xC0 to 0xDF, so the character
                     * should be stretched to 9 pixels wide */
                     pixels = {font_data, font_data[0]};
                end
                else begin
                    /* All other characters are 8 pixels wide */
                     pixels = {font_data, 1'b0};
                end
            end
            else begin
                /* All other cases, the shift register advances */
                pixels <= {pixels[7:0], 1'b0};
            end
        end
    end
    
    /* Colour attribute latch loading */
    always @(posedge clk) begin
        /* It isnt necessary to reset the latched colour attributes, because
         * they are always latched for every character that is to be displayed,
         * thus the value in these latches will always be relevant for the
         * character currently being written */
        if (load) begin
            attributes <= attribute_data;
        end
    end
    
    /* Cursor active latch loading */
    always @(posedge clk) begin
        /* Likewise for the cursor active latch, it is not necessary to reset
         * because the latch will be updated for every character position */
        if (load) begin
            cursor_active_latch <= cursor_active;
        end
    end
endmodule
