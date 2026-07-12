`timescale 1ns / 1ps

import config_pkg::*;

module int_processor(
    input clk, 
    input rst,

    output [3:0] reg_op
);
    // Program Counter
    logic [ADDRBUS_SIZE - 1:0] pc_next, pc_out;

    // Fetch
    instruction instr_a, instr_b;

    // Rename
    rs_entry rename_a, rename_b;
    rob_entry rob_a, rob_b;

    // Dispatch
    rs_entry rs_dp_a [0:3], rs_dp_b [0:3];
    rob_entry rob_dp_a, rob_dp_b;

    // Reservation station outputs
    int_rs_entry int_rs_out;
    imm_rs_entry imm_rs_out;

    // Functional unit outputs
    cdb_entry int_cdb;
    cdb_entry imm_cdb;

    // CDB broadcast
    cdb_entry cdb_arr [0:CDB_SIZE-1];

    // ROB outputs
    rob_entry rob_out_arr [0:1];
    id_to_free ids_to_free [0:1];

    assign pc_next = pc_out + ADDRBUS_SIZE'(2);

    program_counter pc(.clk(clk),
                       .write_enable(~rst),
                       .ip_addr(pc_next),
                       .op_addr(pc_out) );

    instruction_memory instr_mem(.clk(clk),
                                 .ip_addr(pc_out),
                                 .instr_a(instr_a),
                                 .instr_b(instr_b) );

    register_file rf(.clk(clk),
                     .rst(rst),
                     .instr_a(instr_a),
                     .instr_b(instr_b),
                     .cdb_arr(cdb_arr),
                     .commit_arr(rob_out_arr),
                     .rs_a_op(rename_a),
                     .rs_b_op(rename_b),
                     .rob_a_op(rob_a),
                     .rob_b_op(rob_b),
                     .last_arch_reg(reg_op) );

    rename_dispatch_pl dp_pl(.clk(clk),
                             .rst(rst),
                             .rename_a(rename_a),
                             .rename_b(rename_b),
                             .rob_a(rob_a),
                             .rob_b(rob_b),
                             .ids_to_free(ids_to_free),
                             .rs_op_a(rs_dp_a),
                             .rs_op_b(rs_dp_b),
                             .rob_op_a(rob_dp_a),
                             .rob_op_b(rob_dp_b) );

    res_station_int rs_int(.clk(clk),
                           .rst(rst),
                           .instr_a(rs_dp_a[0]),
                           .instr_b(rs_dp_b[0]),
                           .cdb_arr(cdb_arr),
                           .instr_op(int_rs_out),
                           .almost_full() );

    res_station_imm rs_imm(.clk(clk),
                           .rst(rst),
                           .instr_a(rs_dp_a[1]),
                           .instr_b(rs_dp_b[1]),
                           .cdb_arr(cdb_arr),
                           .instr_op(imm_rs_out),
                           .almost_full() );

    func_unit_int fu_int(.clk(clk),
                         .rst(rst),
                         .int_instr(int_rs_out),
                         .cdb_result(int_cdb) );

    func_unit_imm fu_imm(.clk(clk),
                         .rst(rst),
                         .imm_instr(imm_rs_out),
                         .cdb_result(imm_cdb) );

    common_data_bus cdb(.int_res(int_cdb),
                        .imm_res(imm_cdb),
                        .load_res('0),
                        .cdb_arr(cdb_arr) );

    reorder_buffer rob(.clk(clk),
                       .rst(rst),
                       .input_a(rob_dp_a),
                       .input_b(rob_dp_b),
                       .cdb_arr(cdb_arr),
                       .str_rob(),
                       .output_arr(rob_out_arr),
                       .ids_to_free(ids_to_free) );
endmodule
