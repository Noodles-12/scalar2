`timescale 1ns / 1ps

import config_pkg::*;

module func_unit_imm(clk,
                     imm_instr_a, result_a, id_a, dest_a,
                     imm_instr_b, result_b, id_b, dest_b);
    input  logic clk;
    input  imm_rs_entry imm_instr_a, imm_instr_b;
    output logic [0:35] result_a, result_b;
    output logic [0:5]  id_a, id_b;
    output logic [0:4]  dest_a, dest_b;

    logic [0:35] result_a_comb, result_b_comb;

    alu alu_a(.input1(imm_instr_a.value),
              .input2({24'b0, imm_instr_a.imm}), // Zero extended for ALU
              .opcode(imm_instr_a.opcode),
              .result(result_a_comb) );

    alu alu_b(.input1(imm_instr_b.value),
              .input2({24'b0, imm_instr_b.imm}),
              .opcode(imm_instr_b.opcode),
              .result(result_b_comb) );

    always_ff @ (posedge clk) begin
        result_a <= result_a_comb;
        id_a     <= imm_instr_a.id;
        dest_a   <= imm_instr_a.dest;

        result_b <= result_b_comb;
        id_b     <= imm_instr_b.id;
        dest_b   <= imm_instr_b.dest;
    end
endmodule
