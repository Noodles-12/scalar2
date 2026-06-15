`timescale 1ns / 1ps

module register_file(
    input logic clk,
    input logic rst,
    input instruction instr_a,
    input instruction instr_b,
    input cdb_entry cdb_arr [0:CDB_SIZE - 1],
    input rob_entry commit_arr [0:1],

    output rs_entry res_stat_a_op,
    output rs_entry res_stat_b_op,
    output rob_entry rob_a_op,
    output rob_entry rob_b_op
);
    typedef struct packed {
        logic valid;
        logic [PHYS_REGS_BITS - 1:0] idx;
        logic [ARCH_REGS_BITS - 1:0] arch_reg;
    } rat_rename;

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

    logic [PHYS_REGS_BITS - 1:0] free_a, free_b;
    logic found_a, found_b;

    logic [PHYS_REGS_BITS - 1:0] idx_as, idx_at;
    rs_entry res_stat_a;
    rob_entry rob_a;
    rat_rename rename_a;
    
    logic [PHYS_REGS_BITS - 1:0] idx_bs, idx_bt;
    rs_entry res_stat_b;
    rob_entry rob_b;
    rat_rename rename_b;

    always_ff @ (posedge clk) begin
        if(rst) begin
            for (int i = 0; i < NUM_ARCH_REGS; i++)
                alias_table[i] <= i;

            for (int i = 0; i < NUM_PHYS_REGS; i++) begin
                phys_file[i] <= '0;
                valid_list[i] <= 1;
                free_list[i] <= (i < NUM_ARCH_REGS) ? '0 : '1;
            end
        end else begin
            if(rename_a.valid) begin
                alias_table[rename_a.arch_reg] = rename_a.idx;
                valid_list[rename_a.idx] = 0;
                free_list[rename_a.idx] = 0;
            end

            if(rename_b.valid) begin
                alias_table[rename_b.arch_reg] = rename_b.idx;
                valid_list[rename_b.idx] = 0;
                free_list[rename_b.idx] = 0;
            end

            res_stat_a_op <= res_stat_a;
            res_stat_b_op <= res_stat_b;

            rob_a_op <= rob_a;
            rob_b_op <= rob_b;
        end
    end

    // Free physical register finding
    always_comb begin
        free_a = '0; found_a = 0;
        free_b = '0; found_b = 0;

        for(int i = 0; i < NUM_PHYS_REGS; i++) begin
            if(free_list[i]) begin
                if(!found_a) begin
                    found_a = 1;
                    free_a = i;
                end else if(!found_b) begin
                    found_b = 1;
                    free_b = i;
                end
            end
        end
    end

    // Rename of instruction A
    always_comb begin
        res_stat_a = '0; rob_a = '0;
        idx_as = '0; idx_at = '0;
        rename_a = '0;

        // Valid bit should be in same position for any type of RS entry
        res_stat_a.int_rs.valid = (instr_a.opcode != 0); 
        rob_a.valid = (instr_a.opcode != 0);

        unique case(instr_a.opcode) inside
            [1:14] : begin
                res_stat_a.int_rs.opcode = instr_a.opcode;
                idx_as = alias_table[instr_a.reg_s];
                res_stat_a.int_rs.reg_s = idx_as;
                res_stat_a.int_rs.value_s = phys_file[idx_as];
                res_stat_a.int_rs.check_s = valid_list[idx_as];
                idx_at = alias_table[instr_a.reg_t];
                res_stat_a.int_rs.reg_t = idx_at;
                res_stat_a.int_rs.value_t = phys_file[idx_at];
                res_stat_a.int_rs.check_t = valid_list[idx_at];

                rob_a.old_prf = alias_table[instr_a.reg_d];
                rob_a.arch = instr_a.reg_d;
            end

            [15:25] : begin
                res_stat_a.imm_rs.opcode = instr_a.opcode;
                idx_as = alias_table[instr_a.reg_s];
                res_stat_a.imm_rs.reg_s = idx_as;
                res_stat_a.imm_rs.value_s = phys_file[idx_as];
                res_stat_a.imm_rs.check_s = valid_list[idx_as];
                res_stat_a.imm_rs.imm = instr_a.imm;

                rob_a.old_prf = alias_table[instr_a.reg_d];
                rob_a.arch = instr_a.reg_d;
            end

            [26:26] : begin
                res_stat_a.load_rs.opcode = instr_a.opcode;
                idx_as = alias_table[instr_a.reg_s];
                res_stat_a.load_rs.reg_s = idx_as;
                res_stat_a.load_rs.value_s = phys_file[idx_as];
                res_stat_a.load_rs.check_s = valid_list[idx_as];
                res_stat_a.load_rs.offset = instr_a.imm;
                
                rob_a.old_prf = alias_table[instr_a.reg_d];
                rob_a.arch = instr_a.reg_d;
            end

            [27:27] : begin
                res_stat_a.store_rs.opcode = instr_a.opcode;        
                // reg_s position in instruction is register that has value to combine with offset for effective address
                // Flipped compared to other instructions
                idx_as = alias_table[instr_a.reg_s]; 
                res_stat_a.store_rs.reg_d = idx_as;
                res_stat_a.store_rs.value_d = phys_file[idx_as];
                res_stat_a.store_rs.check_d = valid_list[idx_as];

                // reg_d position in instruction is the source register of the data to put into memory
                // Flipped compared to other operations
                idx_at = alias_table[instr_a.reg_d];
                res_stat_a.store_rs.reg_s = idx_at;
                res_stat_a.store_rs.value_s = phys_file[idx_at];
                res_stat_a.store_rs.check_s = valid_list[idx_at];

                res_stat_a.store_rs.offset = instr_a.imm;

                rob_a.is_store = 1;
            end
            
            default : begin end
        endcase

        if(found_a && (instr_a.opcode != 0) && (instr_a.opcode != 6'b011011)) begin
            rob_a.new_prf = free_a;
            rename_a.valid = 1;
            rename_a.idx = free_a;
            rename_a.arch_reg = instr_a.reg_d;
            
            unique case(instr_a.opcode) inside
                [1:14] : begin
                    res_stat_a.int_rs.dest = free_a;
                end
                [15:25] : begin
                    res_stat_a.imm_rs.dest = free_a;
                end
                [26:26] : begin
                    res_stat_a.load_rs.dest = free_a;
                end
                default : begin end
            endcase
        end
    end

    always_comb begin
        res_stat_b = '0; rob_b = '0;
        idx_bs = '0; idx_bt = '0;
        rename_b = '0;

        // Valid bit should be in same position for any type of RS entry
        res_stat_b.int_rs.valid = (instr_b.opcode != 0); 
        rob_b.valid = (instr_b.opcode != 0);

        if(instr_a.opcode != 6'b011011) begin
            idx_bs = (instr_b.reg_s == instr_a.reg_d) ? free_a : alias_table[instr_b.reg_s];
            idx_bt = (instr_b.reg_t == instr_a.reg_d) ? free_a : alias_table[instr_b.reg_t]; 
        end
        //idx_bs = (instr_b.reg_s == instr_a.reg_d) ? alias_table[instr_b.reg_s];

        unique case(instr_b.opcode) inside
            [1:14] : begin
                res_stat_b.int_rs.opcode = instr_b.opcode;
    
                res_stat_b.int_rs.reg_s = idx_bs;
                res_stat_b.int_rs.value_s = phys_file[idx_bs];
                res_stat_b.int_rs.check_s = valid_list[idx_bs];

                res_stat_b.int_rs.reg_t = idx_bt;
                res_stat_b.int_rs.value_t = phys_file[idx_bt];
                res_stat_b.int_rs.check_t = valid_list[idx_bt];

                rob_b.old_prf = alias_table[instr_b.reg_d];
                rob_b.arch = instr_b.reg_d;
            end

            [15:25] : begin
                res_stat_b.imm_rs.opcode = instr_b.opcode;

                res_stat_b.imm_rs.reg_s = idx_bs;
                res_stat_b.imm_rs.value_s = phys_file[idx_bs];
                res_stat_b.imm_rs.check_s = valid_list[idx_bs];
                res_stat_b.imm_rs.imm = instr_b.imm;

                rob_b.old_prf = alias_table[instr_b.reg_d];
                rob_b.arch = instr_b.reg_d;
            end

            [26:26] : begin
                res_stat_b.load_rs.opcode = instr_b.opcode;

                res_stat_b.load_rs.reg_s = idx_bs;
                res_stat_b.load_rs.value_s = phys_file[idx_bs];
                res_stat_b.load_rs.check_s = valid_list[idx_bs];
                res_stat_b.load_rs.offset = instr_b.imm;

                rob_b.old_prf = alias_table[instr_b.reg_d];
                rob_b.arch = instr_b.reg_d;
            end

            [27:27] : begin
                res_stat_b.store_rs.opcode = instr_b.opcode;
                // reg_s position in instruction is register that has value to combine with offset for effective address
                // Flipped compared to other instructions

                res_stat_b.store_rs.reg_d = idx_bs;
                res_stat_b.store_rs.value_d = phys_file[idx_bs];
                res_stat_b.store_rs.check_d = valid_list[idx_bs];

                // reg_d position in instruction is the source register of the data to put into memory
                // Flipped compared to other operations

                res_stat_b.store_rs.reg_s = idx_bt;
                res_stat_b.store_rs.value_s = phys_file[idx_bt];
                res_stat_b.store_rs.check_s = valid_list[idx_bt];

                res_stat_b.store_rs.offset = instr_b.imm;

                rob_b.is_store = 1;
            end
            
            default : begin end
        endcase

        if(found_b && (instr_b.opcode != 0) && (instr_b.opcode != 6'b011011)) begin
            rob_b.new_prf = free_b;
            rename_b.valid = 1;
            rename_b.idx = free_b;
            rename_b.arch_reg = instr_b.reg_d;

            unique case(instr_b.opcode) inside
                [1:14] : begin
                    res_stat_b.int_rs.dest = free_b;
                end
                [15:25] : begin
                    res_stat_b.imm_rs.dest = free_b;
                end
                [26:26] : begin
                    res_stat_b.load_rs.dest = free_b;
                end
                default : begin end
            endcase
        end
    end
endmodule
