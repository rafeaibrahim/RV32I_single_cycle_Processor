// alu.v - parameterized ALU with comparison + status flags
module alu #(parameter XLEN = 32) (
    input  wire [XLEN-1:0] a, b,
    input  wire [3:0]      alu_op,
    output reg  [XLEN-1:0] result,
    output wire            zero, lt, ltu, flag_neg, flag_ovf
);
    localparam ADD=4'd0, SUB=4'd1, SLL=4'd2, SLT=4'd3, SLTU=4'd4,
               XOR_=4'd5, SRL=4'd6, SRA=4'd7, OR_=4'd8, AND_=4'd9;

    wire [XLEN-1:0] diff = a - b;
    assign zero     = (a == b);
    assign lt       = ($signed(a) < $signed(b));
    assign ltu      = (a < b);
    assign flag_neg = result[XLEN-1];
    assign flag_ovf = (a[XLEN-1] ^ b[XLEN-1]) & (a[XLEN-1] ^ diff[XLEN-1]); // meaningful for SUB

    always @(*) begin
        case (alu_op)
            ADD:     result = a + b;
            SUB:     result = diff;
            SLL:     result = a << b[4:0];
            SLT:     result = {{(XLEN-1){1'b0}}, lt};
            SLTU:    result = {{(XLEN-1){1'b0}}, ltu};
            XOR_:    result = a ^ b;
            SRL:     result = a >> b[4:0];
            SRA:     result = $signed(a) >>> b[4:0];
            OR_:     result = a | b;
            AND_:    result = a & b;
            default: result = {XLEN{1'b0}};
        endcase
    end
endmodule