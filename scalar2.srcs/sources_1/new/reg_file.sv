`timescale 1ns / 1ps

import config_pkg::*;

// Decode already happens b/c of the struct type fields, so renaming happens in here
module reg_file(clk, og_instr_a, og_instr_b,
                    rename_a, rename_b);

    input clk;
    input instruction og_instr_a, og_instr_b;
    output rs_entry rename_a, rename_b;

    // Register Alias Table (RAT) - 16 Registers
    // Each register holds the index of a physical register in PRF (0-31)
    logic [0:4] alias_table [0:NUM_REGS - 1];
    logic [0:4] next_alias_table [0:NUM_REGS - 1];

    // Physical Register File (PRF) - 32 Registers
    phys_reg phys_file [0:31];
    phys_reg next_phys_file [0:31];

    instruction instr_a_reg, instr_b_reg;

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
            phys_file[i] = 0;
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

        // Rename Instruction A
        case(instr_a_reg.opcode) inside
            [1:15] : begin
                rename_a.int_rs.opcode = instr_a_reg.opcode;
                rename_a.int_rs.reg1 = alias_table[instr_a_reg.reg_s];
                rename_a.int_rs.reg2 = alias_table[instr_a_reg.reg_t];
                rename_a.int_rs.value1 = phys_file[rename_a.int_rs.reg1].data;
                rename_a.int_rs.value2 = phys_file[rename_a.int_rs.reg2].data;
                rename_a.int_rs.check1 = phys_file[rename_a.int_rs.reg1].valid;
                rename_a.int_rs.check2 = phys_file[rename_a.int_rs.reg2].valid;

                for(int i = 0; i < 32; i++) begin
                    next_alias_table[instr_a_reg.reg_d] = i;
                    next_phys_file[next_alias_table[instr_a_reg.reg_d]].free = 0;
                end

                rename_a.int_rs.dest = phys_file[alias_table[instr_a_reg.reg_d]];
                next_phys_file[next_alias_table[instr_a_reg.reg_d]].valid = 0;
            end

            [16:27] : begin
                rename_a.imm_rs.opcode = instr_a_reg.opcode;
                rename_a.imm_rs.reg_s = alias_table[instr_a_reg.reg_s];
                rename_a.imm_rs.value = phys_file[rename_a.imm_rs.reg_s].data;
                rename_a.imm_rs.check = phys_file[rename_a.imm_rs.reg_s].valid;
                rename_a.imm_rs.imm = instr_a_reg.imm;

                for(int i = 0; i < 32; i++) begin
                    next_alias_table[instr_a_reg.reg_d] = i;
                    next_phys_file[next_alias_table[instr_a_reg.reg_d]].free = 0;
                end

                rename_a.imm_rs.dest = phys_file[alias_table[instr_a_reg.reg_d]];
                next_phys_file[next_alias_table[instr_a_reg.reg_d]].valid = 0;
            end
        endcase

        case(instr_b_reg.opcode) inside
            [1:15] : begin
                rename_b.int_rs.opcode = instr_b_reg.opcode;
                rename_b.int_rs.reg1 = next_alias_table[instr_b_reg.reg_s];
                rename_b.int_rs.reg2 = next_alias_table[instr_b_reg.reg_t];
                rename_b.int_rs.value1 = next_phys_file[rename_b.int_rs.reg1].data;
                rename_b.int_rs.value2 = next_phys_file[rename_b.int_rs.reg2].data;
                rename_b.int_rs.check1 = next_phys_file[rename_b.int_rs.reg1].valid;
                rename_b.int_rs.check2 = next_phys_file[rename_b.int_rs.reg2].valid;

                for(int i = 0; i < 32; i++) begin
                    next_alias_table[instr_b_reg.reg_d] = i;
                    next_phys_file[next_alias_table[instr_b_reg.reg_d]].free = 0;
                end

                rename_b.int_rs.dest = next_phys_file[next_alias_table[instr_b_reg.reg_d]];
                next_phys_file[next_alias_table[instr_b_reg.reg_d]].valid = 0;
            end

            [16:27] : begin
                rename_b.imm_rs.opcode = instr_b_reg.opcode;
                rename_b.imm_rs.reg_s = next_alias_table[instr_b_reg.reg_s];
                rename_b.imm_rs.value = next_phys_file[rename_b.imm_rs.reg_s].data;
                rename_b.imm_rs.check = next_phys_file[rename_b.imm_rs.reg_s].valid;
                rename_b.imm_rs.imm = instr_b_reg.imm;

                for(int i = 0; i < 32; i++) begin
                    next_alias_table[instr_b_reg.reg_d] = i;
                    next_phys_file[next_alias_table[instr_b_reg.reg_d]].free = 0;
                end

                rename_b.imm_rs.dest = next_phys_file[next_alias_table[instr_b_reg.reg_d]];
                next_phys_file[next_alias_table[instr_b_reg.reg_d]].valid = 0;
            end
        endcase
    end
endmodule

// Junk Code
/*
if(instr_a_reg.opcode inside {[1:15]} && instr_b_reg.opcode inside {[1:15]}) begin
            rename_a.opcode = instr_a_reg.opcode;
            rename_a.reg1 = alias_table[instr_a_reg.reg_s];
            rename_a.reg2 = alias_table[instr_a_reg.reg_t];
            rename_a.value1 = phys_file[rename_a.reg1].data;
            rename_a.value2 = phys_file[rename_a.reg2].data;
            rename_a.check1 = phys_file[rename_a.reg1].valid;
            rename_a.check2 = phys_file[rename_a.reg2].valid;

            // Find new physical register for architectural register
            for(int i = 0; i < 32; i = i + 1) begin
                if(phys_file[i].free == 1) begin
                    alias_table[instr_a_reg.reg_d] = i;
                    phys_file[alias_table[instr_a_reg.reg_d]].free = 0;
                end
            end

            rename_a.dest = phys_file[alias_table[instr_a_reg.reg_d]];
            phys_file[alias_table[instr_a_reg.reg_d]].valid = 0;

            rename_b.opcode = instr_b_reg.opcode;
            rename_b.reg1 = alias_table[instr_b_reg.reg_s];
            rename_b.reg2 = alias_table[instr_b_reg.reg_t];
            rename_b.value1 = phys_file[rename_b.reg1].data;
            rename_b.value2 = phys_file[rename_b.reg2].data;
            rename_b.check1 = phys_file[rename_b.reg1].valid;
            rename_b.check2 = phys_file[rename_b.reg2].valid;

            // Find new physical register for architectural register
            for(int i = 0; i < 32; i = i + 1) begin
                if(phys_file[i].free == 1) begin
                    alias_table[instr_b_reg.reg_d] = i;
                    phys_file[alias_table[instr_b_reg.reg_d]].free = 0;
                end
            end

            rename_b.dest = phys_file[alias_table[instr_b_reg.reg_d]];
            phys_file[alias_table[instr_b_reg.reg_d]].valid = 0;
        end else begin
            rename_a = 0;
            rename_b = 0;
        end
*/
