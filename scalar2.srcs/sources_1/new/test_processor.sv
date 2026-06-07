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

    // Dispatch
    rs_entry rs_dp_a [0:3], rs_dp_b [0:3];
    rob_entry rob_dp_a, rob_dp_b;

    // Reservation station outputs
    int_rs_entry int_rs_out_a, int_rs_out_b;
    imm_rs_entry imm_rs_out_a, imm_rs_out_b;

    str_disp_entry str_disp_a, str_disp_b;
    load_fwd_addr load_fwd_a, load_fwd_b;

    // Functional unit outputs
    cdb_entry int_cdb_a, int_cdb_b;
    cdb_entry imm_cdb_a, imm_cdb_b;

    str_disp_entry str_rob [0:1];
    load_fwd_addr load_fwd_addrs [0:1];

    // CDB output
    cdb_entry cdb_arr [0:CDB_SIZE - 1];

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
                .instr_a(instr_a),
                .instr_b(instr_b),
                .cdb_arr(),
                .commit_arr(),
                .rename_a(rename_a),
                .rename_b(rename_b),
                .rob_a(rob_a),
                .rob_b(rob_b) );

    rename_dispatch_pl rd_pl(.clk(clk),
                             .rst(rst),
                             .rename_a(rename_a),
                             .rename_b(rename_b),
                             .rob_a(rob_a),
                             .rob_b(rob_b),
                             .id_to_free(),
                             .rs_op_a(rs_dp_a),
                             .rs_op_b(rs_dp_b),
                             .rob_op_a(rob_dp_a),
                             .rob_op_b(rob_dp_b) );

    res_station_int rs_int(.clk(clk),
                           .rst(rst),
                           .instr_a(rs_dp_a[0]),
                           .instr_b(rs_dp_b[0]),
                           .cdb_arr(cdb_arr),
                           .output_a_reg(int_rs_out_a),
                           .output_b_reg(int_rs_out_b),
                           .almost_full() );

    /* res_station_imm rs_imm(.clk(clk),
                           .rst(rst),
                           .instr_a(rs_dp_a[1]),
                           .instr_b(rs_dp_b[1]),
                           .cdb_arr(cdb_arr),
                           .output_a_reg(imm_rs_out_a),
                           .output_b_reg(imm_rs_out_b),
                           .almost_full() );

    res_station_mem rs_mem(.clk(clk),
                           .rst(rst),
                           .instr_a(rs_dp_a[2]),
                           .instr_b(rs_dp_b[2]),
                           .cdb_arr(),
                           .id_to_free(),
                           .str_fwd_vals(str_rob),
                           .load_fwd_addrs(load_fwd_addrs),
                           .str_disp_a_reg(str_disp_a),
                           .str_disp_b_reg(str_disp_b),
                           .load_fwd_a_reg(load_fwd_a),
                           .load_fwd_b_reg(load_fwd_b),
                           .load_disp_mem(),
                           .load_disp_imm() ); */

    func_unit_int fu_int(.clk(clk),
                         .rst(rst),
                         .int_instr_a(int_rs_out_a),
                         .int_instr_b(int_rs_out_b),
                         .out_a(int_cdb_a),
                         .out_b(int_cdb_b) );

    /* func_unit_imm fu_imm(.clk(clk),
                         .rst(rst),
                         .imm_instr_a(imm_rs_out_a),
                         .imm_instr_b(imm_rs_out_b),
                         .out_a(imm_cdb_a),
                         .out_b(imm_cdb_b) );

    func_unit_str fu_str(.clk(clk),
                         .rst(rst),
                         .str_a(str_disp_a),
                         .str_b(str_disp_b),
                         .str_rob(str_rob) );

    func_unit_load fu_load(.clk(clk),
                           .rst(rst),
                           .load_fwd_a(load_fwd_a),
                           .load_fwd_b(load_fwd_b),
                           .load_mem(),
                           .load_imm(),
                           .mem_rd_data(),
                           .mem_rd_addr(),
                           .fwd_addrs(load_fwd_addrs),
                           .load_mem_op(),
                           .load_imm_op() ); */

    common_data_bus cdb(.int_a(int_cdb_a),
                        .int_b(int_cdb_b),
                        .imm_a(imm_cdb_a),
                        .imm_b(imm_cdb_b),
                        .load_a(),
                        .load_b(),
                        .cdb_arr(cdb_arr) );
endmodule