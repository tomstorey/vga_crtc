`timescale 1ns/1ns

module upcounter
#(parameter WIDTH=8,
            INCREMENT=1,
            MAX_COUNT=-1,
            RESET_VALUE=0
)
(
    input wire reset,
    input wire enable,
    input wire clk,
    output reg[WIDTH-1:0] count
);
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            /* When reset is asserted, reset the counter to 0 */
            count <= RESET_VALUE;
        end
        else begin
            if (enable) begin
                if (count < MAX_COUNT) begin
                    /* If the count is below the MAX_COUNT value, increment */
                    count <= count + INCREMENT;
                end
                else begin
                    /* Otherwise, reset to 0 */
                    count <= {WIDTH{1'b0}};
                end
            end
        end
    end
endmodule
