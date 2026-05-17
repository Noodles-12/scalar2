`timescale 1ns / 1ps

import config_pkg::*;

module test_processor(
    input logic clk, 
    input logic rst
);

    // Program Counter
    logic [ADDRBUS_SIZE-1:0] pc_next, pc_out;
    assign pc_next = pc_out + ADDRBUS_SIZE'(2);

    // Fetch
    instruction instr_a, instr_b;

    // Rename
    rs_entry rename_a, rename_b;
    rob_entry rob_a, rob_b;

    program_counter pc(.clk(clk),
                       .write_enable(~rst),
                       .ip_addr(pc_next),
                       .op_addr(pc_out) );

    instruction_memory instr_mem(.clk(clk),
                                 .rst(rst),
                                 .ip_addr(pc_out),
                                 .instr_a(instr_a),
                                 .instr_b(instr_b) );

     reg_file rf(.clk(clk),
                .rst(rst),
                .og_instr_a(instr_a),
                .og_instr_b(instr_b),
                .cdb_arr(),
                .commit_arr(),
                .rename_a(rename_a),
                .rename_b(rename_b),
                .rob_a(rob_a),
                .rob_b(rob_b) );
endmodule