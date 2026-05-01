`timescale 1ns / 1ps

import config_pkg::*;

module rename_rs_rob_tb();
    // Inputs
    logic clk, rst;
    instruction instr_a, instr_b;

    rs_entry rename_a, rename_b;
    rob_entry rob_a, rob_b; 

    rs_entry rs_entry_a [0:3], rs_entry_b [0:3];
    rob_entry rob_entry_a, rob_entry_b;

    rob_entry output_rob [0:3];

    int_rs_entry intrs_op_a, intrs_op_b;
    imm_rs_entry immrs_op_a, immrs_op_b;

    logic almost_full_int, almost_full_imm;

    cdb_entry fu_int_a, fu_int_b;
    cdb_entry fu_imm_a, fu_imm_b;

    reg_file rf(.clk(clk),
                .rst(rst),
                .og_instr_a(instr_a),
                .og_instr_b(instr_b),
                .rename_a(rename_a),
                .rename_b(rename_b),
                .rob_a(rob_a),
                .rob_b(rob_b) );
    
    rename_dispatch_pl dispatch(.clk(clk),
                                .rename_a(rename_a),
                                .rename_b(rename_b),
                                .rob_a(rob_a),
                                .rob_b(rob_b),
                                .rs_op_a(rs_entry_a),
                                .rs_op_b(rs_entry_b),
                                .rob_op_a(rob_entry_a),
                                .rob_op_b(rob_entry_b) );
               
    reorder_buffer rob(.clk(clk),
                       .input_a(rob_entry_a),
                       .input_b(rob_entry_b),
                       .output_arr(output_rob) );

    res_station_int rs_int(.clk(clk),
                           .instr_a(rs_entry_a[0]),
                           .instr_b(rs_entry_b[0]),
                           .almost_full(almost_full_int),
                           .output_a(intrs_op_a),
                           .output_b(intrs_op_b) );

    func_unit_int fu_int(.clk(clk),
                         .int_instr_a(intrs_op_a),
                         .int_instr_b(intrs_op_b),
                         .out_a(fu_int_a),
                         .out_b(fu_int_b) );

    res_station_imm rs_imm(.clk(clk),
                           .instr_a(rs_entry_a[1]),
                           .instr_b(rs_entry_b[1]),
                           .almost_full(almost_full_imm),
                           .output_a(immrs_op_a),
                           .output_b(immrs_op_b) );

    func_unit_imm fu_imm(.clk(clk),
                         .imm_instr_a(immrs_op_a),
                         .imm_instr_b(immrs_op_b),
                         .out_a(fu_imm_a),
                         .out_b(fu_imm_b) );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        rst = 1; #10; rst = 0;
        instr_a = 30'b010000_0001_0010_0000_000000000111;                 // add r1, r2, r3
        instr_b = 30'b000001_0100_0011_0110_000000000000; #10;            // sub r4, r1, r3 RAW
        instr_a = 0; instr_b = 0; #10; #10; #10; #10; #10; #10;
        $finish;
    end

endmodule
