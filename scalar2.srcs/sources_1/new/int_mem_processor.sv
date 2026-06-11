`timescale 1ns / 1ps

import config_pkg::*;

module int_mem_processor(clk, rst, amount_executed);
    input logic clk, rst;
    output logic [0:3] amount_executed;

    // Program Counter
    logic [ADDRBUS_SIZE-1:0] pc_next, pc_out;
    assign pc_next = pc_out + ADDRBUS_SIZE'(2);

    // Fetch
    instruction instr_a, instr_b;

    // Rename
    rs_entry rename_a, rename_b;
    rob_entry rob_a, rob_b;

    // Dispatch
    rs_entry rs_op_a [0:3], rs_op_b [0:3];
    rob_entry rob_op_a, rob_op_b;
    assign rs_op_a[3] = '0;
    assign rs_op_b[3] = '0;

    // Reservation station outputs
    int_rs_entry int_rs_out_a, int_rs_out_b;
    imm_rs_entry imm_rs_out_a, imm_rs_out_b;
    store_rs_entry str_a, str_b;
    load_rs_entry load_to_fu_a, load_to_fu_b;
    load_rs_entry load_disp_mem, load_disp_imm;

    str_rob_entry str_rob [0:1];
    load_fwd_addr load_fwd_addrs [0:1];

    logic [0:DATABUS_WIDTH - 1] mem_rd_data;
	logic [ADDRBUS_SIZE-1:0] mem_rd_addr;
    logic [0:5] mem_str_to_free;

    // Functional unit outputs
    cdb_entry int_cdb_a, int_cdb_b;
    cdb_entry imm_cdb_a, imm_cdb_b;
    cdb_entry load_mem_cdb, load_imm_cdb;

    // CDB output
    cdb_entry cdb_arr [0:CDB_SIZE - 1];

    // ROB outputs
    rob_entry rob_out_arr [0:1];
    logic [0:5] id_to_free [0:1];

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

    res_station_mem rs_mem(.clk(clk),
                           .rst(rst),
                           .instr_a(rs_op_a[2]),
                           .instr_b(rs_op_b[2]),
                           .cdb_arr(cdb_arr),
                           .id_to_free(id_to_free),
                           .str_fwd_vals(str_rob),
                           .load_fwd_addrs(load_fwd_addrs),
                           .str_op_a(str_a),
                           .str_op_b(str_b),
                           .load_to_fu_a(load_to_fu_a),
                           .load_to_fu_b(load_to_fu_b),
                           .load_disp_mem(load_disp_mem),
                           .load_disp_imm(load_disp_imm) );

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

    func_unit_str fu_str(.clk(clk),
                         .rst(rst),
                         .str_a(str_a),
                         .str_b(str_b),
                         .str_rob(str_rob) );

    func_unit_load fu_load(.clk(clk),
                           .rst(rst),
                           .load_fwd_a(load_to_fu_a),
                           .load_fwd_b(load_to_fu_b),
                           .load_mem(load_disp_mem),
                           .load_imm(load_disp_imm),
                           .mem_rd_data(mem_rd_data),
                           .fwd_addrs(load_fwd_addrs),
                           .load_mem_op(load_mem_cdb),
                           .load_imm_op(load_imm_cdb),
                           .mem_rd_addr(mem_rd_addr) );

    common_data_bus cdb(.int_a(int_cdb_a),
                        .int_b(int_cdb_b),
                        .imm_a(imm_cdb_a),
                        .imm_b(imm_cdb_b),
                        .load_a(load_mem_cdb),
                        .load_b(load_imm_cdb),
                        .cdb_arr(cdb_arr) );

    reorder_buffer rob(.clk(clk),
                       .rst(rst),
                       .input_a(rob_op_a),
                       .input_b(rob_op_b),
                       .cdb_arr(cdb_arr),
                       .str_rob(str_rob),
                       .output_arr(rob_out_arr),
                       .id_to_free(id_to_free),
                       .amount_executed(amount_executed) );

    data_memory mem(.clk(clk),
                    .rst(rst),
                    .commit_arr(rob_out_arr),
                    .read_addr(mem_rd_addr),
                    .read_data(mem_rd_data) );
    
endmodule