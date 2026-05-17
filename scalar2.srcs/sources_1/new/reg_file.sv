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
    logic [PHYS_REGS_BITS - 1:0] alias_table [0:NUM_ARCH_REGS - 1];

    // Physical Register File (PRF) - 32 Registers
    logic [31:0] phys_file [0:NUM_PHYS_REGS - 1];
    // Free list that contains free bit for each physical register
    logic free_list [0:NUM_PHYS_REGS - 1];
    // Valid list that contains valid bit for each physical register
    logic valid_list [0:NUM_PHYS_REGS - 1];

    // Register Retirement Table (RRT) - Structurally same as RAT
    logic [PHYS_REGS_BITS - 1:0] retire_table [0:NUM_ARCH_REGS - 1];

    instruction instr_a_reg, instr_b_reg;

    // --- Stage 1 Logics ---
    logic [PHYS_REGS_BITS - 1:0] s1_alias_table [0:NUM_ARCH_REGS - 1];
    logic [31:0] s1_phys_file [0:NUM_PHYS_REGS - 1];
    logic s1_free_list [0:NUM_PHYS_REGS - 1];
    logic s1_valid_list [0:NUM_PHYS_REGS - 1];

    logic [PHYS_REGS_BITS - 1:0] s1_idx_as, s1_idx_at;
    instruction s1_instr_a, s1_instr_b;
    rs_entry s1_rename_a;
    rob_entry s1_rob_a;

    logic [PHYS_REGS_BITS - 1:0] free_a_idx;
    logic free_a_found;

    logic s1_valid_a, s1_valid_b;
    logic s2_valid_a, s2_valid_b;


    // --- PL 1 Logics ---
    logic [PHYS_REGS_BITS - 1:0] ff1_alias_table [0:NUM_ARCH_REGS - 1];
    logic [31:0] ff1_phys_file [0:NUM_PHYS_REGS - 1];
    logic ff1_free_list [0:NUM_PHYS_REGS - 1];
    logic ff1_valid_list [0:NUM_PHYS_REGS - 1];

    rs_entry ff1_rename_a;
    rob_entry ff1_rob_a;
    instruction ff1_instr_b;

    // --- Stage 2 Logics ---
    logic [PHYS_REGS_BITS - 1:0] s2_alias_table [0:NUM_ARCH_REGS - 1];
    logic [31:0] s2_phys_file [0:NUM_PHYS_REGS - 1];
    logic s2_free_list [0:NUM_PHYS_REGS - 1];
    logic s2_valid_list [0:NUM_PHYS_REGS - 1];

    logic [PHYS_REGS_BITS - 1:0] s2_idx_bs, s2_idx_bt;
    rs_entry s2_rename_b;
    rob_entry s2_rob_b;

    logic [PHYS_REGS_BITS - 1:0] free_b_idx;
    logic free_b_found;

    always_ff @ (posedge clk) begin
        if(rst) begin
            for (int i = 0; i < NUM_PHYS_REGS; i++) begin
                valid_list[i] <= 1;
                free_list[i] <= (i < NUM_ARCH_REGS) ? '0 : '1;
                phys_file[i] <= '0;
            end

            for (int i = 0; i < NUM_ARCH_REGS; i++)
                alias_table[i] <= i;

            instr_a_reg <= '0;
            instr_b_reg <= '0;

            s1_valid_a <= 0;
            s1_valid_b <= 0;

            rename_a <= '0;
            rob_a <= '0;
            rename_b <= '0;
            rob_b <= '0;
        end else begin
            if(s2_valid_a || s2_valid_b) begin
                alias_table <= s2_alias_table;
                phys_file <= s2_phys_file;
                //retire_table <= s2_retire_table;
                free_list <= s2_free_list;
            end
            
            instr_a_reg <= og_instr_a;
            instr_b_reg <= og_instr_b;

            rename_a <= ff1_rename_a;
            rob_a <= ff1_rob_a;
            rename_b <= s2_rename_b;
            rob_b <= s2_rob_b;

            s1_valid_a <= (og_instr_a.opcode != 0);
            s1_valid_b <= (og_instr_b.opcode != 0);
        end

        for(int i = 0; i < CDB_SIZE; i++) begin
            if(cdb_arr[i] != 0)
                $display("CDB change coming in to change P%d to %d | %t",
                    cdb_arr[i].prf,
                    cdb_arr[i].result,
                    $time);
        end

        if(instr_a_reg.opcode != 0)
            $display("Instruction A operation %d | %t", instr_a_reg.opcode, $time);

        if(instr_b_reg.opcode != 0)
            $display("Instruction B operation %d | %t", instr_b_reg.opcode, $time);
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

        s1_rename_a.int_rs.valid = (s1_instr_a.opcode != 0); // Valid bit should be in same position for any type of RS entry
        
        case(s1_instr_a.opcode) inside
            [1:14] : begin
                s1_rename_a.int_rs.opcode = instr_a_reg.opcode;
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

        if(free_a_found && s1_rename_a.int_rs.valid) begin
            s1_rob_a.new_prf = free_a_idx;
            s1_alias_table[instr_a_reg.reg_d] = free_a_idx;
            s1_free_list[free_a_idx] = 0;
            s1_valid_list[free_a_idx] = 0;

            case(s1_instr_a.opcode) inside
                [1:14] : begin
                    s1_rename_a.int_rs.dest = free_a_idx;
                end
            endcase
        end
    end

    always_ff @ (posedge clk) begin
        if (rst) begin
            for (int i = 0; i < NUM_ARCH_REGS; i++)
                ff1_alias_table[i] <= i;

            for(int i = 0; i < NUM_PHYS_REGS; i++) begin
                ff1_valid_list[i] <= 1;
                ff1_free_list[i] <= (i < NUM_ARCH_REGS) ? '0 : '1;
                ff1_phys_file[i] <= '0;
            end

            ff1_rename_a <= '0;
            ff1_rob_a <= '0;
            ff1_instr_b <= '0;

            s2_valid_a <= 0;
            s2_valid_b <= 0;
        end else begin
            if(s1_valid_a || s1_valid_b) begin
                ff1_alias_table <= s1_alias_table;
                ff1_phys_file <= s1_phys_file;
                ff1_free_list <= s1_free_list;
                ff1_valid_list <= s1_valid_list;
            end

            ff1_rename_a <= s1_rename_a;
            ff1_rob_a <= s1_rob_a;
            ff1_instr_b <= s1_instr_b;

            s2_valid_a <= (s1_instr_a.opcode != 0);
            s2_valid_b <= (s1_instr_b.opcode != 0);
        end
    end

    always_comb begin
        s2_alias_table = ff1_alias_table;
        s2_phys_file = ff1_phys_file;
        s2_free_list = ff1_free_list;
        s2_valid_list = ff1_valid_list;

        s2_idx_bs = '0; s2_idx_bt = '0;
        s2_rename_b = '0; s2_rob_b = '0;
        free_b_found = 0; free_b_idx = '0;

        s2_rename_b.int_rs.valid = (ff1_instr_b.opcode != 0);

        case(ff1_instr_b.opcode) inside
            [1:14] : begin
                s2_rename_b.int_rs.opcode = ff1_instr_b.opcode;
                s2_idx_bs = s2_alias_table[ff1_instr_b.reg_s];
                s2_rename_b.int_rs.reg_s = s2_idx_bs;
                s2_rename_b.int_rs.value_s = s2_phys_file[s2_idx_bs];
                s2_rename_b.int_rs.check_s = s2_valid_list[s2_idx_bs];
                s2_idx_bt = s2_alias_table[ff1_instr_b.reg_t];
                s2_rename_b.int_rs.reg_t = s2_idx_bt;
                s2_rename_b.int_rs.value_t = s2_phys_file[s2_idx_bt];
                s2_rename_b.int_rs.check_t = s2_valid_list[s2_idx_bt];

                s2_rob_b.old_prf = s2_idx_bs;
                s2_rob_b.arch = ff1_instr_b.reg_d;
            end
        endcase

        for(int i = 0; i < NUM_PHYS_REGS; i++) begin
            if(s2_free_list[i] && !free_b_found) begin
                free_b_found = 1;
                free_b_idx = i;
            end
        end

        if(free_b_found && s2_rename_b.int_rs.valid) begin
            s2_rob_b.new_prf = free_b_idx;
            s2_alias_table[ff1_instr_b.reg_d] = free_b_idx;
            s2_free_list[free_b_idx] = 0;
            s2_valid_list[free_b_idx] = 0;

            case(ff1_instr_b.opcode) inside
                [1:14] : begin
                    s2_rename_b.int_rs.dest = free_b_idx;
                end
            endcase
        end
    end
endmodule