`timescale 1ns / 1ps

import config_pkg::*;

module func_unit_imm(
    input logic clk,
    input logic rst,
    input imm_rs_entry imm_instr_a,
    input imm_rs_entry imm_instr_b,

    output cdb_entry out_a,
    output cdb_entry out_b
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
        if (rst) begin
            out_a <= '0;
            out_b <= '0;
        end else begin
            out_a.result <= result_a;
            out_a.id <= imm_instr_a.id;
            out_a.prf <= imm_instr_a.dest;

            out_b.result <= result_b;
            out_b.id <= imm_instr_b.id;
            out_b.prf <= imm_instr_b.dest;
        end
    end
endmodule
