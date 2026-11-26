module pc (
    input  wire        clk,
    input  wire        reset,
    output reg  [31:0] pc_out
);

    always @(posedge clk or posedge reset) begin
        if (reset)
            pc_out <= 32'h00000000;
        else
            pc_out <= pc_out + 32'd4;
    end

endmodule