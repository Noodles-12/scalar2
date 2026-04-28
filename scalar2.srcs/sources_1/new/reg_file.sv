`timescale 1ns / 1ps

import config_pkg::*;

// Decode already happens b/c of the struct type fields, so renaming happens in here
module reg_file(clk, og_instr_a, og_instr_b,
                    rename_a, rename_b, rob_a, rob_b);

    input logic clk;
    input instruction og_instr_a, og_instr_b;
    
    output rs_entry rename_a, rename_b;
    output rob_entry rob_a, rob_b;

    // Register Alias Table (RAT) - 16 Registers
    // Each register holds the index of a physical register in PRF (0-31)
    logic [0:4] alias_table [0:NUM_REGS - 1];
    logic [0:4] next_alias_table [0:NUM_REGS - 1];

    // Physical Register File (PRF) - 32 Registers
    phys_reg phys_file [0:31];
    phys_reg next_phys_file [0:31];

    instruction instr_a_reg, instr_b_reg;

    // Intermediaries to hold alias table register (mainly for cleanliness)
    logic [0:4] idx_a1, idx_a2; 
    logic [0:4] idx_b1, idx_b2;

    initial begin
        // Instantiate PRF
        for(int i = 0; i < 32; i = i + 1) begin
            phys_file[i].valid = 1;
            phys_file[i].free = 1;
            phys_file[i].data = 1;
        end

        // Instantiate RAT (as well as taken physical registers)
        for(int i = 0; i < NUM_REGS; i = i + 1) begin
            alias_table[i] = i;
            phys_file[i].free = 0;
        end
    end

    always_ff @ (posedge clk) begin
        instr_a_reg <= og_instr_a;
        instr_b_reg <= og_instr_b;

        phys_file <= next_phys_file;
        alias_table <= next_alias_table;
    end

    always_comb begin
        next_alias_table = alias_table;
        next_phys_file = phys_file;

        rob_a = '0;
        rob_b = '0;

        // id & opcode share the same bits regardless of type
        rename_a.int_rs.id = 0;
        rename_a.int_rs.opcode = instr_a_reg.opcode;
        rename_b.int_rs.id = 0;
        rename_b.int_rs.opcode = instr_b_reg.opcode;

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
        endcase
    end
endmodule