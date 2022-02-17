`timescale 1ns/1ns

module cursor
(
    input wire [10:0] vram_address,
    input wire [3:0] scanline,
    input wire blink_state,
    
    input wire [10:0] match_address,
    input wire cursor_disable,
    input wire [3:0] start_scanline,
    input wire [3:0] end_scanline,
    
    output wire cursor_active
);
    /* The cursor is active when:
     *
     *  - The current VRAM address for loading colour attribute and font pixel
     *    data matches the configured match address; and
     *  - The current scanline is >= to the configured start scanline; and
     *  - The current scanline is <= to the configured end scanline; and
     *  - The blink state input is a logic high; and
     *  - The cursor is not disabled
     *
     * When all of the conditions above are met, the cursor will be drawn to the
     * screen by the pixel generator. */
    assign cursor_active = ((match_address == vram_address) &
                            (scanline >= start_scanline) &
                            (scanline <= end_scanline)) &
                           blink_state &
                           ~cursor_disable;
endmodule
