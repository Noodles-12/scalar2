`timescale 1ns / 1ps

import config_pkg::*;

module func_unit_imm(
    input logic clk,
    input logic rst,
    input logic mispredict_signal,
    input imm_rs_entry imm_instr_a,
    input imm_rs_entry imm_instr_b,

    output cdb_entry cdb_result_a,
    output cdb_entry cdb_result_b
);
    logic [31:0] result_a, result_b;

    alu_imm alu_a(.input1(imm_instr_a.value_s),
                  .imm(imm_instr_a.imm),
                  .opcode(imm_instr_a.opcode),
                  .result(result_a) );

    alu_imm alu_b(.input1(imm_instr_b.value_s),
                  .imm(imm_instr_b.imm),
                  .opcode(imm_instr_b.opcode),
                  .result(result_b) );

    always_ff @ (posedge clk) begin
        if (rst || mispredict_signal) begin
            cdb_result_a <= '0;
        end else begin
            if(imm_instr_a.valid) begin
                cdb_result_a.valid <= 1;
                cdb_result_a.result <= result_a;
                cdb_result_a.id <= imm_instr_a.id;
                cdb_result_a.prf <= imm_instr_a.dest;
            end else
                cdb_result_a <= '0;
        end
    end

    always_ff @ (posedge clk) begin
        if (rst || mispredict_signal) begin
            cdb_result_b <= '0;
        end else begin
            if(imm_instr_b.valid) begin
                cdb_result_b.valid <= 1;
                cdb_result_b.result <= result_b;
                cdb_result_b.id <= imm_instr_b.id;
                cdb_result_b.prf <= imm_instr_b.dest;
            end else
                cdb_result_b <= '0;
        end
    end
endmodule
