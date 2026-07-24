`timescale 1ns / 1ps

import config_pkg::*;

/*
    Golden model self-checking testbench for int_branch_processor.

    The golden model itself still just walks the program in true program order
    (following actual branch outcomes, not predicted ones) since that's exactly
    what commit_a/commit_b should converge to once recovery has happened.
*/

module int_branch_tb();
    logic clk, rst;

    int_branch_processor dut(
        .clk(clk),
        .rst(rst)
    );

    always #5 clk = ~clk;

    // Golden model
    // One queue entry per instruction, in the order it is expected to
    // architecturally commit (true program order).
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

    // Checker - pops golden_q as commit_pl actually retires entries.
    // Hooked to commit_a/commit_b (post-squash architectural commits),
    // not the ROB's raw output_arr, so mispredicted wrong-path noise
    // never reaches the checker.
    task automatic check_commit(input rob_entry entry);
        golden_commit_t exp;

        if (!entry.reg_rob.valid) return;

        if (golden_q.size() == 0) begin
            $error("[%0t] commit_pl retired an entry but golden_q is empty (unexpected extra commit)", $time);
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
            if (dut.commit_a.reg_rob.valid) check_commit(dut.commit_a);
            if (dut.commit_b.reg_rob.valid) check_commit(dut.commit_b);
        end
    end

    initial begin
        clk = 0; rst = 1;
        golden_checked = 0;
        golden_errors = 0;
        golden_run();
        #10;
        rst = 0;

        #300;

        if (golden_q.size() != 0) begin
            $error("Test ended with %0d instruction(s) still un-retired in golden_q", golden_q.size());
            golden_errors++;
        end

        if (golden_errors == 0)
            $display("INT_BRANCH_TB PASS: %0d commits checked, 0 errors", golden_checked);
        else
            $display("INT_BRANCH_TB FAIL: %0d commits checked, %0d errors", golden_checked, golden_errors);

        $finish;
    end
endmodule
