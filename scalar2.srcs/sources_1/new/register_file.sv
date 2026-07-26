`timescale 1ns / 1ps

import config_pkg::*;

module register_file(
    input logic clk,
    input logic rst,
    input logic mispredict_signal,
    input instruction instr_a,
    input instruction instr_b,
    input logic [11:0] recov_a,
    input logic [11:0] recov_b,
    input logic [4:0] hist_a,
    input logic [4:0] hist_b,
    input cdb_entry cdb_arr [0:CDB_SIZE-1],
    input rob_entry commit_a,
    input rob_entry commit_b,

    output rs_entry rs_a_op,
    output rs_entry rs_b_op,
    output rob_entry rob_a_op,
    output rob_entry rob_b_op,
    output [3:0] last_arch_reg
);
    typedef struct packed {
        logic valid;
        logic [PHYS_REGS_BITS - 1:0] idx;
        logic [ARCH_REGS_BITS - 1:0] arch_reg;
    } rat_rename;

    // Register Alias Table (RAT) - 16 Registers
    // Each register holds the index of a physical register in PRF (0-31)
    (* max_fanout = 8 *) logic [PHYS_REGS_BITS - 1:0] alias_table [0:NUM_ARCH_REGS - 1];

    // Physical Register File (PRF) - 32 Registers
    (* max_fanout = 8 *) logic [31:0] phys_file [0:NUM_PHYS_REGS - 1];
    // Free list that contains free bit for each physical register
    (* max_fanout = 8 *) logic free_list [0:NUM_PHYS_REGS - 1];
    // Valid list that contains valid bit for each physical register
    (* max_fanout = 8 *) logic valid_list [0:NUM_PHYS_REGS - 1];

    // Register Retirement Table (RRT) - Structurally same as RAT
    logic [PHYS_REGS_BITS - 1:0] retire_table [0:NUM_ARCH_REGS - 1];
    logic free_retire_list [0:NUM_PHYS_REGS-1];

    logic [31:0] free_bits;
    logic [31:0] onehot_a, onehot_b;
    logic [31:0] free_bits_masked;
    logic [PHYS_REGS_BITS - 1:0] free_a, free_b;
    logic found_a, found_b;

    rs_entry rs_a;
    rob_entry rob_a;
    rat_rename rename_a;
    logic [PHYS_REGS_BITS - 1:0] idx_as, idx_at, idx_ad;
    logic [31:0] value_as, value_at;
    logic check_as, check_at;

    logic match_ai, match_aj, match_ak;
    logic match_ax, match_ay, match_az;
    
    rs_entry rs_b;
    rob_entry rob_b;
    rat_rename rename_b;
    logic s_match, t_match, d_match;
    logic [PHYS_REGS_BITS - 1:0] idx_bs, idx_bt, idx_bd;
    logic [31:0] value_bs, value_bt;
    logic check_bs, check_bt;

    logic match_bi, match_bj, match_bk;
    logic match_bx, match_by, match_bz;

    logic retire_override;

    always_ff @ (posedge clk) begin
        if(rst) begin
            for (int i = 0; i < NUM_ARCH_REGS; i++) begin
                alias_table[i] <= i;
                retire_table[i] <= i;
            end

            for (int i = 0; i < NUM_PHYS_REGS; i++) begin
                phys_file[i] <= '0;
                valid_list[i] <= 1;
                free_list[i] <= (i < NUM_ARCH_REGS) ? '0 : '1;
                free_retire_list[i] <= (i < NUM_ARCH_REGS) ? '0 : '1;
            end
        end else if(retire_override) begin
            alias_table <= retire_table;
            valid_list <= '{default: 1};

            free_list <= free_retire_list;
        end else begin
            if(rename_a.valid) begin
                alias_table[rename_a.arch_reg] <= rename_a.idx;
                valid_list[rename_a.idx] <= 0;
                free_list[rename_a.idx] <= 0;
            end

            if(rename_b.valid) begin
                alias_table[rename_b.arch_reg] <= rename_b.idx;
                valid_list[rename_b.idx] <= 0;
                free_list[rename_b.idx] <= 0;
            end

            for(int i = 0; i < CDB_SIZE; i++) begin
                if(!cdb_arr[i].valid) continue;

                phys_file[cdb_arr[i].prf] <= cdb_arr[i].result;
                valid_list[cdb_arr[i].prf] <= 1;
            end

            if(commit_a.reg_rob.valid && commit_a.reg_rob.code == ROB_REG) begin
                free_list[commit_a.reg_rob.old_prf] <= 1;
                retire_table[commit_a.reg_rob.arch] <= commit_a.reg_rob.new_prf;
                free_retire_list[commit_a.reg_rob.old_prf] <= 1;
                free_retire_list[commit_a.reg_rob.new_prf] <= 0;
            end

            if(commit_b.reg_rob.valid && commit_b.reg_rob.code == ROB_REG) begin
                free_list[commit_b.reg_rob.old_prf] <= 1;
                retire_table[commit_b.reg_rob.arch] <= commit_b.reg_rob.new_prf;
                free_retire_list[commit_b.reg_rob.old_prf] <= 1;
                free_retire_list[commit_b.reg_rob.new_prf] <= 0;
            end
        end
    end

    always_ff @ (posedge clk) begin
        retire_override <= mispredict_signal;
    end

    always_ff @ (posedge clk) begin
        if(rst || mispredict_signal) begin
            rs_a_op <= '0;
            rs_b_op <= '0;

            rob_a_op <= '0;
            rob_b_op <= '0;
        end else begin
            rs_a_op <= rs_a;
            rs_b_op <= rs_b;

            rob_a_op <= rob_a;
            rob_b_op <= rob_b;
        end
    end

    // Free physical register finding
    always_comb begin
        free_bits = '0; free_bits_masked = '0;
        free_a = '0; found_a = 0; onehot_a = '0;
        free_b = '0; found_b = 0; onehot_b = '0;

        free_bits = free_list;
        onehot_a = free_bits & (~free_bits + 1);

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
        rs_a = '0; rob_a = '0;
        idx_as = '0; idx_at = '0; idx_ad = '0;
        value_as = '0; value_at = '0;
        check_as = 0; check_at = 0;
        rename_a = '0;

        // Valid bit should be in same position for any type of RS entry
        rs_a.int_rs.valid = (instr_a.opcode != 0); 
        rob_a.reg_rob.valid = (instr_a.opcode != 0);

        idx_as = alias_table[instr_a.reg_s];

        match_ai = cdb_arr[0].valid && (idx_as == cdb_arr[0].prf);
        match_aj = cdb_arr[1].valid && (idx_as == cdb_arr[1].prf);
        match_ak = cdb_arr[2].valid && (idx_as == cdb_arr[2].prf);

        unique case (1'b1)
            match_ai: value_as = cdb_arr[0].result;
            match_aj: value_as = cdb_arr[1].result;
            match_ak: value_as = cdb_arr[2].result;
            default:  value_as = phys_file[idx_as];
        endcase

        check_as = (match_ai || match_aj || match_ak) ? 1'b1 : valid_list[idx_as];

        idx_at = alias_table[instr_a.reg_t];

        match_ax = cdb_arr[0].valid && (idx_at == cdb_arr[0].prf);
        match_ay = cdb_arr[1].valid && (idx_at == cdb_arr[1].prf);
        match_az = cdb_arr[2].valid && (idx_at == cdb_arr[2].prf);

        unique case (1'b1)
            match_ax: value_at = cdb_arr[0].result;
            match_ay: value_at = cdb_arr[1].result;
            match_az: value_at = cdb_arr[2].result;
            default:  value_at = phys_file[idx_at];
        endcase

        check_at = (match_ax || match_ay || match_az) ? 1'b1 : valid_list[idx_at];

        idx_ad = alias_table[instr_a.reg_d];

        unique case(instr_a.opcode) inside
            [1:14] : begin
                rs_a.int_rs.opcode = instr_a.opcode;

                rs_a.int_rs.reg_s = idx_as;
                rs_a.int_rs.value_s = value_as;
                rs_a.int_rs.check_s = check_as;

                rs_a.int_rs.reg_t = idx_at;
                rs_a.int_rs.value_t = value_at;
                rs_a.int_rs.check_t = check_at;

                rob_a.reg_rob.old_prf = idx_ad;
                rob_a.reg_rob.code = ROB_REG;
                rob_a.reg_rob.arch = instr_a.reg_d;
            end

            [15:25] : begin
                rs_a.imm_rs.opcode = instr_a.opcode;

                rs_a.imm_rs.reg_s = idx_as;
                rs_a.imm_rs.value_s = value_as;
                rs_a.imm_rs.check_s = check_as;
                rs_a.imm_rs.imm = instr_a.imm;

                rob_a.reg_rob.old_prf = idx_ad;
                rob_a.reg_rob.code = ROB_REG;
                rob_a.reg_rob.arch = instr_a.reg_d;
            end

            [26:26] : begin
                rs_a.load_rs.opcode = instr_a.opcode;

                rs_a.load_rs.reg_s = idx_as;
                rs_a.load_rs.value_s = value_as;
                rs_a.load_rs.check_s = check_as;
                rs_a.load_rs.offset = instr_a.imm;
                
                rob_a.reg_rob.old_prf = idx_ad;
                rob_a.reg_rob.code = ROB_REG;
                rob_a.reg_rob.arch = instr_a.reg_d;
            end

            [27:27] : begin
                rs_a.store_rs.opcode = instr_a.opcode;        
                // reg_s position in instruction is register that has value to combine with offset for effective address
                // Flipped compared to other instructions
                rs_a.store_rs.reg_d = idx_as;
                rs_a.store_rs.value_d = value_as;
                rs_a.store_rs.check_d = check_as;

                // reg_d position in instruction is the source register of the data to put into memory
                // Flipped compared to other operations
                rs_a.store_rs.reg_s = idx_at;
                rs_a.store_rs.value_s = value_at;
                rs_a.store_rs.check_s = check_at;

                rs_a.store_rs.offset = instr_a.imm;
            end

            [28:33] : begin
                rs_a.branch_rs.opcode = instr_a.opcode;
                rs_a.branch_rs.reg_s = idx_as;
                rs_a.branch_rs.value_s = value_as;
                rs_a.branch_rs.check_s = check_as;

                rs_a.branch_rs.reg_t = idx_at;
                rs_a.branch_rs.value_t = value_at;
                rs_a.branch_rs.check_t = check_at;

                rob_a.branch_rob.recov_addr = recov_a;
                rob_a.branch_rob.hist_entry = hist_a;
                rob_a.branch_rob.predict = instr_a.code[0];
                rob_a.branch_rob.code = ROB_BRN;
            end
            
            default : begin end
        endcase

        if(found_a && (instr_a.opcode != 0) && !(instr_a.opcode inside {[27:33]})) begin
            rob_a.reg_rob.new_prf = free_a;
            rename_a.valid = 1;
            rename_a.idx = free_a;
            rename_a.arch_reg = instr_a.reg_d;
            
            unique case(instr_a.opcode) inside
                [1:14] : begin
                    rs_a.int_rs.dest = free_a;
                end
                [15:25] : begin
                    rs_a.imm_rs.dest = free_a;
                end
                [26:26] : begin
                    rs_a.load_rs.dest = free_a;
                end
                default : begin end
            endcase
        end
    end

    always_comb begin
        rs_b = '0; rob_b = '0;
        idx_bs = '0; idx_bt = '0; idx_bd = '0;
        value_bs = '0; value_bt = '0;
        check_bs = 0; check_bt = 0;
        rename_b = '0;

        // Valid bit should be in same position for any type of RS entry
        rs_b.int_rs.valid = (instr_b.opcode != 0); 
        rob_b.reg_rob.valid = (instr_b.opcode != 0);

        // Only match against instr_a if it actually renames a destination register
        // (stores 27, branches 28-33, jumps & invalid ops leave reg_d meaningless);
        // matching a non-renaming instr_a would point instr_b at free_a, which is
        // never written -> check bit stuck at 0 -> deadlock
        s_match = (instr_b.reg_s == instr_a.reg_d) && (instr_a.opcode inside {[1:26]}) && found_a;
        t_match = (instr_b.reg_t == instr_a.reg_d) && (instr_a.opcode inside {[1:26]}) && found_a;
        d_match = (instr_b.reg_d == instr_a.reg_d) && (instr_a.opcode inside {[1:26]}) && found_a;

        idx_bs = s_match ? free_a : alias_table[instr_b.reg_s];

        match_bi = !s_match && cdb_arr[0].valid && (idx_bs == cdb_arr[0].prf);
        match_bj = !s_match && cdb_arr[1].valid && (idx_bs == cdb_arr[1].prf);
        match_bk = !s_match && cdb_arr[2].valid && (idx_bs == cdb_arr[2].prf);

        unique case (1'b1)
            match_bi: value_bs = cdb_arr[0].result;
            match_bj: value_bs = cdb_arr[1].result;
            match_bk: value_bs = cdb_arr[2].result;
            default:  value_bs = phys_file[idx_bs];
        endcase

        check_bs = s_match ? 1'b0
            : (match_bi || match_bj || match_bk) ? 1'b1
            : valid_list[idx_bs];


        idx_bt = t_match ? free_a : alias_table[instr_b.reg_t];

        match_bx = !t_match && cdb_arr[0].valid && (idx_bt == cdb_arr[0].prf);
        match_by = !t_match && cdb_arr[1].valid && (idx_bt == cdb_arr[1].prf);
        match_bz = !t_match && cdb_arr[2].valid && (idx_bt == cdb_arr[2].prf);

        unique case (1'b1)
            match_bx: value_bt = cdb_arr[0].result;
            match_by: value_bt = cdb_arr[1].result;
            match_bz: value_bt = cdb_arr[2].result;
            default:  value_bt = phys_file[idx_bt];
        endcase

        check_bt = t_match ? 1'b0
            : (match_bx || match_by || match_bz) ? 1'b1
            : valid_list[idx_bt];

        idx_bd = d_match ? free_a : alias_table[instr_b.reg_d];

        unique case(instr_b.opcode) inside
            [1:14] : begin
                rs_b.int_rs.opcode = instr_b.opcode;
    
                rs_b.int_rs.reg_s = idx_bs;
                rs_b.int_rs.value_s = value_bs;
                rs_b.int_rs.check_s = check_bs;

                rs_b.int_rs.reg_t = idx_bt;
                rs_b.int_rs.value_t = value_bt;
                rs_b.int_rs.check_t = check_bt;

                rob_b.reg_rob.old_prf = idx_bd;
                rob_b.reg_rob.code = ROB_REG;
                rob_b.reg_rob.arch = instr_b.reg_d;
            end

            [15:25] : begin
                rs_b.imm_rs.opcode = instr_b.opcode;

                rs_b.imm_rs.reg_s = idx_bs;
                rs_b.imm_rs.value_s = value_bs;
                rs_b.imm_rs.check_s = check_bs;
                rs_b.imm_rs.imm = instr_b.imm;

                rob_b.reg_rob.old_prf = idx_bd;
                rob_b.reg_rob.code = ROB_REG;
                rob_b.reg_rob.arch = instr_b.reg_d;
            end

            [26:26] : begin
                rs_b.load_rs.opcode = instr_b.opcode;

                rs_b.load_rs.reg_s = idx_bs;
                rs_b.load_rs.value_s = value_bs;
                rs_b.load_rs.check_s = check_bs;
                rs_b.load_rs.offset = instr_b.imm;

                rob_b.reg_rob.old_prf = idx_bd;
                rob_b.reg_rob.code = ROB_REG;
                rob_b.reg_rob.arch = instr_b.reg_d;
            end

            [27:27] : begin
                rs_b.store_rs.opcode = instr_b.opcode;
                // reg_s position in instruction is register that has value to combine with offset for effective address
                // Flipped compared to other instructions

                rs_b.store_rs.reg_d = idx_bs;
                rs_b.store_rs.value_d = value_bs;
                rs_b.store_rs.check_d = check_bs;

                // reg_d position in instruction is the source register of the data to put into memory
                // Flipped compared to other operations

                rs_b.store_rs.reg_s = idx_bt;
                rs_b.store_rs.value_s = value_bt;
                rs_b.store_rs.check_s = check_bt;

                rs_b.store_rs.offset = instr_b.imm;
            end

            [28:33] : begin
                rs_b.branch_rs.opcode = instr_b.opcode;
    
                rs_b.branch_rs.reg_s = idx_bs;
                rs_b.branch_rs.value_s = value_bs;
                rs_b.branch_rs.check_s = check_bs;

                rs_b.branch_rs.reg_t = idx_bt;
                rs_b.branch_rs.value_t = value_bt;
                rs_b.branch_rs.check_t = check_bt;

                rob_b.branch_rob.recov_addr = recov_b;
                rob_b.branch_rob.hist_entry = hist_b;
                rob_b.branch_rob.predict = instr_b.code[0];
                rob_b.branch_rob.code = ROB_BRN;
            end
            
            default : begin end
        endcase

        if(found_b && (instr_b.opcode != 0) && !(instr_b.opcode inside {[27:33]})) begin
            rob_b.reg_rob.new_prf = free_b;
            rename_b.valid = 1;
            rename_b.idx = free_b;
            rename_b.arch_reg = instr_b.reg_d;

            unique case(instr_b.opcode) inside
                [1:14] : begin
                    rs_b.int_rs.dest = free_b;
                end
                [15:25] : begin
                    rs_b.imm_rs.dest = free_b;
                end
                [26:26] : begin
                    rs_b.load_rs.dest = free_b;
                end
                default : begin end
            endcase
        end
    end

    assign last_arch_reg = phys_file[alias_table[NUM_ARCH_REGS-1]][3:0];
endmodule
