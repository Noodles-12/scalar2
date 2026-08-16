`timescale 1ns / 1ps

import config_pkg::*;

module branch_predictor(
    input logic rst,
    input logic clk,
    input logic predict_flush,
    input logic mispredict_flush,
    input logic enable,
    input instruction instr_a,
    input logic [11:0] addr_a,
    input instruction instr_b,
    input logic [11:0] addr_b,
    input rob_entry commit_a,
    input rob_entry commit_b,
    
    output instruction instr_a_op,
    output instruction instr_b_op,
    output logic [11:0] predict_addr_a,
    output logic [11:0] predict_addr_b,
    output logic [11:0] recov_addr_a,
    output logic [11:0] recov_addr_b,
    output logic [4:0] hist_a,
    output logic [4:0] hist_b,
    output logic [1:0] imm_lo_a,
    output logic [1:0] imm_lo_b
);
    logic [1:0] history_table [0:31];
    
    instr_code code_a, code_b;
    logic [1:0] predict_a, predict_b;
    instruction mod_instr_a, mod_instr_b;

    logic [1:0] curr_state_a, curr_state_b;
    logic [1:0] next_state_a, next_state_b;

    logic [11:0] taken_a, taken_b;
    logic [11:0] return_a, return_b;

    assign taken_a = instr_a.imm;
    assign taken_b = instr_b.imm;
    assign return_a = addr_a + 1;
    assign return_b = addr_b + 1;

    always_ff @ (posedge clk) begin
        if(rst || mispredict_flush) begin
            instr_a_op <= '0;
            instr_b_op <= '0;

            predict_addr_a <= '0;
            predict_addr_b <= '0;

            recov_addr_a <= '0;
            recov_addr_b <= '0;

            hist_a <= '0;
            hist_b <= '0;

            imm_lo_a <= '0;
            imm_lo_b <= '0;
        end else if(enable) begin
            if(predict_flush) begin
                instr_a_op <= '0;
                instr_b_op <= '0;

                predict_addr_a <= '0;
                predict_addr_b <= '0;

                recov_addr_a <= '0;
                recov_addr_b <= '0;

                hist_a <= '0;
                hist_b <= '0;

                imm_lo_a <= '0;
                imm_lo_b <= '0;
            end else begin
                instr_a_op <= mod_instr_a;
                instr_b_op <= mod_instr_b;

                hist_a <= addr_a[4:0];
                hist_b <= addr_b[4:0];

                imm_lo_a <= instr_a.code;
                imm_lo_b <= instr_b.code;

                unique case(code_a)
                    NORMAL:         predict_addr_a <= '0;
                    JUMP:           predict_addr_a <= taken_a;
                    UNTAKEN_BRANCH: predict_addr_a <= return_a;
                    TAKEN_BRANCH:   predict_addr_a <= taken_a;
                    default:        predict_addr_a <= '0;
                endcase

                unique case(code_a)
                    NORMAL:         recov_addr_a <= '0;
                    JUMP:           recov_addr_a <= '0;
                    UNTAKEN_BRANCH: recov_addr_a <= taken_a;
                    TAKEN_BRANCH:   recov_addr_a <= return_a;
                    default:        recov_addr_a <= '0;
                endcase

                unique case(code_b)
                    NORMAL:         predict_addr_b <= '0;
                    JUMP:           predict_addr_b <= taken_b;
                    UNTAKEN_BRANCH: predict_addr_b <= return_b;
                    TAKEN_BRANCH:   predict_addr_b <= taken_b;
                    default:        predict_addr_b <= '0;
                endcase

                unique case(code_b)
                    NORMAL:         recov_addr_b <= '0;
                    JUMP:           recov_addr_b <= '0;
                    UNTAKEN_BRANCH: recov_addr_b <= taken_b;
                    TAKEN_BRANCH:   recov_addr_b <= return_b;
                    default:        recov_addr_b <= '0;
                endcase
            end
        end
    end

    always_ff @ (posedge clk) begin
        if(rst) begin
            history_table <= '{default: 2'b10};
        end else begin
            // Only yield the write port to commit_b when b is actually a valid branch
            // commit to the same entry; otherwise an invalid commit_b (all zeros)
            // would block every branch that hashes to entry 0 from ever training
            if(commit_a.reg_rob.valid && commit_a.reg_rob.code == ROB_BRN
            && !(commit_b.reg_rob.valid && commit_b.reg_rob.code == ROB_BRN
                 && commit_a.branch_rob.hist_entry == commit_b.branch_rob.hist_entry)) begin
                history_table[commit_a.branch_rob.hist_entry] <= next_state_a;
            end
            
            if(commit_b.reg_rob.valid && commit_b.reg_rob.code == ROB_BRN) begin
                history_table[commit_b.branch_rob.hist_entry] <= next_state_b;
            end
        end
    end

    // Instruction A code
    always_comb begin
        predict_a = history_table[addr_a[4:0]];

        unique case(instr_a.opcode) inside
            [1:27] : begin
                code_a = NORMAL;
            end
            
            [28:33] : begin
                if(predict_a > 2'b01) begin
                    code_a = TAKEN_BRANCH;
                end else begin
                    code_a = UNTAKEN_BRANCH;
                end
            end
            
            [34:34] : begin
                code_a = JUMP;
            end
            default: code_a = NORMAL;
        endcase

        mod_instr_a = instr_a;
        mod_instr_a.code = code_a;
    end
    
    // Instruction B code
    always_comb begin
        predict_b = history_table[addr_b[4:0]];

        unique case(instr_b.opcode) inside
            [1:27] : begin
                code_b = NORMAL;
            end
            
            [28:33] : begin
                if(predict_b > 2'b01) begin
                    code_b = TAKEN_BRANCH;
                end else begin
                    code_b = UNTAKEN_BRANCH;
                end
            end
            
            [34:34] : begin
                code_b = JUMP;
            end
            default: code_b = NORMAL;
        endcase

        mod_instr_b = instr_b;
        mod_instr_b.code = code_b;
    end

    always_comb begin
        curr_state_a = history_table[commit_a.branch_rob.hist_entry];

        if(commit_a.branch_rob.actual) begin
            next_state_a = (curr_state_a == 2'b11) ? 2'b11 : curr_state_a + 1;
        end else begin
            next_state_a = (curr_state_a == 2'b00) ? 2'b00 : curr_state_a - 1;
        end
    end

    always_comb begin
        curr_state_b = history_table[commit_b.branch_rob.hist_entry];

        if(commit_b.branch_rob.actual) begin
            next_state_b = (curr_state_b == 2'b11) ? 2'b11 : curr_state_b + 1;
        end else begin
            next_state_b = (curr_state_b == 2'b00) ? 2'b00 : curr_state_b - 1;
        end
    end
endmodule
