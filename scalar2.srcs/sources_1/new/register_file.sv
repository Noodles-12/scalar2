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

        end else begin
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
    end

    // Rename of instruction A
    always_comb begin
        res_stat_a = '0; rob_a = '0;
        idx_as = '0; idx_at = '0;
        rename_a = '0;

        // Valid bit should be in same position for any type of RS entry
        res_stat_a.int_rs.valid = (s1_instr_a.opcode != 0); 
        rob_a.valid = (s1_instr_a.opcode != 0);

        unique case(s1_instr_a.opcode) inside
            [1:14] : begin
                res_stat_a.int_rs.opcode = instr_a.opcode;
                idx_as = s1_alias_table[instr_a.reg_s];
                res_stat_a.int_rs.reg_s = idx_as;
                res_stat_a.int_rs.value_s = s1_phys_file[idx_as];
                res_stat_a.int_rs.check_s = s1_valid_list[idx_as];
                idx_at = s1_alias_table[instr_a.reg_t];
                res_stat_a.int_rs.reg_t = idx_at;
                res_stat_a.int_rs.value_t = s1_phys_file[idx_at];
                res_stat_a.int_rs.check_t = s1_valid_list[idx_at];

                rob_a.old_prf = s1_alias_table[instr_a.reg_d];
                rob_a.arch = instr_a.reg_d;
            end

            [15:25] : begin
                res_stat_a.imm_rs.opcode = instr_a.opcode;
                idx_as = s1_alias_table[instr_a.reg_s];
                res_stat_a.imm_rs.reg_s = idx_as;
                res_stat_a.imm_rs.value_s = s1_phys_file[idx_as];
                res_stat_a.imm_rs.check_s = s1_valid_list[idx_as];
                res_stat_a.imm_rs.imm = instr_a.imm;

                rob_a.old_prf = s1_alias_table[instr_a.reg_d];
                rob_a.arch = instr_a.reg_d;
            end

            [26:26] : begin
                res_stat_a.load_rs.opcode = instr_a.opcode;
                idx_as = s1_alias_table[instr_a.reg_s];
                res_stat_a.load_rs.reg_s = idx_as;
                res_stat_a.load_rs.value_s = s1_phys_file[idx_as];
                res_stat_a.load_rs.check_s = s1_valid_list[idx_as];
                res_stat_a.load_rs.offset = instr_a.imm;
                
                rob_a.old_prf = s1_alias_table[instr_a.reg_d];
                rob_a.arch = instr_a.reg_d;
            end

            [27:27] : begin
                res_stat_a.store_rs.opcode = instr_a.opcode;
                // reg_d position in instruction is the source register of the data to put into memory
                // Flipped compared to other operations
                idx_as = s1_alias_table[instr_a.reg_d]; 
                res_stat_a.store_rs.reg_s = idx_as;
                res_stat_a.store_rs.value_s = s1_phys_file[idx_as];
                res_stat_a.store_rs.check_s = s1_valid_list[idx_as];
                // reg_s position in instruction is register that has value to combine with offset for effective address
                // Flipped compared to other instructions
                idx_at = s1_alias_table[instr_a.reg_s];
                res_stat_a.store_rs.reg_d = idx_at;
                res_stat_a.store_rs.value_d = s1_phys_file[idx_at];
                res_stat_a.store_rs.check_d = s1_valid_list[idx_at];
                res_stat_a.store_rs.offset = instr_a.imm;

                rob_a.is_store = 1;
            end
            
            default: begin end
        endcase

        if(found_a && res_stat_a.int_rs.valid && (instr_a.opcode != 6'b011011)) begin
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
            endcase
        end
    end

    always_comb begin

    end
endmodule
