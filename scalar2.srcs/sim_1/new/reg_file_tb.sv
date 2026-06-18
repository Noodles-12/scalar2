`timescale 1ns / 1ps

import config_pkg::*;

module reg_file_tb();

    logic clk, rst;
    instruction instr_a, instr_b;
    rs_entry rs_entry_a, rs_entry_b;

    register_file rf(.clk(clk),
                .rst(rst),
                .instr_a(instr_a),
                .instr_b(instr_b),
                .cdb_arr(),
                .commit_arr(),
                .res_stat_a_op(rs_entry_a),
                .res_stat_b_op(rs_entry_b),
                .rob_a_op(),
                .rob_b_op() );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        rst = 1; #10; rst = 0;
        // This is needed to let the free finders get an extra cycle to find free registers on the fresh free_regs
        // Not an issue when doing a full processor implementation hopefully
        #10;
        instr_a = 32'b000001_0001_0010_0011_000000000000_00;        // add r1, r2, r3
        instr_b = 32'b000011_0100_0001_0110_000000000000_00; #10;   // sub r4, r1, r3 RAW
        
        instr_a = 32'b000001_0010_0010_0011_000000000000_00;        // add r2, r2, r3 WAR
        instr_b = 32'b001111_0010_0100_0000_000000000101_00; #10;   // addi r2, r4, 5 WAW & RAW 

        instr_a = 32'b0;
        instr_b = 32'b0; #30;
        $finish;
    end
endmodule
