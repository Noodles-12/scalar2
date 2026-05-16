`timescale 1ns / 1ps

import config_pkg::*;

// Decode already happens b/c of the struct type fields, so renaming happens in here
module reg_file(
    input  logic clk,
    input  logic rst,
    input  instruction og_instr_a,
    input  instruction og_instr_b,
    input  cdb_entry cdb_arr [0:CDB_SIZE - 1],
    input  rob_entry commit_arr [0:1],

    output rs_entry rename_a,
    output rs_entry rename_b,
    output rob_entry rob_a,
    output rob_entry rob_b
);

    // Register Alias Table (RAT) - 16 Registers
    // Each register holds the index of a physical register in PRF (0-31)
    logic [ARCH_REGS_BITS - 1:0] alias_table [0:NUM_ARCH_REGS - 1];

    // Physical Register File (PRF) - 32 Registers
    logic [PHYS_REGS_BITS - 1:0] phys_file [0:NUM_PHYS_REGS - 1];
    // Free list that contains free bit for each physical register
    logic free_list [0:NUM_PHYS_REGS - 1];
    // Valid list that contains valid bit for each physical register
    logic valid_list [0:NUM_PHYS_REGS - 1];

    // Register Retirement Table (RRT) - Structurally same as RAT
    logic [ARCH_REGS_BITS - 1:0] retire_table [0:NUM_ARCH_REGS - 1];

    instruction instr_a_reg, instr_b_reg;

    // --- Stage 1 Logics ---
    logic [ARCH_REGS_BITS - 1:0] s1_alias_table [0:NUM_ARCH_REGS - 1];
    logic [PHYS_REGS_BITS - 1:0] s1_phys_file [0:NUM_PHYS_REGS - 1];
    logic s1_free_list [0:NUM_PHYS_REGS - 1];
    logic s1_valid_list [0:NUM_PHYS_REGS - 1];
    
    logic [ARCH_REGS_BITS - 1:0] s1_idx_as, s1_idx_at;
    instruction s1_instr_a, s1_instr_b;
    rs_entry s1_rename_a;
    rob_entry s1_rob_a;

    logic [PHYS_REGS_BITS - 1:0] free_a_idx;
    logic free_a_found;

    // --- PL 1 Logics ---
    logic [ARCH_REGS_BITS - 1:0] ff1_alias_table [0:NUM_ARCH_REGS - 1];
    logic [PHYS_REGS_BITS - 1:0] ff1_phys_file [0:NUM_PHYS_REGS - 1];
    logic ff1_free_list [0:NUM_PHYS_REGS - 1];
    logic ff1_valid_list [0:NUM_PHYS_REGS - 1];

    rs_entry ff1_rename_a;
    rob_entry ff1_rob_a;
    instruction ff1_instr_b;

    // --- Stage 2 Logics ---
    logic [ARCH_REGS_BITS - 1:0] s2_alias_table [0:NUM_ARCH_REGS - 1];
    logic [PHYS_REGS_BITS - 1:0] s2_phys_file [0:NUM_PHYS_REGS - 1];
    logic s2_free_list [0:NUM_PHYS_REGS - 1];
    logic s2_valid_list [0:NUM_PHYS_REGS - 1];

    rs_entry s2_rename_b;
    rob_entry s2_rob_b;

    always_ff @ (posedge clk) begin
        if(rst) begin
            for (int i = 0; i < 32; i++) begin
                phys_file[i].valid <= 1;
                free_list[i] <= (i < NUM_REGS) ? '0 : '1;
                phys_file[i].data <= 0;
            end
            for (int i = 0; i < NUM_REGS; i++)
                alias_table[i] <= i[4:0];
            instr_a_reg <= '0;
            instr_b_reg <= '0;
        end else begin
            instr_a_reg <= og_instr_a;
            instr_b_reg <= og_instr_b;
            //phys_file <= next_phys_file;
            //alias_table <= next_alias_table;
            //retire_table <= next_retire_table;
            //free_list <= next_free_list;
        end

        for(int i = 0; i < CDB_SIZE; i++) begin
            if(cdb_arr[i] != 0)
                $display("CDB change coming in to change P%d to %d | %t", cdb_arr[i].prf, cdb_arr[i].result, $time);
        end
    end
    
    // Stage 1: Rename instruction A
    // Could also fit in CDB will test later
    always_comb begin
        s1_alias_table = alias_table;
        s1_phys_file = phys_file;
        s1_free_list = free_list;
        s1_valid_list = valid_list;

        s1_instr_a = instr_a_reg; 
        s1_instr_b = instr_b_reg;

        s1_rename_a = '0; s1_rob_a = '0;
        s1_idx_as = '0; s1_idx_at = '0;
        free_a_idx = '0; free_a_found = 0;

        case(s1_instr_a.opcode) inside
            [1:14] : begin
                s1_idx_as = s1_alias_table[instr_a_reg.reg_s];
                s1_rename_a.int_rs.reg_s = s1_idx_as;
                s1_rename_a.int_rs.value_s = s1_phys_file[s1_idx_as];
                s1_rename_a.int_rs.check_s = s1_valid_list[s1_idx_as];
                s1_idx_at = s1_alias_table[instr_a_reg.reg_t];
                s1_rename_a.int_rs.reg_t = s1_idx_at;
                s1_rename_a.int_rs.value_t = s1_phys_file[s1_idx_at];
                s1_rename_a.int_rs.check_t = s1_valid_list[s1_idx_at];

                s1_rob_a.old_prf = s1_idx_as;
                s1_rob_a.arch = instr_a_reg.reg_d;
            end
        endcase

        for(int i = 0; i < NUM_PHYS_REGS; i++) begin
            if(s1_free_list[i] && !free_a_found) begin
                free_a_found = 1;
                free_a_idx = i;
            end
        end

        if(free_a_found) begin
            s1_rob_a.new_prf = free_a_idx;
            next_alias_table[instr_a_reg.reg_d] = i;
            s1_free_list = 0;
            s1_valid_list = 0;

            case(s1_instr_a.opcode) inside
                [1:14] : begin
                    s1_rename_a.int_rs.dest = i;
                end
            endcase
        end
    end

    always_ff @ (posedge clk) begin
        ff1_alias_table <= s1_alias_table;
        ff1_phys_file <= s1_phys_file;
        ff1_free_list <= s1_free_list;
        ff1_valid_list <= s1_valid_list;

        ff1_rename_a <= s1_rename_a;
        ff1_rob_a <= s1_rob_a;
        ff1_instr_b <= s1_instr_b;
    end

    /* always_comb begin
        next_alias_table = alias_table;
        next_phys_file = phys_file;
        next_retire_table = retire_table;
        next_free_list = free_list;

        rob_a = '0;
        rob_b = '0;
        rename_a = '0;
        rename_b = '0;

        // id & opcode share the same bits regardless of type; id stays 0 until dispatch assigns it
        if (instr_a_reg.opcode != 0) rename_a.int_rs.opcode = instr_a_reg.opcode;
        if (instr_b_reg.opcode != 0) rename_b.int_rs.opcode = instr_b_reg.opcode;

        // Rename Instruction A
        case(instr_a_reg.opcode) inside
            [1:14] : begin
                idx_a1 = alias_table[instr_a_reg.reg_s];
                idx_a2 = alias_table[instr_a_reg.reg_t];
                rename_a.int_rs.reg1 = idx_a1;
                rename_a.int_rs.reg2 = idx_a2;
                rename_a.int_rs.value1 = phys_file[idx_a1].data;
                rename_a.int_rs.value2 = phys_file[idx_a2].data;
                rename_a.int_rs.check1 = phys_file[idx_a1].valid;
                rename_a.int_rs.check2 = phys_file[idx_a2].valid;

                for(int i = 0; i < 32; i++) begin
                    if(free_list[i] == 1) begin
                        rob_a.old_prf = next_alias_table[instr_a_reg.reg_d];
                        rob_a.new_prf = i;
                        rob_a.arch = instr_a_reg.reg_d;

                        next_alias_table[instr_a_reg.reg_d] = i;
                        next_free_list[i] = 0;
                        next_phys_file[i].valid = 0;
                        rename_a.int_rs.dest = i;
                        break;
                    end
                end
            end

            [16:26] : begin
                idx_a1 = alias_table[instr_a_reg.reg_s];
                rename_a.imm_rs.reg_s = idx_a1;
                rename_a.imm_rs.value = phys_file[idx_a1].data;
                rename_a.imm_rs.check = phys_file[idx_a1].valid;
                rename_a.imm_rs.imm = instr_a_reg.imm;

                for(int i = 0; i < 32; i++) begin
                    if(free_list[i] == 1) begin
                        rob_a.old_prf = next_alias_table[instr_a_reg.reg_d];
                        rob_a.new_prf = i;
                        rob_a.arch = instr_a_reg.reg_d;

                        next_alias_table[instr_a_reg.reg_d] = i;
                        next_free_list[i] = 0;
                        next_phys_file[i].valid = 0;
                        rename_a.imm_rs.dest = i;
                        break;
                    end
                end
            end

            [28:28] : begin
                idx_a1 = alias_table[instr_a_reg.reg_s];
                rename_a.load_rs.reg_s = idx_a1;
                rename_a.load_rs.base_val = phys_file[idx_a1].data;
                rename_a.load_rs.base_ready = phys_file[idx_a1].valid;
                rename_a.load_rs.offset = instr_a_reg.imm;

                for(int i = 0; i < 32; i++) begin
                    if(free_list[i] == 1) begin
                        rob_a.old_prf = next_alias_table[instr_a_reg.reg_d];
                        rob_a.new_prf = i;
                        rob_a.arch = instr_a_reg.reg_d;

                        next_alias_table[instr_a_reg.reg_d] = i;
                        next_free_list[i] = 0;
                        next_phys_file[i].valid = 0;
                        rename_a.load_rs.dest = i;
                        break;
                    end
                end
            end

            [29:29] : begin
                idx_a1 = alias_table[instr_a_reg.reg_d];
                idx_a2 = alias_table[instr_a_reg.reg_s];
                rename_a.store_rs.reg_d = idx_a1;
                rename_a.store_rs.reg_s = idx_a2;
                rename_a.store_rs.value1 = phys_file[idx_a1].data;
                rename_a.store_rs.value2 = phys_file[idx_a2].data;
                rename_a.store_rs.check1 = phys_file[idx_a1].valid;
                rename_a.store_rs.check2 = phys_file[idx_a2].valid;
                rename_a.store_rs.offset = instr_a_reg.imm;
                rob_a.is_store = 1;
            end
        endcase

        // Rename Instruction B (reads next_... stuff to use A's renaming updates)
        case(instr_b_reg.opcode) inside
            [1:14] : begin
                idx_b1 = next_alias_table[instr_b_reg.reg_s];
                idx_b2 = next_alias_table[instr_b_reg.reg_t];
                rename_b.int_rs.reg1 = idx_b1;
                rename_b.int_rs.reg2 = idx_b2;
                rename_b.int_rs.value1 = next_phys_file[idx_b1].data;
                rename_b.int_rs.value2 = next_phys_file[idx_b2].data;
                rename_b.int_rs.check1 = next_phys_file[idx_b1].valid;
                rename_b.int_rs.check2 = next_phys_file[idx_b2].valid;

                for(int i = 0; i < 32; i++) begin
                    if(next_free_list[i] == 1) begin
                        rob_b.old_prf = next_alias_table[instr_b_reg.reg_d];
                        rob_b.new_prf = i;
                        rob_b.arch = instr_b_reg.reg_d;

                        next_alias_table[instr_b_reg.reg_d] = i;
                        next_free_list[i] = 0;
                        next_phys_file[i].valid = 0;
                        rename_b.int_rs.dest = i;
                        break;
                    end
                end
            end

            [16:26] : begin
                idx_b1 = next_alias_table[instr_b_reg.reg_s];
                rename_b.imm_rs.reg_s = idx_b1;
                rename_b.imm_rs.value = next_phys_file[idx_b1].data;
                rename_b.imm_rs.check = next_phys_file[idx_b1].valid;
                rename_b.imm_rs.imm = instr_b_reg.imm;

                for(int i = 0; i < 32; i++) begin
                    if(next_free_list[i] == 1) begin
                        rob_b.old_prf = next_alias_table[instr_b_reg.reg_d];
                        rob_b.new_prf = i;
                        rob_b.arch = instr_b_reg.reg_d;

                        next_alias_table[instr_b_reg.reg_d] = i;
                        next_free_list[i] = 0;
                        next_phys_file[i].valid = 0;
                        rename_b.imm_rs.dest = i;
                        break;
                    end
                end
            end

            [28:28] : begin
                idx_b1 = next_alias_table[instr_b_reg.reg_s];
                rename_b.load_rs.reg_s = idx_b1;
                rename_b.load_rs.base_val = next_phys_file[idx_b1].data;
                rename_b.load_rs.base_ready = next_phys_file[idx_b1].valid;
                rename_b.load_rs.offset = instr_b_reg.imm;

                for(int i = 0; i < 32; i++) begin
                    if(next_free_list[i] == 1) begin
                        rob_b.old_prf = next_alias_table[instr_b_reg.reg_d];
                        rob_b.new_prf = i;
                        rob_b.arch = instr_b_reg.reg_d;

                        next_alias_table[instr_b_reg.reg_d] = i;
                        next_free_list[i] = 0;
                        next_phys_file[i].valid = 0;
                        rename_b.load_rs.dest = i;
                        break;
                    end
                end
            end

            [29:29] : begin
                idx_b1 = next_alias_table[instr_b_reg.reg_d];
                idx_b2 = next_alias_table[instr_b_reg.reg_s];
                rename_b.store_rs.reg_d = idx_b1;
                rename_b.store_rs.reg_s = idx_b2;
                rename_b.store_rs.value1 = next_phys_file[idx_b1].data;
                rename_b.store_rs.value2 = next_phys_file[idx_b2].data;
                rename_b.store_rs.check1 = next_phys_file[idx_b1].valid;
                rename_b.store_rs.check2 = next_phys_file[idx_b2].valid;
                rename_b.store_rs.offset = instr_b_reg.imm;
                rob_b.is_store = 1;
            end
        endcase

        // Validate PRF registers from CDB
        for(int i = 0; i < CDB_SIZE; i++) begin
            if(cdb_arr[i] == 0) continue;
            next_phys_file[cdb_arr[i].prf].valid = 1;
            next_phys_file[cdb_arr[i].prf].data = cdb_arr[i].result;
        end

        // Retirement table setting from commit buffer
        // Might need to add intermediary registers for critical path
        for(int i = 0; i < 2; i++) begin
            if(commit_arr[i] == 0 || commit_arr[i].is_store == 1) continue;
            next_free_list[commit_arr[i].old_prf] = 1;
            next_retire_table[commit_arr[i].arch] = commit_arr[i].new_prf;
        end
    end */
endmodule