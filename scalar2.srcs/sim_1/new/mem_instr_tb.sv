`timescale 1ns / 1ps

import config_pkg::*;

module mem_instr_tb();
    logic clk, rst;
    instruction instr_a, instr_b;

    rs_entry rename_a, rename_b;
    rob_entry rob_a, rob_b;
    
    rs_entry rs_entry_a [0:3], rs_entry_b [0:3];
    rob_entry rob_entry_a, rob_entry_b;

    store_rs_entry str_a, str_b;
    load_rs_entry load_to_fu_a, load_to_fu_b;

    str_rob_entry str_rob [0:1];
    load_fwd_addr load_fwd_addrs [0:1];

    logic [0:DATABUS_WIDTH - 1] mem_rd_data;
	logic [ADDRBUS_SIZE-1:0] mem_rd_addr;

    load_rs_entry load_disp_mem, load_disp_imm;
    cdb_entry load_mem_cdb, load_imm_cdb;
    
    rob_entry output_rob [0:1];

    logic [0:5] id_to_free [0:1];

    cdb_entry cdb_arr [0:CDB_SIZE - 1];

    logic [0:3] amount_executed;

    reg_file rf(.clk(clk),
                .rst(rst),
                .og_instr_a(instr_a),
                .og_instr_b(instr_b),
                .cdb_arr(cdb_arr),
                .commit_arr(output_rob),
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
                             .id_to_free(id_to_free),
                             .rs_op_a(rs_entry_a),
                             .rs_op_b(rs_entry_b),
                             .rob_op_a(rob_entry_a),
                             .rob_op_b(rob_entry_b) );

    reorder_buffer rob(.clk(clk),
                       .rst(rst),
                       .input_a(rob_entry_a),
                       .input_b(rob_entry_b),
                       .cdb_arr(cdb_arr),
                       .str_rob(str_rob),
                       .output_arr(output_rob),
                       .id_to_free(id_to_free),
                       .amount_executed(amount_executed) );

    res_station_mem rs_mem(.clk(clk),
                           .rst(rst),
                           .instr_a(rs_entry_a[2]),
                           .instr_b(rs_entry_b[2]),
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

    func_unit_str str_fu(.clk(clk),
                         .rst(rst),
                         .str_a(str_a),
                         .str_b(str_b),
                         .str_rob(str_rob) );

    func_unit_load load_fu(.clk(clk),
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

    common_data_bus cdb(.int_a('0),
                        .int_b('0),
                        .imm_a('0),
                        .imm_b('0),
                        .load_a(load_mem_cdb),
                        .load_b(load_imm_cdb),
                        .cdb_arr(cdb_arr) );

    data_memory mem(.clk(clk),
                    .rst(rst),
                    .commit_arr(output_rob), 
                    .read_addr(mem_rd_addr),
                    .read_data(mem_rd_data) );

    always #5 clk = ~clk;

    initial begin
        clk = 0; rst = 1;
        #10 rst = 0;

        instr_a = 30'b011100_0010_0000_0000_000000000100;
        instr_b = 30'b011101_0010_0011_0000_000000001000;
        #10;

        instr_a = 0; instr_b = 0;
        #150;

        $finish;
    end
endmodule
