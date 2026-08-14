`timescale 1ns / 1ps

import config_pkg::*;

module controller(
    input logic clk,
    input instr_code code_a,
    input instr_code code_b,
    input logic [11:0] target_a,
    input logic [11:0] target_b,
    input logic [11:0] curr_pc,
    input logic mispredict_signal,
    input logic [11:0] recov_addr,

    input logic rs_int_full,
    input logic rs_imm_full,
    input logic rs_branch_full,
    input logic rs_mem_full,
    input logic rob_full,
    input logic reg_file_full,

    output logic predict_flush,
    output logic mispredict_flush_rob,
    output logic mispredict_flush_rs,
    output logic mispredict_flush_reg,
    output logic [11:0] next_pc,
    output logic enable
);
    logic [1:0] pc_sel;

    assign enable = !(rs_int_full || rs_imm_full || rs_branch_full ||
                       rs_mem_full || rob_full || reg_file_full);

    always_comb begin
        predict_flush = 1'b0;

        if(code_a[0] || code_b[0]) begin
            predict_flush = 1'b1;
        end
    end

    always_comb begin
        mispredict_flush_rob = mispredict_signal;
    end

    always_ff @ (posedge clk) begin
        mispredict_flush_rs  <= mispredict_signal;
        mispredict_flush_reg <= mispredict_signal;
    end

    always_comb begin
        if (mispredict_signal)
            pc_sel = 2'b11;                          // recov_addr
        else if (code_a == TAKEN_BRANCH || code_a == JUMP)
            pc_sel = 2'b01;                          // target_a
        else if (code_b == TAKEN_BRANCH || code_b == JUMP)
            pc_sel = 2'b10;                          // target_b
        else
            pc_sel = 2'b00;                          // curr_pc + 1
    end

    always_comb begin
        unique case(pc_sel)
            2'b00: next_pc = curr_pc + 2;
            2'b01: next_pc = target_a;
            2'b10: next_pc = target_b;
            2'b11: next_pc = recov_addr;
        endcase
    end

endmodule
