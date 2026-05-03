`timescale 1ns / 1ps

import config_pkg::*;

// Decode already happens b/c of the struct type fields, so renaming happens in here
module reg_file(clk, rst, og_instr_a, og_instr_b, cdb_arr, commit_arr,
                    rename_a, rename_b, rob_a, rob_b);

    input logic clk, rst;
    input instruction og_instr_a, og_instr_b;
    input cdb_entry cdb_arr [0:3];
    input rob_entry commit_arr [0:3];
    
    output rs_entry rename_a, rename_b;
    output rob_entry rob_a, rob_b;

    // Register Alias Table (RAT) - 16 Registers
    // Each register holds the index of a physical register in PRF (0-31)
    logic [0:4] alias_table [0:NUM_REGS - 1];
    logic [0:4] next_alias_table [0:NUM_REGS - 1];

    // Physical Register File (PRF) - 32 Registers
    phys_reg phys_file [0:31];
    phys_reg next_phys_file [0:31];

    // Register Retirement Table (RRT) - Structurally same as RAT
    logic [0:4] retire_table [0:NUM_REGS - 1];
    logic [0:4] next_retire_table [0:NUM_REGS - 1];

    instruction instr_a_reg, instr_b_reg;

    // Intermediaries to hold alias table register (mainly for cleanliness)
    logic [0:4] idx_a1, idx_a2; 
    logic [0:4] idx_b1, idx_b2;

    always_ff @ (posedge clk) begin
        if (rst) begin
            for (int i = 0; i < 32; i++) begin
                phys_file[i].valid <= 1;
                phys_file[i].free <= (i < NUM_REGS) ? 1'b0 : 1'b1;
                phys_file[i].data <= 1;
            end
            for (int i = 0; i < NUM_REGS; i++)
                alias_table[i] <= i[4:0];
            instr_a_reg <= '0;
            instr_b_reg <= '0;
        end else begin
            instr_a_reg <= og_instr_a;
            instr_b_reg <= og_instr_b;
            phys_file <= next_phys_file;
            alias_table <= next_alias_table;
            retire_table <= next_retire_table;
        end
    end

    always_comb begin
        next_alias_table = alias_table;
        next_phys_file = phys_file;
        next_retire_table = retire_table;

        rob_a = '0;
        rob_b = '0;
        rename_a = '0;
        rename_b = '0;

        // id & opcode share the same bits regardless of type; id stays 0 until dispatch assigns it
        if (instr_a_reg.opcode != 0) rename_a.int_rs.opcode = instr_a_reg.opcode;
        if (instr_b_reg.opcode != 0) rename_b.int_rs.opcode = instr_b_reg.opcode;

        // Rename Instruction A
        case(instr_a_reg.opcode) inside
            [1:15] : begin
                idx_a1 = alias_table[instr_a_reg.reg_s];
                idx_a2 = alias_table[instr_a_reg.reg_t];
                rename_a.int_rs.reg1 = idx_a1;
                rename_a.int_rs.reg2 = idx_a2;
                rename_a.int_rs.value1 = phys_file[idx_a1].data;
                rename_a.int_rs.value2 = phys_file[idx_a2].data;
                rename_a.int_rs.check1 = phys_file[idx_a1].valid;
                rename_a.int_rs.check2 = phys_file[idx_a2].valid;

                for(int i = 0; i < 32; i++) begin
                    if(phys_file[i].free == 1) begin
                        rob_a.old_prf = next_alias_table[instr_a_reg.reg_d];
                        rob_a.new_prf = i;
                        rob_a.arch = instr_a_reg.reg_d;

                        next_alias_table[instr_a_reg.reg_d] = i;
                        next_phys_file[next_alias_table[instr_a_reg.reg_d]].free = 0;
                        next_phys_file[next_alias_table[instr_a_reg.reg_d]].valid = 0;
                        rename_a.int_rs.dest = i;
                        break;
                    end
                end
            end

            [16:27] : begin
                idx_a1 = alias_table[instr_a_reg.reg_s];
                rename_a.imm_rs.reg_s = idx_a1;
                rename_a.imm_rs.value = phys_file[idx_a1].data;
                rename_a.imm_rs.check = phys_file[idx_a1].valid;
                rename_a.imm_rs.imm = instr_a_reg.imm;

                for(int i = 0; i < 32; i++) begin
                    if(phys_file[i].free == 1) begin
                        rob_a.old_prf = next_alias_table[instr_a_reg.reg_d];
                        rob_a.new_prf = i;
                        rob_a.arch = instr_a_reg.reg_d;

                        next_alias_table[instr_a_reg.reg_d] = i;
                        next_phys_file[next_alias_table[instr_a_reg.reg_d]].free = 0;
                        next_phys_file[next_alias_table[instr_a_reg.reg_d]].valid = 0;
                        rename_a.imm_rs.dest = i;
                        break;
                    end
                end
            end

            [28:28] : begin
                idx_a1 = alias_table[instr_a_reg.reg_s];
                rename_a.load_rs.reg_s = idx_a1;
                rename_a.load_rs.value = phys_file[idx_a1].data;
                rename_a.load_rs.check = phys_file[idx_a1].valid;
                rename_a.load_rs.offset = instr_a_reg.imm;

                for(int i = 0; i < 32; i++) begin
                    if(phys_file[i].free == 1) begin
                        rob_a.old_prf = next_alias_table[instr_a_reg.reg_d];
                        rob_a.new_prf = i;
                        rob_a.arch = instr_a_reg.reg_d;

                        next_alias_table[instr_a_reg.reg_d] = i;
                        next_phys_file[next_alias_table[instr_a_reg.reg_d]].free = 0;
                        next_phys_file[next_alias_table[instr_a_reg.reg_d]].valid = 0;
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
            end
        endcase

        // Rename Instruction B (reads next_... stuff to use A's renaming updates)
        case(instr_b_reg.opcode) inside
            [1:15] : begin
                idx_b1 = next_alias_table[instr_b_reg.reg_s];
                idx_b2 = next_alias_table[instr_b_reg.reg_t];
                rename_b.int_rs.reg1 = idx_b1;
                rename_b.int_rs.reg2 = idx_b2;
                rename_b.int_rs.value1 = next_phys_file[idx_b1].data;
                rename_b.int_rs.value2 = next_phys_file[idx_b2].data;
                rename_b.int_rs.check1 = next_phys_file[idx_b1].valid;
                rename_b.int_rs.check2 = next_phys_file[idx_b2].valid;

                for(int i = 0; i < 32; i++) begin
                    if(next_phys_file[i].free == 1) begin
                        rob_b.old_prf = next_alias_table[instr_b_reg.reg_d];
                        rob_b.new_prf = i;
                        rob_b.arch = instr_b_reg.reg_d;

                        next_alias_table[instr_b_reg.reg_d] = i;
                        next_phys_file[next_alias_table[instr_b_reg.reg_d]].free = 0;
                        next_phys_file[next_alias_table[instr_b_reg.reg_d]].valid = 0;
                        rename_b.int_rs.dest = i;
                        break;
                    end
                end
            end

            [16:27] : begin
                idx_b1 = next_alias_table[instr_b_reg.reg_s];
                rename_b.imm_rs.reg_s = idx_b1;
                rename_b.imm_rs.value = next_phys_file[idx_b1].data;
                rename_b.imm_rs.check = next_phys_file[idx_b1].valid;
                rename_b.imm_rs.imm = instr_b_reg.imm;

                for(int i = 0; i < 32; i++) begin
                    if(next_phys_file[i].free == 1) begin
                        rob_b.old_prf = next_alias_table[instr_b_reg.reg_d];
                        rob_b.new_prf = i;
                        rob_b.arch = instr_b_reg.reg_d;

                        next_alias_table[instr_b_reg.reg_d] = i;
                        next_phys_file[next_alias_table[instr_b_reg.reg_d]].free = 0;
                        next_phys_file[next_alias_table[instr_b_reg.reg_d]].valid = 0;
                        rename_b.imm_rs.dest = i;
                        break;
                    end
                end
            end

            [28:28] : begin
                idx_b1 = next_alias_table[instr_b_reg.reg_s];
                rename_b.load_rs.reg_s = idx_b1;
                rename_b.load_rs.value = next_phys_file[idx_b1].data;
                rename_b.load_rs.check = next_phys_file[idx_b1].valid;
                rename_b.load_rs.offset = instr_b_reg.imm;

                for(int i = 0; i < 32; i++) begin
                    if(next_phys_file[i].free == 1) begin
                        rob_b.old_prf = next_alias_table[instr_b_reg.reg_d];
                        rob_b.new_prf = i;
                        rob_b.arch = instr_b_reg.reg_d;

                        next_alias_table[instr_b_reg.reg_d] = i;
                        next_phys_file[next_alias_table[instr_b_reg.reg_d]].free = 0;
                        next_phys_file[next_alias_table[instr_b_reg.reg_d]].valid = 0;
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
            end
        endcase

        for(int i = 0; i < 4; i++) begin
            if(cdb_arr[i] == 0) continue;
            next_phys_file[cdb_arr[i].prf].valid = 1;
            next_phys_file[cdb_arr[i].prf].data = cdb_arr[i].result;
        end

        // Retirement table setting from 
        for(int i = 0; i < 4; i++) begin
            if(commit_arr[i] == 0) continue;
            phys_file[commit_arr[i].old_prf].free = 1;
            next_retire_table[commit_arr[i].arch] = commit_arr[i].new_prf;
        end
    end
endmodule