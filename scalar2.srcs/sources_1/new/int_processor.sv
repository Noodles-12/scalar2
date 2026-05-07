`timescale 1ns / 1ps

import config_pkg::*;

module int_processor(clk, rst);
    input logic clk, rst;

    // Program Counter
    logic [0:11] pc_next, pc_out;

    // Fetch
    instruction instr_a, instr_b;

    // Rename
    rs_entry rename_a, rename_b;
    rob_entry rob_a, rob_b;

    // Dispatch
    rs_entry rs_op_a [0:3], rs_op_b [0:3];
    rob_entry rob_op_a, rob_op_b;
    assign rs_op_a[2] = '0;
    assign rs_op_a[3] = '0;
    assign rs_op_b[2] = '0;
    assign rs_op_b[3] = '0;

    // Reservation station outputs
    int_rs_entry int_rs_out_a, int_rs_out_b;
    imm_rs_entry imm_rs_out_a, imm_rs_out_b;

    // Functional unit outputs
    cdb_entry int_cdb_a, int_cdb_b;
    cdb_entry imm_cdb_a, imm_cdb_b;

    // CDB broadcast
    cdb_entry cdb_arr [0:3];

    // ROB outputs
    rob_entry rob_out_arr [0:3];
    logic [0:5] id_to_free [0:3];

    // str_rob (no store unit in this processor)
    str_rob_entry str_rob_tie [0:1];
    assign str_rob_tie = '{default: '0};

    assign pc_next = pc_out + 12'd2;

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
                .cdb_arr(cdb_arr),
                .commit_arr(rob_out_arr),
                .rename_a(rename_a),
                .rename_b(rename_b),
                .rob_a(rob_a),
                .rob_b(rob_b) );

    rename_dispatch_pl dp_pl(.clk(clk),
                             .rst(rst),
                             .rename_a(rename_a),
                             .rename_b(rename_b),
                             .rob_a(rob_a),
                             .rob_b(rob_b),
                             .id_to_free(id_to_free),
                             .rs_op_a(rs_op_a),
                             .rs_op_b(rs_op_b),
                             .rob_op_a(rob_op_a),
                             .rob_op_b(rob_op_b) );

    res_station_int rs_int(.clk(clk),
                           .rst(rst),
                           .instr_a(rs_op_a[0].int_rs),
                           .instr_b(rs_op_b[0].int_rs),
                           .cdb_arr(cdb_arr),
                           .output_a(int_rs_out_a),
                           .output_b(int_rs_out_b),
                           .almost_full() );

    res_station_imm rs_imm(.clk(clk),
                           .rst(rst),
                           .instr_a(rs_op_a[1].imm_rs),
                           .instr_b(rs_op_b[1].imm_rs),
                           .cdb_arr(cdb_arr),
                           .output_a(imm_rs_out_a),
                           .output_b(imm_rs_out_b),
                           .almost_full() );

    func_unit_int fu_int(.clk(clk),
                         .rst(rst),
                         .int_instr_a(int_rs_out_a),
                         .int_instr_b(int_rs_out_b),
                         .out_a(int_cdb_a),
                         .out_b(int_cdb_b) );

    func_unit_imm fu_imm(.clk(clk),
                         .rst(rst),
                         .imm_instr_a(imm_rs_out_a),
                         .imm_instr_b(imm_rs_out_b),
                         .out_a(imm_cdb_a),
                         .out_b(imm_cdb_b) );

    common_data_bus cdb_bus(.int_a(int_cdb_a),
                            .int_b(int_cdb_b),
                            .imm_a(imm_cdb_a),
                            .imm_b(imm_cdb_b),
                            .cdb_arr(cdb_arr) );

    reorder_buffer rob(.clk(clk),
                       .rst(rst),
                       .input_a(rob_op_a),
                       .input_b(rob_op_b),
                       .cdb_arr(cdb_arr),
                       .str_rob(str_rob_tie),
                       .output_arr(rob_out_arr),
                       .id_to_free(id_to_free) );

endmodule
