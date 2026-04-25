`timescale 1ns / 1ps

import config_pkg::*;

module reg_file_tb();

    logic clk;
    instruction instr_a, instr_b, instr_c;
    rs_entry rs_entry_a, rs_entry_b;

    reg_file rf(.clk(clk),
                .og_instr_a(instr_a),
                .og_instr_b(instr_b),
                .rename_a(rs_entry_a),
                .rename_b(rs_entry_b));

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        instr_a = 30'b000001_0001_0010_0011_000000000000;       // add r1, r2, r3
        instr_b = 30'b000011_0100_0101_0110_000000000000; #10;  // sub r4, r8, r3
        instr_c = 30'b000001_0110_1100_0001_000000000000; #10;  // add r6, r12, r1
        $finish;
    end
endmodule
