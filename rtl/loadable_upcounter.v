`timescale 1ns/1ns

module loadable_upcounter
#(parameter WIDTH=8,
            INCREMENT=1
)
(
    input wire reset,
    input wire clk,
    input wire load,
    input wire [WIDTH-1:0] value,
    output reg [WIDTH-1:0] count
);
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            /* When reset is asserted, reset the counter to 0 */
            count <= {WIDTH{1'b0}};
        end
        else if (load) begin
            /* When the load signal is asserted, load value into the counter */
            count <= value;
        end
        else begin
            /* Otherwise increment for each clock */
            count <= count + INCREMENT;
        end
    end
endmodule
