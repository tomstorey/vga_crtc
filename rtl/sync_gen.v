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

module sync_gen
#(parameter WIDTH,
            ACTIVE_COUNT,
            FRONT_COUNT,
            SYNC_COUNT,
            RESET_COUNT
)
(
    input wire reset,
    input wire clk,
    output wire backporch,
    output wire active,
    output wire frontporch,
    output wire sync
);
    /* State machine states */
    localparam [1:0]
        STATE_BACKPORCH = 2'b00,
        STATE_ACTIVE = 2'b01,
        STATE_FRONTPORCH = 2'b10,
        STATE_SYNC = 2'b11;

    /* n bit counter that tracks the number of pixel columns or rows */
    reg[WIDTH-1:0] count = 0;
    
    /* 2 bit register to hold the state machines state */
    reg[1:0] state = 0;
    
    /* Counts at which the state machine is advanced */
    wire sm_clk = (count == ACTIVE_COUNT) |
                  (count == FRONT_COUNT) |
                  (count == SYNC_COUNT) |
                  (count == RESET_COUNT);

    /* Set outputs high when the state machine is in the corresponding state */
    assign backporch = (state == STATE_BACKPORCH);
    assign active = (state == STATE_ACTIVE);
    assign frontporch = (state == STATE_FRONTPORCH);
    assign sync = (state == STATE_SYNC);
    
    /* Counter implementation */
    always @(posedge clk, posedge reset)
    begin
        if (reset) begin
            /* When reset is asserted, reset the counter to 0 */
            count <= {WIDTH{1'b0}};
        end
        else if (count == RESET_COUNT) begin
            /* At the reset count, reset the counter to 0 */
            count <= {WIDTH{1'b0}};
        end
        else begin
            /* Otherwise, increment the counter for each clock */
            count <= count + 1'b1;
        end
    end
    
    /* State machine implementation */
    always @(posedge sm_clk, posedge reset)
    begin
        if (reset) begin
            /* When reset is asserted, the state machine returns to the
             * BACKPORCH state */
            state <= STATE_BACKPORCH;
        end
        else begin
            case (state)
                STATE_BACKPORCH:
                    /* When the count reaches the active count, proceed to the
                     * ACTIVE state */
                    state <= STATE_ACTIVE;
                
                STATE_ACTIVE:
                    /* When the count reaches the front porch count, proceed to
                     * the FRONTPORCH state */
                    state <= STATE_FRONTPORCH;
                
                STATE_FRONTPORCH:
                    /* When the count reaches the sync count, proceed to the
                     * SYNC state */
                    state <= STATE_SYNC;
                
                STATE_SYNC:
                    /* When the count reaches the reset count, proceed to the
                     * BACKPORCH state */
                    state <= STATE_BACKPORCH;
            endcase
        end
    end
endmodule
