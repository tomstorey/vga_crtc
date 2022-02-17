`timescale 1ns/1ns

module pixel_generator
(
    input wire reset,                   /* Async reset */
    input wire clk,                     /* Pixel clock, for shifting */
    input wire load,                    /* Async load of new pixel data */
    input wire [7:0] attribute_data,    /* Colour attributes from VRAM */
    input wire [7:0] font_data,         /* Font pixel data, from font ROM */
    input wire [2:0] char_msbs,         /* 3 MSbs of character code */
    input wire blink_state,             /* For generating blinking text */
    input wire cursor_active,           /* For drawing the cursor */
    input wire extended_bg_colours,     /* 16 BG colours instead of blinking text*/
    
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
    
    /* A latch which is set when the shift register is loaded, and helps to
     * remove a glitch that causes a second load resulting in unwanted
     * duplication of the MSb of pixel data (left hand pixel column) */
    reg just_loaded;
    
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
    
    wire do_load = load & ~just_loaded;
    
    /* Shift register implementation */
    always @(posedge clk, posedge do_load, posedge reset) begin
        if (reset) begin
            /* When reset is asserted, the shift register and just_loaded latch
             * is reset */
            pixels <= 9'b000000000;
            just_loaded <= 1'b0;
        end
        else if (do_load) begin
            if (char_msbs == 3'b110) begin
                /* Character code is in the range 0xC0 to 0xDF, so the character
                 * should be stretched to 9 pixels wide */
                 pixels = {font_data, font_data[0]};
            end
            else begin
                /* All other characters are 8 pixels wide */
                 pixels = {font_data, 1'b0};
            end
            
            /* Set the just_loaded flag to prevent a second load */
            just_loaded <= 1'b1;
        end
        else begin
            /* All other cases, the shift register advances */
            pixels <= {pixels[7:0], 1'b0};
            
            /* Can reset the just_loaded flag, ready for next load */
            just_loaded <= 1'b0;
        end
    end
    
    /* Colour attribute latch loading */
    always @(posedge do_load) begin
        /* It isnt necessary to reset the latched colour attributes, because
         * they are always latched for every character that is to be displayed,
         * thus the value in these latches will always be relevant for the
         * character currently being written */
        attributes <= attribute_data;
    end
    
    /* Cursor active latch loading */
    always @(posedge do_load) begin
        /* Likewise for the cursor active latch, it is not necessary to reset
         * because the latch will be updated for every character position */
        cursor_active_latch <= cursor_active;
    end
endmodule
