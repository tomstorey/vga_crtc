`timescale 1ns/1ns

module upcounter
#(parameter WIDTH=8,
            INCREMENT=1,
            RESET_COUNT=-1
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
            count <= {WIDTH{1'b0}};
        end
        else if (enable) begin
            if (count >= (RESET_COUNT - INCREMENT)) begin
                /* When the count reaches or exceeds the reset value, reset the
                 * counter to 0 */
                count <= {WIDTH{1'b0}};
            end
            else begin
                /* Otherwise increment for each clock */
                count <= count + INCREMENT;
            end
        end
    end
endmodule
