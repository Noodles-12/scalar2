`timescale 1ns / 1ps

import config_pkg::*;

module dependency_resolver(
    input logic clk,
    input logic rst,
    input logic mispredict_flush,
    input logic enable,
    input instruction instr_a,
    input instruction instr_b,
    input logic [11:0] recov_a,
    input logic [11:0] recov_b,
    input logic [4:0] hist_a,
    input logic [4:0] hist_b,
    input logic [1:0] imm_lo_a,
    input logic [1:0] imm_lo_b,

    output instruction instr_a_op,
    output instruction instr_b_op,
    output logic [11:0] recov_addr_a,
    output logic [11:0] recov_addr_b,
    output logic [4:0] hist_a_op,
    output logic [4:0] hist_b_op,
    output logic [1:0] imm_lo_a_op,
    output logic [1:0] imm_lo_b_op
);
    instr_code code_a, code_b;

    assign code_a = instr_a.code;
    assign code_b = instr_b.code;

    always_ff @ (posedge clk) begin
        if(rst || mispredict_flush) begin
            instr_a_op <= '0;
            instr_b_op <= '0;

            recov_addr_a <= '0;
            recov_addr_b <= '0;

            hist_a_op <= '0;
            hist_b_op <= '0;

            imm_lo_a_op <= '0;
            imm_lo_b_op <= '0;
        end else if(enable) begin
            // Flushing out any jumps
            // Testing not including flush conditions for recovery & hist entry for both instructions
            instr_a_op <= (code_a == JUMP) ? '0 : instr_a;
            recov_addr_a <= recov_a;
            hist_a_op <= hist_a;
            imm_lo_a_op <= (code_a == JUMP) ? '0 : imm_lo_a;

            // code_a[0] being 1 represents if instr_a is taken branch or jump
            instr_b_op <= (code_a[0] || code_b == JUMP) ? '0 : instr_b;
            recov_addr_b <= recov_b;
            hist_b_op <= hist_b;
            imm_lo_b_op <= (code_a[0] || code_b == JUMP) ? '0 : imm_lo_b;
        end
    end
endmodule
