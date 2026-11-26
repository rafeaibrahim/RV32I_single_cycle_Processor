// control.v - Control Unit for single-cycle RV32I
// op_a_sel : 00 = rs1      01 = PC        10 = zero      (LUI/AUIPC trick)
// alu_src  : 0  = rs2      1  = imm
// wb_sel   : 00 = ALU      01 = mem data  10 = PC+4      (JAL/JALR link)
// pc_sel   : 00 = PC+4     01 = PC+imm    10 = (rs1+imm)&~1 (JALR)
// imm_sel  : 000 I  001 S  010 B  011 U  100 J
// alu_op   : 0 ADD 1 SUB 2 SLL 3 SLT 4 SLTU 5 XOR 6 SRL 7 SRA 8 OR 9 AND
module control (
    input  wire [6:0] opcode,
    input  wire [2:0] funct3,
    input  wire [6:0] funct7,
    input  wire       zero,        // from alu: a == b
    input  wire       lt,          // from alu: signed   a <  b
    input  wire       ltu,         // from alu: unsigned a <  b
    output reg        reg_write,
    output reg        alu_src,
    output reg        mem_read,
    output reg        mem_write,
    output reg  [1:0] op_a_sel,
    output reg  [1:0] wb_sel,
    output reg  [1:0] pc_sel,
    output reg  [2:0] imm_sel,
    output reg  [3:0] alu_op,
    output reg        halt,        // ECALL / EBREAK
    output reg        illegal      // unsupported / malformed instruction
);

    localparam OP_R      = 7'b0110011;
    localparam OP_IALU   = 7'b0010011;
    localparam OP_LOAD   = 7'b0000011;
    localparam OP_STORE  = 7'b0100011;
    localparam OP_BRANCH = 7'b1100011;
    localparam OP_JAL    = 7'b1101111;
    localparam OP_JALR   = 7'b1100111;
    localparam OP_LUI    = 7'b0110111;
    localparam OP_AUIPC  = 7'b0010111;
    localparam OP_FENCE  = 7'b0001111;
    localparam OP_SYSTEM = 7'b1110011;

    localparam ALU_ADD=4'd0, ALU_SUB=4'd1, ALU_SLL=4'd2, ALU_SLT=4'd3, ALU_SLTU=4'd4,
               ALU_XOR=4'd5, ALU_SRL=4'd6, ALU_SRA=4'd7, ALU_OR=4'd8,  ALU_AND=4'd9;

    localparam IMM_I=3'd0, IMM_S=3'd1, IMM_B=3'd2, IMM_U=3'd3, IMM_J=3'd4;

    wire is_r = (opcode == OP_R);

    // ALU function for R-type and I-type ALU instructions.
    // funct7[5] selects SUB only for R-type (ADDI with a negative immediate also has instr[30]=1).
    reg [3:0] alu_fn;
    always @(*) begin
        case (funct3)
            3'b000:  alu_fn = (is_r && funct7[5]) ? ALU_SUB : ALU_ADD;
            3'b001:  alu_fn = ALU_SLL;
            3'b010:  alu_fn = ALU_SLT;
            3'b011:  alu_fn = ALU_SLTU;
            3'b100:  alu_fn = ALU_XOR;
            3'b101:  alu_fn = funct7[5] ? ALU_SRA : ALU_SRL;
            3'b110:  alu_fn = ALU_OR;
            3'b111:  alu_fn = ALU_AND;
            default: alu_fn = ALU_ADD;
        endcase
    end

    // branch condition
    reg br_taken;
    always @(*) begin
        case (funct3)
            3'b000:  br_taken = zero;     // BEQ
            3'b001:  br_taken = ~zero;    // BNE
            3'b100:  br_taken = lt;       // BLT
            3'b101:  br_taken = ~lt;      // BGE
            3'b110:  br_taken = ltu;      // BLTU
            3'b111:  br_taken = ~ltu;     // BGEU
            default: br_taken = 1'b0;
        endcase
    end

    // legality helpers
    wire f7_zero   = (funct7 == 7'b0000000);
    wire f7_alt    = (funct7 == 7'b0100000);
    wire r_ok      = f7_zero | (f7_alt & ((funct3 == 3'b000) | (funct3 == 3'b101)));
    wire shift_ok  = (funct3 == 3'b001) ? f7_zero :
                     (funct3 == 3'b101) ? (f7_zero | f7_alt) : 1'b1;
    wire load_ok   = (funct3 == 3'b000) | (funct3 == 3'b001) | (funct3 == 3'b010) |
                     (funct3 == 3'b100) | (funct3 == 3'b101);
    wire store_ok  = (funct3 == 3'b000) | (funct3 == 3'b001) | (funct3 == 3'b010);
    wire branch_ok = ~((funct3 == 3'b010) | (funct3 == 3'b011));

    // main decoder
    always @(*) begin
        // safe defaults (prevent latches)
        reg_write = 1'b0;
        alu_src   = 1'b0;
        mem_read  = 1'b0;
        mem_write = 1'b0;
        op_a_sel  = 2'b00;
        wb_sel    = 2'b00;
        pc_sel    = 2'b00;
        imm_sel   = IMM_I;
        alu_op    = ALU_ADD;
        halt      = 1'b0;
        illegal   = 1'b0;

        case (opcode)
            OP_R: begin
                reg_write = 1'b1;
                alu_op    = alu_fn;
                illegal   = ~r_ok;
            end
            OP_IALU: begin
                reg_write = 1'b1;
                alu_src   = 1'b1;
                imm_sel   = IMM_I;
                alu_op    = alu_fn;
                illegal   = ~shift_ok;
            end
            OP_LOAD: begin
                reg_write = 1'b1;
                alu_src   = 1'b1;
                mem_read  = 1'b1;
                wb_sel    = 2'b01;
                imm_sel   = IMM_I;
                illegal   = ~load_ok;
            end
            OP_STORE: begin
                alu_src   = 1'b1;
                mem_write = 1'b1;
                imm_sel   = IMM_S;
                illegal   = ~store_ok;
            end
            OP_BRANCH: begin
                imm_sel   = IMM_B;
                alu_op    = ALU_SUB;
                pc_sel    = br_taken ? 2'b01 : 2'b00;
                illegal   = ~branch_ok;
            end
            OP_JAL: begin
                reg_write = 1'b1;
                wb_sel    = 2'b10;
                imm_sel   = IMM_J;
                pc_sel    = 2'b01;
            end
            OP_JALR: begin
                reg_write = 1'b1;
                alu_src   = 1'b1;
                wb_sel    = 2'b10;
                imm_sel   = IMM_I;
                pc_sel    = 2'b10;
                illegal   = (funct3 != 3'b000);
            end
            OP_LUI: begin
                reg_write = 1'b1;
                alu_src   = 1'b1;
                op_a_sel  = 2'b10;      // 0 + imm
                imm_sel   = IMM_U;
            end
            OP_AUIPC: begin
                reg_write = 1'b1;
                alu_src   = 1'b1;
                op_a_sel  = 2'b01;      // PC + imm
                imm_sel   = IMM_U;
            end
            OP_FENCE: begin
                // treated as NOP
            end
            OP_SYSTEM: begin
                if (funct3 == 3'b000) halt    = 1'b1;   // ECALL / EBREAK
                else                  illegal = 1'b1;   // CSR ops not supported
            end
            default: illegal = 1'b1;
        endcase

        // safe-fail: an illegal instruction must not change any state
        if (illegal) begin
            reg_write = 1'b0;
            mem_write = 1'b0;
            mem_read  = 1'b0;
            pc_sel    = 2'b00;
        end
    end

endmodule