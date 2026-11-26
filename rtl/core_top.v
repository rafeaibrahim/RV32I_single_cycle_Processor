
module core_top (
    input  wire        clk,
    input  wire        reset,

    output wire [31:0] pc_debug,
    output wire [31:0] instr_debug,
    output wire [31:0] alu_debug,
    output wire        halted,
    output wire        illegal_debug
);

    // Internal wires
    wire [31:0] pc_out;
    wire [31:0] pc_next;
    wire [31:0] instr;

    wire [31:0] rs1_data;
    wire [31:0] rs2_data;
    wire [31:0] write_back_data;

    wire [31:0] imm;
    wire [31:0] alu_a;
    wire [31:0] alu_b;
    wire [31:0] alu_result;

    wire [31:0] mem_read_data;

    wire zero, lt, ltu;
    wire flag_neg, flag_ovf;

    wire reg_write;
    wire alu_src;
    wire mem_read;
    wire mem_write;

    wire [1:0] op_a_sel;
    wire [1:0] wb_sel;
    wire [1:0] pc_sel;

    wire [2:0] imm_sel;
    wire [3:0] alu_op;

    wire [31:0] pc_plus4;
    wire [31:0] branch_target;
    wire [31:0] jalr_target;
    wire [31:0] selected_pc;


    // 1. Program Counter
    pc PC (
        .clk(clk),
        .reset(reset),
        .pc_next(pc_next),
        .pc_out(pc_out)
    );


    // 2. Instruction Memory
    instruction_memory IMEM (
        .addr(pc_out),
        .instr(instr)
    );


    // 3. Register File
    register_file RF (
        .clk(clk),
        .reg_write(reg_write),
        .rs1(instr[19:15]),
        .rs2(instr[24:20]),
        .rd(instr[11:7]),
        .write_data(write_back_data),
        .read_data1(rs1_data),
        .read_data2(rs2_data)
    );


    // 4. Immediate Generator
    imm_gen IG (
        .instr(instr),
        .imm_sel(imm_sel),
        .imm(imm)
    );


    // 5. Control Unit
    control CU (
        .opcode(instr[6:0]),
        .funct3(instr[14:12]),
        .funct7(instr[31:25]),

        .zero(zero),
        .lt(lt),
        .ltu(ltu),

        .reg_write(reg_write),
        .alu_src(alu_src),
        .mem_read(mem_read),
        .mem_write(mem_write),

        .op_a_sel(op_a_sel),
        .wb_sel(wb_sel),
        .pc_sel(pc_sel),

        .imm_sel(imm_sel),
        .alu_op(alu_op),

        .halt(halted),
        .illegal(illegal_debug)
    );


    // 6. ALU Operand A Multiplexer
    mux4 #(32) ALU_A_MUX (
        .d0(rs1_data),
        .d1(pc_out),
        .d2(32'b0),
        .d3(32'b0),
        .sel(op_a_sel),
        .y(alu_a)
    );


    // 7. ALU Operand B Multiplexer
    mux2 #(32) ALU_B_MUX (
        .d0(rs2_data),
        .d1(imm),
        .sel(alu_src),
        .y(alu_b)
    );


    // 8. ALU
    alu #(32) ALU (
        .a(alu_a),
        .b(alu_b),
        .alu_op(alu_op),
        .result(alu_result),
        .zero(zero),
        .lt(lt),
        .ltu(ltu),
        .flag_neg(flag_neg),
        .flag_ovf(flag_ovf)
    );


    // 9. Data Memory
    data_memory DMEM (
        .clk(clk),
        .mem_write(mem_write),
        .mem_read(mem_read),
        .funct3(instr[14:12]),
        .addr(alu_result),
        .write_data(rs2_data),
        .read_data(mem_read_data)
    );


    // 10. Write Back Multiplexer
    mux4 #(32) WB_MUX (
        .d0(alu_result),
        .d1(mem_read_data),
        .d2(pc_plus4),
        .d3(alu_result),
        .sel(wb_sel),
        .y(write_back_data)
    );


    // 11. Program Counter Calculations
    assign pc_plus4 = pc_out + 32'd4;

    assign branch_target = pc_out + imm;

    assign jalr_target = {alu_result[31:1], 1'b0};


    // 12. PC Selection Multiplexer
    mux4 #(32) PC_MUX (
        .d0(pc_plus4),
        .d1(branch_target),
        .d2(jalr_target),
        .d3(pc_plus4),
        .sel(pc_sel),
        .y(selected_pc)
    );


    // 13. Hold PC when halted or illegal
    assign pc_next =
        (halted || illegal_debug) ? pc_out : selected_pc;


    // 14. Debug Outputs
    assign pc_debug = pc_out;
    assign instr_debug = instr;
    assign alu_debug = alu_result;

endmodule
