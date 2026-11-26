// mux.v - parameterized 2:1 and 4:1 multiplexers
module mux2 #(parameter WIDTH = 32) (
    input  wire [WIDTH-1:0] d0, d1,
    input  wire             sel,
    output wire [WIDTH-1:0] y
);
    assign y = sel ? d1 : d0;
endmodule

module mux4 #(parameter WIDTH = 32) (
    input  wire [WIDTH-1:0] d0, d1, d2, d3,
    input  wire [1:0]       sel,
    output reg  [WIDTH-1:0] y
);
    always @(*) begin
        case (sel)
            2'b00:   y = d0;
            2'b01:   y = d1;
            2'b10:   y = d2;
            2'b11:   y = d3;
            default: y = d0;
        endcase
    end
endmodule