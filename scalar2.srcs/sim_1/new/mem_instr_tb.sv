`timescale 1ns / 1ps

import config_pkg::*;

module mem_instr_tb();
    logic clk, rst;

    instruction instr_a, instr_b;
    logic [11:0] recov_a, recov_b;
    logic [4:0] hist_a, hist_b;

    cdb_entry cdb_arr [0:CDB_SIZE-1];
    rob_entry commit_a, commit_b;

    rs_entry rs_a, rs_b;
    rob_entry rob_a, rob_b;

    rs_entry rs_disp_a [0:3], rs_disp_b [0:3];
    rob_entry rob_disp_a, rob_disp_b;

    logic [5:0] id_to_free [0:1];

    load_fwd_addr load_fwd_addrs [0:1];

    str_disp_entry str_disp_op;
    str_disp_entry str_rob;
    load_fwd_addr load_fwd_a_reg, load_fwd_b_reg;
    load_rs_entry load_disp_mem, load_disp_imm;

    register_file rf(
        .clk(clk),
        .rst(rst),
        .mispredict_signal(1'b0),
        .instr_a(instr_a),
        .instr_b(instr_b),
        .recov_a(recov_a),
        .recov_b(recov_b),
        .hist_a(hist_a),
        .hist_b(hist_b),
        .cdb_arr(cdb_arr),
        .commit_a(commit_a),
        .commit_b(commit_b),

        .rs_a_op(rs_a),
        .rs_b_op(rs_b),
        .rob_a_op(rob_a),
        .rob_b_op(rob_b),
        .last_arch_reg()
    );

    dispatch_pl disp_pl(
        .clk(clk),
        .rst(rst),
        .mispredict_signal(1'b0),
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

    res_station_mem rs_mem(
        .clk(clk),
        .rst(rst),
        .mispredict_signal(1'b0),
        .instr_a(rs_disp_a[2]),
        .instr_b(rs_disp_b[2]),
        .cdb_arr(cdb_arr),
        .id_to_free(id_to_free),

        .str_fwd_val(str_rob),
        .load_fwd_addrs(load_fwd_addrs),

        .str_disp_op(str_disp_op),

        .load_fwd_a_reg(load_fwd_a_reg),
        .load_fwd_b_reg(load_fwd_b_reg),

        .load_disp_mem(load_disp_mem),
        .load_disp_imm(load_disp_imm)
    );

    func_unit_str fu_str(
        .clk(clk),
        .rst(rst),
        .str_op(str_disp_op),
        .str_rob(str_rob)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0; rst = 1;
        recov_a = '0; recov_b = '0;
        hist_a = '0; hist_b = '0;
        cdb_arr = '{default: '0};
        commit_a = '0; commit_b = '0;
        id_to_free = '{default: '0};
        load_fwd_addrs = '{default: '0};
        instr_a = '0; instr_b = '0;

        #10;
        rst = 0;

        instr_a = '{opcode: 26, reg_d: 4'd1, reg_s: 4'd2, reg_t: 4'd0, imm: 12'd4, code: NORMAL};
        instr_b = '{opcode: 27, reg_d: 4'd2, reg_s: 4'd3, reg_t: 4'd0, imm: 12'd8, code: NORMAL};
        #10;

        instr_a = '0; instr_b = '0;
        #40;

        $display("load_buffer[0]: valid=%0b opcode=%0d reg_s=%0d offset=%0d dest=%0d",
            rs_mem.load_buffer[0].valid, rs_mem.load_buffer[0].opcode,
            rs_mem.load_buffer[0].reg_s, rs_mem.load_buffer[0].offset,
            rs_mem.load_buffer[0].dest);

        $display("store_buffer[0]: valid=%0b opcode=%0d reg_s=%0d reg_d=%0d offset=%0d check_s=%0b check_d=%0b",
            rs_mem.store_buffer[0].valid, rs_mem.store_buffer[0].opcode,
            rs_mem.store_buffer[0].reg_s, rs_mem.store_buffer[0].reg_d,
            rs_mem.store_buffer[0].offset,
            rs_mem.store_buffer[0].check_s, rs_mem.store_buffer[0].check_d);

        // Store dispatch check: sources were ready at rename (fresh regs),
        // so the store should be selected and appear on str_disp_op
        $display("str_disp_op: valid=%0b id=%0d idx=%0d base_val=%0d offset=%0d value=%0d",
            str_disp_op.valid, str_disp_op.id, str_disp_op.idx,
            str_disp_op.base_val, str_disp_op.offset, str_disp_op.value);

        if (str_disp_op.valid && str_disp_op.idx == 0
            && str_disp_op.offset == 12'd8
            && str_disp_op.base_val == 12'd0
            && str_disp_op.value == 32'd0)
            $display("PASS: store dispatched from res_station_mem");
        else
            $display("FAIL: store not dispatched or fields wrong");

        // Store FU check: one cycle after dispatch the store should come out
        // of func_unit_str with mem_dest = base_val + offset
        #10;

        $display("str_rob: valid=%0b id=%0d idx=%0d mem_dest=%0d value=%0d",
            str_rob.valid, str_rob.id, str_rob.idx,
            str_rob.mem_dest, str_rob.value);

        if (str_rob.valid && str_rob.idx == 0
            && str_rob.mem_dest == 12'd8
            && str_rob.value == 32'd0)
            $display("PASS: store went through func_unit_str");
        else
            $display("FAIL: store missing or wrong at func_unit_str output");

        // Forwarding check: str_rob feeds back into str_fwd_val, so one cycle
        // later the RS should have latched the effective address for entry 0
        #10;

        $display("store_eff_addr[0]=%0d store_valid_addr[0]=%0b",
            rs_mem.store_eff_addr[0], rs_mem.store_valid_addr[0]);

        if (rs_mem.store_valid_addr[0] && rs_mem.store_eff_addr[0] == 12'd8)
            $display("PASS: effective address forwarded back into RS");
        else
            $display("FAIL: effective address not stored in RS");

        #90;

        $finish;
    end
endmodule
