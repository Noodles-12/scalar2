`timescale 1ns / 1ps

module scalar2_top(
    input logic clk,
    input logic rst,

    output logic [3:0] last_arch_reg
);
    logic [ADDRBUS_SIZE-1:0] pc_addr;
    logic [ADDRBUS_SIZE-1:0] next_pc;

    logic predict_flush;
    logic mispredict_flush_rob, mispredict_flush_rs, mispredict_flush_reg;
    logic pipe_enable;

    logic rs_int_full, rs_imm_full, rs_branch_full, rs_mem_full;
    logic rob_almost_full, reg_file_almost_full;

    instruction instr_a, instr_b;
    logic [ADDRBUS_SIZE-1:0] addr_a, addr_b;

    instruction bp_instr_a, bp_instr_b;
    logic [ADDRBUS_SIZE-1:0] bp_addr_a, bp_addr_b;

    instruction mod_instr_a, mod_instr_b;
    logic [ADDRBUS_SIZE-1:0] predict_a, predict_b;
    logic [ADDRBUS_SIZE-1:0] recov_a, recov_b;
    logic [4:0] hist_a, hist_b;
    logic [1:0] imm_lo_a, imm_lo_b;

    // Dependency Resolver
    instruction instr_a_rslv, instr_b_rslv;
    logic [ADDRBUS_SIZE-1:0] recov_a_rslv, recov_b_rslv;
    logic [4:0] hist_a_rslv, hist_b_rslv;
    logic [1:0] imm_lo_a_rslv, imm_lo_b_rslv;

    // Rename
    rs_entry rs_a, rs_b;
    rob_entry rob_a, rob_b;

    // Dispatch
    rs_entry rs_disp_a [0:3], rs_disp_b [0:3];
    rob_entry rob_disp_a, rob_disp_b;

    // Reservation station outputs
    int_rs_entry int_rs_out_a, int_rs_out_b;
    imm_rs_entry imm_rs_out_a, imm_rs_out_b;
    branch_rs_entry branch_rs_out_a, branch_rs_out_b;
    str_disp_entry str_rs_out_a, str_rs_out_b;

    load_fwd_addr load_fwd_rs;
    load_disp_entry load_disp_rs_a, load_disp_rs_b;

    // Functional unit outputs
    cdb_entry int_cdb_a, int_cdb_b;
    cdb_entry imm_cdb_a, imm_cdb_b;
    cdb_entry load_cdb_a, load_cdb_b;

    str_disp_entry str_fu_out_a, str_fu_out_b;
    branch_disp_entry branch_disp_a, branch_disp_b;

    load_fwd_addr load_fwd_fu;
    logic [ADDRBUS_SIZE-1:0] read_addr_a, read_addr_b;
    logic [DATABUS_WIDTH-1:0] read_data_a, read_data_b;


    // CDB broadcast
    cdb_entry cdb_arr [0:CDB_SIZE-1];

    // ROB
    rob_entry rob_out_arr [0:1];

    // Commit
    logic commit_misp;
    logic [ADDRBUS_SIZE-1:0] commit_misp_addr;
    rob_entry commit_a, commit_b;

    program_counter pc(
        .clk(clk),
        .rst(rst),
        .enable(pipe_enable),
        .ip_addr(next_pc),

        .op_addr(pc_addr)
    );

    controller ctrl(
        .clk(clk),
        .code_a(mod_instr_a.code),
        .code_b(mod_instr_b.code),
        .target_a(predict_a),
        .target_b(predict_b),
        .curr_pc(pc_addr),
        .mispredict_signal(commit_misp),
        .recov_addr(commit_misp_addr),

        .rs_int_full(rs_int_full),
        .rs_imm_full(rs_imm_full),
        .rs_branch_full(rs_branch_full),
        .rs_mem_full(rs_mem_full),
        .rob_full(rob_almost_full),
        .reg_file_full(reg_file_almost_full),

        .predict_flush(predict_flush),
        .mispredict_flush_rob(mispredict_flush_rob),
        .mispredict_flush_rs(mispredict_flush_rs),
        .mispredict_flush_reg(mispredict_flush_reg),
        .next_pc(next_pc),
        .enable(pipe_enable)
    );

    instruction_memory instr_mem(
        .clk(clk),
        .rst(rst),
        .ip_addr(pc_addr),
        .predict_flush(predict_flush),
        .mispredict_flush(mispredict_flush_rob),
        .enable(pipe_enable),

        .instr_a(instr_a),
        .instr_b(instr_b),
        .instr_a_addr(addr_a),
        .instr_b_addr(addr_b)
    );

    branch_predictor bp(
        .clk(clk),
        .rst(rst),
        .predict_flush(predict_flush),
        .mispredict_flush(mispredict_flush_rob),
        .enable(pipe_enable),
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
        .hist_b(hist_b),
        .imm_lo_a(imm_lo_a),
        .imm_lo_b(imm_lo_b)
    );

    dependency_resolver dep_rsvr(
        .clk(clk),
        .rst(rst),
        .mispredict_flush(mispredict_flush_rob),
        .enable(pipe_enable),
        .instr_a(mod_instr_a),
        .instr_b(mod_instr_b),
        .recov_a(recov_a),
        .recov_b(recov_b),
        .hist_a(hist_a),
        .hist_b(hist_b),
        .imm_lo_a(imm_lo_a),
        .imm_lo_b(imm_lo_b),

        .instr_a_op(instr_a_rslv),
        .instr_b_op(instr_b_rslv),
        .recov_addr_a(recov_a_rslv),
        .recov_addr_b(recov_b_rslv),
        .hist_a_op(hist_a_rslv),
        .hist_b_op(hist_b_rslv),
        .imm_lo_a_op(imm_lo_a_rslv),
        .imm_lo_b_op(imm_lo_b_rslv)
    );

    register_file rf(
        .clk(clk),
        .rst(rst),
        .mispredict_signal(mispredict_flush_reg),
        .enable(pipe_enable),
        .instr_a(instr_a_rslv),
        .instr_b(instr_b_rslv),
        .recov_a(recov_a_rslv),
        .recov_b(recov_b_rslv),
        .hist_a(hist_a_rslv),
        .hist_b(hist_b_rslv),
        .imm_lo_a(imm_lo_a_rslv),
        .imm_lo_b(imm_lo_b_rslv),
        .cdb_arr(cdb_arr),
        .commit_a(commit_a),
        .commit_b(commit_b),

        .rs_a_op(rs_a),
        .rs_b_op(rs_b),
        .rob_a_op(rob_a),
        .rob_b_op(rob_b),
        .last_arch_reg(last_arch_reg),
        .almost_full(reg_file_almost_full)
    );

    dispatch_pl disp_pl(
        .clk(clk),
        .rst(rst),
        .mispredict_signal(mispredict_flush_reg),
        .enable(pipe_enable),
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

    res_station_int rs_int(
        .clk(clk),
        .rst(rst),
        .mispredict_signal(mispredict_flush_rs),
        .enable(pipe_enable),
        .instr_a(rs_disp_a[0].int_rs),
        .instr_b(rs_disp_b[0].int_rs),
        .cdb_arr(cdb_arr),

        .instr_op_a(int_rs_out_a),
        .instr_op_b(int_rs_out_b),
        .almost_full(rs_int_full)
    );

    res_station_imm rs_imm(
        .clk(clk),
        .rst(rst),
        .mispredict_signal(mispredict_flush_rs),
        .enable(pipe_enable),
        .instr_a(rs_disp_a[1].imm_rs),
        .instr_b(rs_disp_b[1].imm_rs),
        .cdb_arr(cdb_arr),

        .instr_op_a(imm_rs_out_a),
        .instr_op_b(imm_rs_out_b),
        .almost_full(rs_imm_full)
    );

    res_station_mem rs_mem(
        .clk(clk),
        .rst(rst),
        .mispredict_signal(mispredict_flush_rs),
        .enable(pipe_enable),
        .instr_a(rs_disp_a[2]),
        .instr_b(rs_disp_b[2]),
        .cdb_arr(cdb_arr),
        .free_id_a(commit_a),
        .free_id_b(commit_b),
        .str_fwd_val_a(str_fu_out_a),
        .str_fwd_val_b(str_fu_out_b),
        .load_fwd_ip(load_fwd_fu),

        .str_disp_op_a(str_rs_out_a),
        .str_disp_op_b(str_rs_out_b),
        .load_fwd_op(load_fwd_rs),
        .load_disp_op_a(load_disp_rs_a),
        .load_disp_op_b(load_disp_rs_b),
        .almost_full(rs_mem_full)
    );

    res_station_branch rs_branch(
        .clk(clk),
        .rst(rst),
        .mispredict_signal(mispredict_flush_rs),
        .enable(pipe_enable),
        .instr_a(rs_disp_a[3].branch_rs),
        .instr_b(rs_disp_b[3].branch_rs),
        .cdb_arr(cdb_arr),

        .instr_op_a(branch_rs_out_a),
        .instr_op_b(branch_rs_out_b),
        .almost_full(rs_branch_full)
    );

    func_unit_int fu_int(
        .clk(clk),
        .rst(rst),
        .mispredict_signal(mispredict_flush_rs),
        .int_instr_a(int_rs_out_a),
        .int_instr_b(int_rs_out_b),

        .cdb_result_a(int_cdb_a),
        .cdb_result_b(int_cdb_b)
    );

    func_unit_imm fu_imm(
        .clk(clk),
        .rst(rst),
        .mispredict_signal(mispredict_flush_rs),
        .imm_instr_a(imm_rs_out_a),
        .imm_instr_b(imm_rs_out_b),

        .cdb_result_a(imm_cdb_a),
        .cdb_result_b(imm_cdb_b)
    );

    func_unit_branch fu_branch(
        .clk(clk),
        .rst(rst),
        .mispredict_signal(mispredict_flush_rs),
        .branch_instr_a(branch_rs_out_a),
        .branch_instr_b(branch_rs_out_b),

        .result_op_a(branch_disp_a),
        .result_op_b(branch_disp_b)
    );

    func_unit_str fu_str(
        .clk(clk),
        .rst(rst),
        .str_op_a(str_rs_out_a),
        .str_op_b(str_rs_out_b),

        .str_rob_a(str_fu_out_a),
        .str_rob_b(str_fu_out_b)
    );

    func_unit_load fu_load(
        .clk(clk),
        .rst(rst),
        .mispredict_signal(mispredict_flush_rs),
        .load_entry(load_fwd_rs),
        .load_disp_ip_a(load_disp_rs_a),
        .load_disp_ip_b(load_disp_rs_b),

        .mem_rd_data_a(read_data_a),
        .mem_rd_data_b(read_data_b),
        .mem_rd_addr_a(read_addr_a),
        .mem_rd_addr_b(read_addr_b),

        .fwd_load_addr(load_fwd_fu),
        .load_cdb_a(load_cdb_a),
        .load_cdb_b(load_cdb_b)
    );

    common_data_bus cdb(
        .int_res_a(int_cdb_a),
        .int_res_b(int_cdb_b),
        .imm_res_a(imm_cdb_a),
        .imm_res_b(imm_cdb_b),
        .load_res_a(load_cdb_a),
        .load_res_b(load_cdb_b),

        .cdb_arr(cdb_arr)
    );

    reorder_buffer rob(
        .clk(clk),
        .rst(rst),
        .mispredict_signal(mispredict_flush_rob),
        .input_a(rob_disp_a),
        .input_b(rob_disp_b),
        .cdb_arr(cdb_arr),
        .str_rob_a(str_fu_out_a),
        .str_rob_b(str_fu_out_b),
        .branch_rob_a(branch_disp_a),
        .branch_rob_b(branch_disp_b),

        .output_arr(rob_out_arr),
        .almost_full(rob_almost_full)
    );

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

    data_memory data_mem(
        .clk(clk),
        .rst(rst),
        .commit_a(commit_a),
        .commit_b(commit_b),
        .read_addr_a(read_addr_a),
        .read_addr_b(read_addr_b),

        .read_data_a(read_data_a),
        .read_data_b(read_data_b)
    );
endmodule
