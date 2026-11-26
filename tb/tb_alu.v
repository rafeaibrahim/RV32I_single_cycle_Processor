// Self-checking testbench for alu.v (directed + random tests)
`timescale 1ns/1ps
module tb_alu;
    reg  [31:0] a, b;
    reg  [3:0]  alu_op;
    wire [31:0] result;
    wire        zero, lt, ltu, flag_neg, flag_ovf;

    alu #(.XLEN(32)) dut (.a(a), .b(b), .alu_op(alu_op), .result(result),
                          .zero(zero), .lt(lt), .ltu(ltu),
                          .flag_neg(flag_neg), .flag_ovf(flag_ovf));

    localparam ADD=4'd0, SUB=4'd1, SLL=4'd2, SLT=4'd3, SLTU=4'd4,
               XOR_=4'd5, SRL=4'd6, SRA=4'd7, OR_=4'd8, AND_=4'd9;

    integer pass = 0, fail = 0, i;

    // reference model used for the random tests
    function [31:0] ref_alu(input [31:0] x, input [31:0] y, input [3:0] op);
        begin
            case (op)
                ADD:     ref_alu = x + y;
                SUB:     ref_alu = x - y;
                SLL:     ref_alu = x << y[4:0];
                SLT:     ref_alu = ($signed(x) < $signed(y)) ? 32'd1 : 32'd0;
                SLTU:    ref_alu = (x < y) ? 32'd1 : 32'd0;
                XOR_:    ref_alu = x ^ y;
                SRL:     ref_alu = x >> y[4:0];
                SRA:     ref_alu = $signed(x) >>> y[4:0];
                OR_:     ref_alu = x | y;
                AND_:    ref_alu = x & y;
                default: ref_alu = 32'd0;
            endcase
        end
    endfunction

    // check result AND the comparison flags
    task check(input [127:0] name, input [31:0] x, input [31:0] y,
               input [3:0] op, input [31:0] expected);
        reg e_zero, e_lt, e_ltu;
        begin
            a = x; b = y; alu_op = op;
            #1;
            e_zero = (x == y);
            e_lt   = ($signed(x) < $signed(y));
            e_ltu  = (x < y);
            if (result === expected && zero === e_zero && lt === e_lt && ltu === e_ltu)
                pass = pass + 1;
            else begin
                fail = fail + 1;
                $display("FAIL %0s: a=%h b=%h op=%0d -> result=%h (exp %h) zero=%b lt=%b ltu=%b",
                         name, x, y, op, result, expected, zero, lt, ltu);
            end
        end
    endtask

    initial begin
        // ---------- directed tests ----------
        check("add basic",      32'd5,         32'd3,         ADD,  32'd8);
        check("add wrap",       32'hFFFFFFFF,  32'd1,         ADD,  32'd0);
        check("add ovf",        32'h7FFFFFFF,  32'd1,         ADD,  32'h80000000);
        check("sub basic",      32'd5,         32'd3,         SUB,  32'd2);
        check("sub negative",   32'd3,         32'd5,         SUB,  32'hFFFFFFFE);
        check("sub same",       32'hDEADBEEF,  32'hDEADBEEF,  SUB,  32'd0);
        check("sll 31",         32'd1,         32'd31,        SLL,  32'h80000000);
        check("sll uses b[4:0]",32'd1,         32'd33,        SLL,  32'd2);
        check("slt -1<1",       32'hFFFFFFFF,  32'd1,         SLT,  32'd1);
        check("slt 1<-1",       32'd1,         32'hFFFFFFFF,  SLT,  32'd0);
        check("sltu max<1",     32'hFFFFFFFF,  32'd1,         SLTU, 32'd0);
        check("sltu 1<max",     32'd1,         32'hFFFFFFFF,  SLTU, 32'd1);
        check("xor",            32'hF0F0F0F0,  32'hFFFF0000,  XOR_, 32'h0F0FF0F0);
        check("srl 31",         32'h80000000,  32'd31,        SRL,  32'd1);
        check("sra 31",         32'h80000000,  32'd31,        SRA,  32'hFFFFFFFF);
        check("sra 4",          32'h80000000,  32'd4,         SRA,  32'hF8000000);
        check("sra positive",   32'h40000000,  32'd4,         SRA,  32'h04000000);
        check("or",             32'hF0F0F0F0,  32'h0F0F0F0F,  OR_,  32'hFFFFFFFF);
        check("and",            32'hF0F0F0F0,  32'hFF00FF00,  AND_, 32'hF000F000);
        check("bad op -> 0",    32'h12345678,  32'h9ABCDEF0,  4'd15, 32'd0);

        // ---------- flag tests ----------
        a = 32'h80000000; b = 32'd1; alu_op = SUB; #1;   // most-negative minus 1 overflows
        if (result === 32'h7FFFFFFF && flag_ovf === 1'b1 && flag_neg === 1'b0) pass = pass + 1;
        else begin fail = fail + 1; $display("FAIL flag ovf test: res=%h ovf=%b neg=%b", result, flag_ovf, flag_neg); end

        a = 32'd5; b = 32'd3; alu_op = SUB; #1;           // normal subtract, no overflow
        if (result === 32'd2 && flag_ovf === 1'b0 && flag_neg === 1'b0) pass = pass + 1;
        else begin fail = fail + 1; $display("FAIL flag normal sub: res=%h ovf=%b neg=%b", result, flag_ovf, flag_neg); end

        a = 32'd3; b = 32'd5; alu_op = SUB; #1;           // negative result
        if (result === 32'hFFFFFFFE && flag_neg === 1'b1 && flag_ovf === 1'b0) pass = pass + 1;
        else begin fail = fail + 1; $display("FAIL flag neg: res=%h ovf=%b neg=%b", result, flag_ovf, flag_neg); end

        // ---------- random tests ----------
        for (i = 0; i < 500; i = i + 1) begin
            a = $random;
            b = (i % 5 == 0) ? {27'd0, $random} : $random;   // some small shift amounts
            check("random", a, b, i % 10, ref_alu(a, b, i % 10));
        end

        $display("tb_alu: %0d passed, %0d failed", pass, fail);
        if (fail == 0) $display("ALL TESTS PASSED");
        $finish;
    end
endmodule