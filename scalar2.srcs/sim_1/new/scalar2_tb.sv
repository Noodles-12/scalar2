`timescale 1ns / 1ps

import config_pkg::*;

// Golden model self-checking testbench for scalar2_top but with memory now

module scalar2_tb();
    logic clk, rst;

    scalar2_top dut(
        .clk(clk),
        .rst(rst),
        .last_arch_reg()
    );

    always #5 clk = ~clk;

    // Golden model
    typedef enum { COMMIT_REG, COMMIT_BRANCH, COMMIT_STORE } golden_kind_t;

    typedef struct {
        golden_kind_t kind;
        logic [3:0] arch_reg;   // for reg-writing ops
        logic [31:0] value;     // expected result for reg-writing ops / store value
        logic actual_taken;     // for branches: whether branch was taken
        logic [11:0] mem_addr;  // for stores: destination address
    } golden_commit_t;

    golden_commit_t golden_q [$];

    logic [31:0] golden_mem [0:DATA_MEM_SIZE-1];

    int golden_checked;
    int golden_errors;

    // --- Simulation-only stats (nothing here affects checking/pass-fail) ---
    longint cycle_count;
    longint last_commit_cycle;
    int reg_commit_count, store_commit_count, branch_commit_count;
    int mispredict_count;
    int stall_cycle_count;

    task automatic golden_run();
        logic [31:0] gold_mem_instr [0:DATA_MEM_SIZE-1];
        logic [31:0] gold_regs [0:NUM_ARCH_REGS-1];
        logic [ADDRBUS_SIZE-1:0] gpc;
        instruction cur;
        logic [31:0] raw;
        logic [31:0] s_val, t_val, d_val;
        int steps;
        golden_commit_t commit;

        $readmemh("instr_mem.mem", gold_mem_instr);
        // data_memory.sv zeros its entire array on reset; no separate init file to load.
        golden_mem = '{default: '0};
        gold_regs = '{default: '0};
        gpc = '0;
        steps = 0;

        // Bounded so a bug in golden decode/control-flow can't spin forever.
        while (steps < 128) begin
            raw = gold_mem_instr[gpc];
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
                    commit.kind = COMMIT_REG;
                    commit.arch_reg = cur.reg_d;
                    commit.value = d_val;
                    commit.actual_taken = 1'b0;
                    commit.mem_addr = '0;
                    golden_q.push_back(commit);
                    gpc = gpc + 1;
                end

                [15:25] : begin // immediate ALU ops
                    logic [31:0] imm_ext;
                    imm_ext = {18'b0, cur.imm, cur.code};
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
                    commit.kind = COMMIT_REG;
                    commit.arch_reg = cur.reg_d;
                    commit.value = d_val;
                    commit.actual_taken = 1'b0;
                    commit.mem_addr = '0;
                    golden_q.push_back(commit);
                    gpc = gpc + 1;
                end

                [26:26] : begin // lw: $dest <= data_mem[($reg_s) + offset]
                    logic [11:0] eff_addr;
                    eff_addr = s_val[11:0] + cur.imm;
                    d_val = golden_mem[eff_addr];

                    gold_regs[cur.reg_d] = d_val;
                    commit.kind = COMMIT_REG;
                    commit.arch_reg = cur.reg_d;
                    commit.value = d_val;
                    commit.actual_taken = 1'b0;
                    commit.mem_addr = '0;
                    golden_q.push_back(commit);
                    gpc = gpc + 1;
                end

                [27:27] : begin // sw: data_mem[(reg_s) + offset] <= (reg_t); reg_s=base, reg_t=data
                    logic [11:0] eff_addr;
                    eff_addr = s_val[11:0] + cur.imm;
                    golden_mem[eff_addr] = t_val;

                    commit.kind = COMMIT_STORE;
                    commit.arch_reg = '0;
                    commit.value = t_val;
                    commit.actual_taken = 1'b0;
                    commit.mem_addr = eff_addr;
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

                    commit.kind = COMMIT_BRANCH;
                    commit.arch_reg = '0;
                    commit.value = '0;
                    commit.actual_taken = taken;
                    commit.mem_addr = '0;
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
    task automatic check_commit(input rob_entry entry);
        golden_commit_t exp;
        rob_t entry_kind;

        entry_kind = rob_t'(entry.reg_rob.code);

        if (!entry.reg_rob.valid) return;

        if (golden_q.size() == 0) begin
            $error("[%0t] commit_pl retired an entry but golden_q is empty (unexpected extra commit)", $time);
            golden_errors++;
            return;
        end

        exp = golden_q.pop_front();
        golden_checked++;
        last_commit_cycle = cycle_count;

        case (exp.kind)
            COMMIT_BRANCH : begin
                branch_commit_count++;
                if (entry_kind !== ROB_BRN || entry.branch_rob.actual !== exp.actual_taken) begin
                    $error("[%0t] branch commit #%0d mismatch: hw kind=%0d actual=%0b golden actual=%0b",
                        $time, golden_checked, entry_kind, entry.branch_rob.actual, exp.actual_taken);
                    golden_errors++;
                end else begin
                    $display("[%0t] branch commit #%0d OK: actual=%0b",
                        $time, golden_checked, exp.actual_taken);
                end
            end

            COMMIT_STORE : begin
                store_commit_count++;
                if (entry_kind !== ROB_STR || entry.str_rob.mem_dest !== exp.mem_addr || entry.str_rob.value !== exp.value) begin
                    $error("[%0t] store commit #%0d mismatch: hw kind=%0d addr=0x%03x value=0x%08x golden addr=0x%03x value=0x%08x",
                        $time, golden_checked, entry_kind, entry.str_rob.mem_dest, entry.str_rob.value, exp.mem_addr, exp.value);
                    golden_errors++;
                end else begin
                    $display("[%0t] store commit #%0d OK: mem[0x%03x] = 0x%08x",
                        $time, golden_checked, exp.mem_addr, exp.value);
                end
            end

            default : begin // COMMIT_REG
                reg_commit_count++;
                if (entry_kind !== ROB_REG || entry.reg_rob.arch !== exp.arch_reg || entry.reg_rob.result !== exp.value) begin
                    $error("[%0t] reg commit #%0d mismatch: hw kind=%0d arch=r%0d result=0x%08x golden arch=r%0d value=0x%08x",
                        $time, golden_checked, entry_kind, entry.reg_rob.arch, entry.reg_rob.result, exp.arch_reg, exp.value);
                    golden_errors++;
                end else begin
                    $display("[%0t] reg commit #%0d OK: r%0d = 0x%08x",
                        $time, golden_checked, exp.arch_reg, exp.value);
                end
            end
        endcase
    endtask

    always_ff @ (posedge clk) begin
        if (!rst) begin
            if (dut.commit_a.reg_rob.valid) check_commit(dut.commit_a);
            if (dut.commit_b.reg_rob.valid) check_commit(dut.commit_b);
        end
    end

    // Simulation-only stats: cycle count, stall cycles (enable deasserted --
    // structural back-pressure from a full RS/ROB/reg file), mispredict count.
    always @ (posedge clk) begin
        if (!rst) begin
            cycle_count++;
            if (!dut.pipe_enable) stall_cycle_count++;
            if (dut.commit_misp) mispredict_count++;
        end
    end

    initial begin
        clk = 0; rst = 1;
        golden_checked = 0;
        golden_errors = 0;
        cycle_count = 0;
        last_commit_cycle = 0;
        reg_commit_count = 0;
        store_commit_count = 0;
        branch_commit_count = 0;
        mispredict_count = 0;
        stall_cycle_count = 0;
        golden_run();
        #10;
        rst = 0;

        #10000;

        if (golden_q.size() != 0) begin
            $error("Test ended with %0d instruction(s) still un-retired in golden_q", golden_q.size());
            golden_errors++;
        end

        for (int i = 0; i < DATA_MEM_SIZE; i++) begin
            if (dut.data_mem.memory[i] !== golden_mem[i]) begin
                $error("Final memory mismatch at addr 0x%03x: hw=0x%08x golden=0x%08x",
                    i, dut.data_mem.memory[i], golden_mem[i]);
                golden_errors++;
            end
        end

        $display("---------------------------------------------");
        $display("SIMULATION STATS");
        $display("  Simulated cycles     : %0d (includes idle padding after last commit)", cycle_count);
        $display("  Active cycles        : %0d (reset deassert -> last commit)", last_commit_cycle);
        $display("  Total commits        : %0d", golden_checked);
        $display("  IPC (avg, active)    : %0.4f", real'(golden_checked) / real'(last_commit_cycle));
        $display("  Reg commits          : %0d", reg_commit_count);
        $display("  Store commits        : %0d", store_commit_count);
        $display("  Branch commits       : %0d", branch_commit_count);
        $display("  Mispredicts          : %0d", mispredict_count);
        $display("  Branch mispredict %%  : %0.2f%%",
            (branch_commit_count > 0) ? (100.0 * real'(mispredict_count) / real'(branch_commit_count)) : 0.0);
        $display("  Stall cycles         : %0d", stall_cycle_count);
        $display("  Stall %% (active)     : %0.2f%%", 100.0 * real'(stall_cycle_count) / real'(last_commit_cycle));
        $display("---------------------------------------------");

        if (golden_errors == 0)
            $display("SCALAR2_TB PASS: %0d commits checked, 0 errors", golden_checked);
        else
            $display("SCALAR2_TB FAIL: %0d commits checked, %0d errors", golden_checked, golden_errors);

        $finish;
    end
endmodule
