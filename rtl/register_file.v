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

module register_file
(
    input wire reset,                   /* Async reset */
    
    input wire [7:0] cpu_data,          /* CPU data bus (bidir) */
    input wire [1:0] cpu_address,       /* CPU address bus */
    input wire n_write,                 /* CPU write signal */
    
    /* Outputs to cursor module */
    output wire [10:0] match_address,
    output wire cursor_disable,
    output wire [3:0] start_scanline,
    output wire [3:0] end_scanline,
    
    /* Outputs to display control interface */
    output wire screen_blank,

    /* Outputs to pixel generator module */
    output wire extended_bg_colours
);
    /* Match address register */
    reg [10:0] match_address_latch;
    
    /* Cursor disable latch */
    reg cursor_disable_latch;
    
    /* Start/end scanlines */
    reg [3:0] start_scanline_latch;
    reg [3:0] end_scanline_latch;
    
    /* Screen blank latch */
    reg screen_blank_latch;
    
    /* Extended background colour mode latch */
    reg extended_bg_colours_latch;
    
    /* Write signals for the various registers */
    wire write_register_0 = n_write | ~(cpu_address == 2'b00);
    wire write_register_1 = n_write | ~(cpu_address == 2'b01);
    wire write_register_2 = n_write | ~(cpu_address == 2'b10);
    wire write_register_3 = n_write | ~(cpu_address == 2'b11);
    
    /* Register outputs */
    assign match_address = match_address_latch;
    assign cursor_disable = cursor_disable_latch;
    assign start_scanline = start_scanline_latch;
    assign end_scanline = end_scanline_latch;
    assign screen_blank = screen_blank_latch;
    assign extended_bg_colours = extended_bg_colours_latch;
    
    /* Register address 0 load and reset */
    always @(posedge reset, posedge write_register_0) begin
        if (reset) begin
            /* On reset, the cursor is enabled and placed in the top left corner
             * of the screen (address 0) */
            cursor_disable_latch <= 1'b0;
            match_address_latch[10:8] <= 3'b000;
        end
        else begin
            cursor_disable_latch <= cpu_data[7];
            match_address_latch[10:8] <= cpu_data[2:0];
        end
    end
    
    /* Register address 1 load and reset */
    always @(posedge reset, posedge write_register_1) begin
        if (reset) begin
            /* On reset the cursor is placed in the top left corner of the
             * screen (address 0) */
            match_address_latch[7:0] <= 8'b00000000;
        end
        else begin
            match_address_latch[7:0] <= cpu_data[7:0];
        end
    end
    
    /* Register address 2 load and reset */
    always @(posedge reset, posedge write_register_2) begin
        if (reset) begin
            /* On reset the cursor occupies scanlines 13 and 14 */
            end_scanline_latch <= 4'b1110;
            start_scanline_latch <= 4'b1101;
        end
        else begin
            end_scanline_latch <= cpu_data[7:4];
            start_scanline_latch <= cpu_data[3:0];
        end
    end
    
    /* Register address 3 load and reset */
    always @(posedge reset, posedge write_register_3) begin
        if (reset) begin
            /* On reset, extended background colour mode is disabled, and the
             * screen is not blanked */
            extended_bg_colours_latch <= 1'b0;
            screen_blank_latch <= 1'b0;
        end
        else begin
            extended_bg_colours_latch <= cpu_data[0];
            screen_blank_latch <= cpu_data[4];
        end
    end
endmodule
