`timescale 1ns / 1ps

import config_pkg::*;

/*
    The main point of this testbench is to see that our ROB is filled with the right instructions
        (assuming right predicts) & that all of them are completed/passed to commit (as of 07/13/26 commit_pl not created)
*/

module predict_tb();
    logic clk, rst;

    logic [ADDRBUS_SIZE-1:0] pc_addr;
    logic [ADDRBUS_SIZE-1:0] next_pc;

    logic predict_flush, mispredict_flush;
    logic [ADDRBUS_SIZE-1:0] mispredict_addr;

    instruction instr_a, instr_b;
    logic [ADDRBUS_SIZE-1:0] addr_a, addr_b;

    instruction mod_instr_a, mod_instr_b;
    logic [ADDRBUS_SIZE-1:0] predict_a, predict_b;
    logic [ADDRBUS_SIZE-1:0] recov_a, recov_b;
    logic [4:0] hist_a, hist_b;

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
    id_to_free ids_to_free [0:1];

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
        .mispredict_signal(1'b0),
        .recov_addr(mispredict_addr),

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
        .instr_a(instr_a),
        .addr_a(addr_a),
        .instr_b(instr_b),
        .addr_b(addr_b),
        .predict_flush(predict_flush),
        .mispredict_flush(mispredict_flush),
        .enable(1'b1),

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
        .instr_a(mod_instr_a),
        .instr_b(mod_instr_b),
        .recov_a(recov_a),
        .recov_b(recov_b),
        .hist_a(hist_a),
        .hist_b(hist_b),
        .mispredict_flush(mispredict_flush),
        .enable(1'b1),

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
        .instr_a(instr_a_rslv),
        .instr_b(instr_b_rslv),
        .recov_a(recov_a_rslv),
        .recov_b(recov_b_rslv),
        .hist_a(hist_a_rslv),
        .hist_b(hist_b_rslv),
        .cdb_arr(cdb_arr),
        .commit_arr(),

        .rs_a_op(rs_a),
        .rs_b_op(rs_b),
        .rob_a_op(rob_a),
        .rob_b_op(rob_b),
        .last_arch_reg()
    );

    dispatch_pl disp_pl(
        .clk(clk),
        .rst(rst),
        .rename_a(rs_a),
        .rename_b(rs_b),
        .rob_a(rob_a),
        .rob_b(rob_b),
        .ids_to_free(),
        .cdb_arr(cdb_arr),

        .rs_op_a(rs_disp_a),
        .rs_op_b(rs_disp_b),
        .rob_op_a(rob_disp_a),
        .rob_op_b(rob_disp_b)
    );

    res_station_int rs_int(.clk(clk),
                           .rst(rst),
                           .instr_a(rs_disp_a[0].int_rs),
                           .instr_b(rs_disp_b[0].int_rs),
                           .cdb_arr(cdb_arr),

                           .instr_op(int_rs_out),
                           .almost_full() );

    res_station_imm rs_imm(.clk(clk),
                           .rst(rst),
                           .instr_a(rs_disp_a[1].imm_rs),
                           .instr_b(rs_disp_b[1].imm_rs),
                           .cdb_arr(cdb_arr),

                           .instr_op(imm_rs_out),
                           .almost_full() );

    res_station_branch rs_branch(.clk(clk),
                                 .rst(rst),
                                 .instr_a(rs_disp_a[3].branch_rs),
                                 .instr_b(rs_disp_b[3].branch_rs),
                                 .cdb_arr(cdb_arr),

                                 .instr_op(branch_rs_out),
                                 .almost_full() );

    func_unit_int fu_int(.clk(clk),
                         .rst(rst),
                         .int_instr(int_rs_out),

                         .cdb_result(int_cdb) );

    func_unit_imm fu_imm(.clk(clk),
                         .rst(rst),
                         .imm_instr(imm_rs_out),

                         .cdb_result(imm_cdb) );

    func_unit_branch fu_branch(.clk(clk),
                               .rst(rst),
                               .branch_instr(branch_rs_out),

                               .result_op(branch_disp) );

    common_data_bus cdb(.int_res(int_cdb),
                        .imm_res(imm_cdb),
                        .load_res('0),

                        .cdb_arr(cdb_arr) );

    reorder_buffer rob(.clk(clk),
                       .rst(rst),
                       .input_a(rob_disp_a),
                       .input_b(rob_disp_b),
                       .cdb_arr(cdb_arr),
                       .str_rob(),
                       .branch_rob(branch_disp),

                       .output_arr(rob_out_arr),
                       .ids_to_free(ids_to_free) );

    always #5 clk = ~clk;


    // --- Golden model ---
    // One queue entry per instruction, in the order it is expected to commit
    typedef struct {
        bit is_branch;
        logic [3:0] arch_reg;   // for reg-writing ops
        logic [31:0] value;     // expected result for reg-writing ops
        logic actual_taken;     // for branches: whether branch was taken
    } golden_commit_t;

    golden_commit_t golden_q [$];

    int golden_checked;
    int golden_errors;

    task automatic golden_run();
        logic [31:0] gold_mem [0:DATA_MEM_SIZE-1];
        logic [31:0] gold_regs [0:NUM_ARCH_REGS-1];
        logic [ADDRBUS_SIZE-1:0] gpc;
        instruction cur;
        logic [31:0] raw;
        logic [31:0] s_val, t_val, d_val;
        int steps;
        golden_commit_t commit;

        $readmemh("instr_mem.mem", gold_mem);
        gold_regs = '{default: '0};
        gpc = '0;
        steps = 0;

        // Bounded so a bug in golden decode/control-flow can't spin forever.
        while (steps < 64) begin
            raw = gold_mem[gpc];
            cur = instruction'(raw);

            if (cur.opcode == 0) break; // treat opcode 0 as end of program

            s_val = gold_regs[cur.reg_s];
            t_val = gold_regs[cur.reg_t];

            unique case (cur.opcode) inside
                [1:14] : begin // int reg-reg ALU ops
                    d_val = '0;
                    unique case (alu_opcode'(cur.opcode))
                        ALU_ADD:    d_val = s_val + t_val;
                        ALU_SUB:    d_val = s_val - t_val;
                        ALU_LSHIFT: d_val = s_val << t_val[5:0];
                        ALU_RSHIFT: d_val = s_val >> t_val[5:0];
                        ALU_EQ:     d_val = (s_val == t_val);
                        ALU_GTE:    d_val = (s_val >= t_val);
                        ALU_LTE:    d_val = (s_val <= t_val);
                        ALU_GT:     d_val = (s_val > t_val);
                        ALU_LT:     d_val = (s_val < t_val);
                        ALU_AND:    d_val = s_val & t_val;
                        ALU_OR:     d_val = s_val | t_val;
                        ALU_NOR:    d_val = ~(s_val | t_val);
                        ALU_NAND:   d_val = ~(s_val & t_val);
                        ALU_XOR:    d_val = s_val ^ t_val;
                        default:    d_val = '0;
                    endcase

                    gold_regs[cur.reg_d] = d_val;
                    commit.is_branch = 0;
                    commit.arch_reg = cur.reg_d;
                    commit.value = d_val;
                    commit.actual_taken = 1'b0;
                    golden_q.push_back(commit);
                    gpc = gpc + 1;
                end

                [15:25] : begin // immediate ALU ops
                    logic [31:0] imm_ext;
                    imm_ext = {20'b0, cur.imm};
                    d_val = '0;
                    unique case (ialu_opcode'(cur.opcode))
                        IALU_ADD:  d_val = s_val + imm_ext;
                        IALU_SUB:  d_val = s_val - imm_ext;
                        IALU_RSHI: d_val = s_val >> imm_ext[5:0];
                        IALU_LSHI: d_val = s_val << imm_ext[5:0];
                        IALU_AND:  d_val = s_val & imm_ext;
                        IALU_OR:   d_val = s_val | imm_ext;
                        IALU_EQ:   d_val = (s_val == imm_ext);
                        IALU_GTE:  d_val = (s_val >= imm_ext);
                        IALU_LTE:  d_val = (s_val <= imm_ext);
                        IALU_GT:   d_val = (s_val > imm_ext);
                        IALU_LT:   d_val = (s_val < imm_ext);
                        default:   d_val = '0;
                    endcase

                    gold_regs[cur.reg_d] = d_val;
                    commit.is_branch = 0;
                    commit.arch_reg = cur.reg_d;
                    commit.value = d_val;
                    commit.actual_taken = 1'b0;
                    golden_q.push_back(commit);
                    gpc = gpc + 1;
                end

                [28:33] : begin // branches
                    logic taken;
                    taken = 1'b0;
                    unique case (comp_opcode'(cur.opcode))
                        COMP_EQ:  taken = (s_val == t_val);
                        COMP_NE:  taken = (s_val != t_val);
                        COMP_GE:  taken = ($signed(s_val) >= $signed(t_val));
                        COMP_LT:  taken = ($signed(s_val) <  $signed(t_val));
                        COMP_GEU: taken = (s_val >= t_val);
                        COMP_LTU: taken = (s_val <  t_val);
                        default:  taken = 1'b0;
                    endcase

                    commit.is_branch = 1;
                    commit.arch_reg = '0;
                    commit.value = '0;
                    commit.actual_taken = taken;
                    golden_q.push_back(commit);
                    gpc = taken ? (gpc + cur.imm) : (gpc + 1);
                end

                [34:34] : begin // jump
                    gpc = cur.imm;
                end

                default : gpc = gpc + 1;
            endcase

            steps++;
        end
    endtask

    // Checker - pops golden_q as the ROB actually commits entries
    task automatic check_commit(input rob_entry entry);
        golden_commit_t exp;

        if (!entry.reg_rob.valid) return;

        if (golden_q.size() == 0) begin
            $error("[%0t] ROB committed an entry but golden_q is empty (unexpected extra commit)", $time);
            golden_errors++;
            return;
        end

        exp = golden_q.pop_front();
        golden_checked++;

        if (exp.is_branch) begin
            if (entry.branch_rob.actual !== exp.actual_taken) begin
                $error("[%0t] branch commit #%0d mismatch: hw actual=%0b golden actual=%0b",
                    $time, golden_checked, entry.branch_rob.actual, exp.actual_taken);
                golden_errors++;
            end else begin
                $display("[%0t] branch commit #%0d OK: actual=%0b",
                    $time, golden_checked, exp.actual_taken);
            end
        end else begin
            if (entry.reg_rob.arch !== exp.arch_reg || entry.reg_rob.result !== exp.value) begin
                $error("[%0t] reg commit #%0d mismatch: hw arch=r%0d result=0x%08x golden arch=r%0d value=0x%08x",
                    $time, golden_checked, entry.reg_rob.arch, entry.reg_rob.result, exp.arch_reg, exp.value);
                golden_errors++;
            end else begin
                $display("[%0t] reg commit #%0d OK: r%0d = 0x%08x",
                    $time, golden_checked, exp.arch_reg, exp.value);
            end
        end
    endtask

    always_ff @ (posedge clk) begin
        if (!rst) begin
            if (rob_out_arr[0].reg_rob.valid) check_commit(rob_out_arr[0]);
            if (rob_out_arr[1].reg_rob.valid) check_commit(rob_out_arr[1]);
        end
    end

    initial begin
        clk = 0; rst = 1;
        golden_checked = 0;
        golden_errors = 0;
        golden_run();
        #10;
        rst = 0;

        #160;

        if (golden_q.size() != 0) begin
            $error("Test ended with %0d instruction(s) still un-retired in golden_q", golden_q.size());
            golden_errors++;
        end

        if (golden_errors == 0)
            $display("PREDICT_TB PASS: %0d commits checked, 0 errors", golden_checked);
        else
            $display("PREDICT_TB FAIL: %0d commits checked, %0d errors", golden_checked, golden_errors);

        $finish;
    end
endmodule
