module instruction_memory (
    input  wire [31:0] addr,
    output wire [31:0] instr
);

    reg [31:0] mem [0:63];   // 64 words = 256 bytes
    integer i;

    initial begin
        for (i = 0; i < 64; i = i + 1)
            mem[i] = 32'h00000013;   // NOP (addi x0,x0,0)
        $readmemh("program.hex", mem);
    end

    assign instr = mem[addr[7:2]];

endmodule