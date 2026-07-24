`timescale 1ns / 1ps

module int_branch_processor(
    input logic clk,
    input logic rst,

    output logic [3:0] last_arch_reg
);
    logic [ADDRBUS_SIZE-1:0] pc_addr;
    logic [ADDRBUS_SIZE-1:0] next_pc;

    logic predict_flush, mispredict_flush;

    instruction instr_a, instr_b;
    logic [ADDRBUS_SIZE-1:0] addr_a, addr_b;

    instruction mod_instr_a, mod_instr_b;
    logic [ADDRBUS_SIZE-1:0] predict_a, predict_b;
    logic [ADDRBUS_SIZE-1:0] recov_a, recov_b;
    logic [4:0] hist_a, hist_b;

    // Dependency Resolver
    instruction instr_a_rslv, instr_b_rslv;
    logic [ADDRBUS_SIZE-1:0] recov_a_rslv, recov_b_rslv;
    logic [4:0] hist_a_rslv, hist_b_rslv;

    // Rename
    rs_entry rs_a, rs_b;
    rob_entry rob_a, rob_b;

    // Dispatch
    rs_entry rs_disp_a [0:3], rs_disp_b [0:3];
    rob_entry rob_disp_a, rob_disp_b;

    // Reservation station outputs
    int_rs_entry int_rs_out;
    imm_rs_entry imm_rs_out;
    branch_rs_entry branch_rs_out;

    // Functional unit outputs
    cdb_entry int_cdb;
    cdb_entry imm_cdb;

    // CDB broadcast
    cdb_entry cdb_arr [0:CDB_SIZE-1];
    branch_disp_entry branch_disp;

    // ROB
    rob_entry rob_out_arr [0:1];

    // Commit
    logic commit_misp;
    logic [ADDRBUS_SIZE-1:0] commit_misp_addr;
    rob_entry commit_a, commit_b;

    program_counter pc(
        .clk(clk),
        .rst(rst),
        .enable(1'b1),
        .ip_addr(next_pc),
        
        .op_addr(pc_addr)
    );

    controller ctrl(
        .code_a(mod_instr_a.code),
        .code_b(mod_instr_b.code),
        .target_a(predict_a),
        .target_b(predict_b),
        .curr_pc(pc_addr),
        .mispredict_signal(commit_misp),
        .recov_addr(commit_misp_addr),

        .predict_flush(predict_flush),
        .mispredict_flush(mispredict_flush),
        .next_pc(next_pc),
        .enable()
    );

    instruction_memory instr_mem(
        .clk(clk),
        .rst(rst),
        .ip_addr(pc_addr),
        .predict_flush(predict_flush),
        .mispredict_flush(mispredict_flush),

        .instr_a(instr_a),
        .instr_b(instr_b),
        .instr_a_addr(addr_a),
        .instr_b_addr(addr_b)
    );

    branch_predictor bp(
        .clk(clk),
        .rst(rst),
        .predict_flush(predict_flush),
        .mispredict_flush(mispredict_flush),
        .enable(1'b1),
        .instr_a(instr_a),
        .addr_a(addr_a),
        .instr_b(instr_b),
        .addr_b(addr_b),
        .commit_a(commit_a),
        .commit_b(commit_b),

        .instr_a_op(mod_instr_a),
        .instr_b_op(mod_instr_b),
        .predict_addr_a(predict_a),
        .predict_addr_b(predict_b),
        .recov_addr_a(recov_a),
        .recov_addr_b(recov_b),
        .hist_a(hist_a),
        .hist_b(hist_b)
    );

    dependency_resolver dep_rsvr(
        .clk(clk),
        .rst(rst),
        .mispredict_flush(mispredict_flush),
        .enable(1'b1),
        .instr_a(mod_instr_a),
        .instr_b(mod_instr_b),
        .recov_a(recov_a),
        .recov_b(recov_b),
        .hist_a(hist_a),
        .hist_b(hist_b),

        .instr_a_op(instr_a_rslv),
        .instr_b_op(instr_b_rslv),
        .recov_addr_a(recov_a_rslv),
        .recov_addr_b(recov_b_rslv),
        .hist_a_op(hist_a_rslv),
        .hist_b_op(hist_b_rslv)
    );

    register_file rf(
        .clk(clk),
        .rst(rst),
        .mispredict_signal(mispredict_flush),
        .instr_a(instr_a_rslv),
        .instr_b(instr_b_rslv),
        .recov_a(recov_a_rslv),
        .recov_b(recov_b_rslv),
        .hist_a(hist_a_rslv),
        .hist_b(hist_b_rslv),
        .cdb_arr(cdb_arr),
        .commit_a(commit_a),
        .commit_b(commit_b),

        .rs_a_op(rs_a),
        .rs_b_op(rs_b),
        .rob_a_op(rob_a),
        .rob_b_op(rob_b),
        .last_arch_reg(last_arch_reg)
    );

    dispatch_pl disp_pl(
        .clk(clk),
        .rst(rst),
        .mispredict_signal(mispredict_flush),
        .rename_a(rs_a),
        .rename_b(rs_b),
        .rob_a(rob_a),
        .rob_b(rob_b),
        .commit_a(commit_a),
        .commit_b(commit_b),
        .cdb_arr(cdb_arr),

        .rs_op_a(rs_disp_a),
        .rs_op_b(rs_disp_b),
        .rob_op_a(rob_disp_a),
        .rob_op_b(rob_disp_b)
    );

    res_station_int rs_int(.clk(clk),
                           .rst(rst),
                           .mispredict_signal(mispredict_flush),
                           .instr_a(rs_disp_a[0].int_rs),
                           .instr_b(rs_disp_b[0].int_rs),
                           .cdb_arr(cdb_arr),

                           .instr_op(int_rs_out),
                           .almost_full() );

    res_station_imm rs_imm(.clk(clk),
                           .rst(rst),
                           .mispredict_signal(mispredict_flush),
                           .instr_a(rs_disp_a[1].imm_rs),
                           .instr_b(rs_disp_b[1].imm_rs),
                           .cdb_arr(cdb_arr),

                           .instr_op(imm_rs_out),
                           .almost_full() );

    res_station_branch rs_branch(.clk(clk),
                                 .rst(rst),
                                 .mispredict_signal(mispredict_flush),
                                 .instr_a(rs_disp_a[3].branch_rs),
                                 .instr_b(rs_disp_b[3].branch_rs),
                                 .cdb_arr(cdb_arr),

                                 .instr_op(branch_rs_out),
                                 .almost_full() );

    func_unit_int fu_int(.clk(clk),
                         .rst(rst),
                         .mispredict_signal(mispredict_flush),
                         .int_instr(int_rs_out),

                         .cdb_result(int_cdb) );

    func_unit_imm fu_imm(.clk(clk),
                         .rst(rst),
                         .mispredict_signal(mispredict_flush),
                         .imm_instr(imm_rs_out),

                         .cdb_result(imm_cdb) );

    func_unit_branch fu_branch(.clk(clk),
                               .rst(rst),
                               .mispredict_signal(mispredict_flush),
                               .branch_instr(branch_rs_out),

                               .result_op(branch_disp) );

    common_data_bus cdb(.int_res(int_cdb),
                        .imm_res(imm_cdb),
                        .load_res('0),

                        .cdb_arr(cdb_arr) );

    reorder_buffer rob(.clk(clk),
                       .rst(rst),
                       .mispredict_signal(mispredict_flush),
                       .input_a(rob_disp_a),
                       .input_b(rob_disp_b),
                       .cdb_arr(cdb_arr),
                       .str_rob(),
                       .branch_rob(branch_disp),

                       .output_arr(rob_out_arr),
                       .ids_to_free() );

    commit_pl commit(
        .clk(clk),
        .rst(rst),
        .rob_a(rob_out_arr[0]),
        .rob_b(rob_out_arr[1]),

        .mispredict_signal(commit_misp),
        .mispredict_pc(commit_misp_addr),
        .commit_a(commit_a),
        .commit_b(commit_b)
    );
endmodule
