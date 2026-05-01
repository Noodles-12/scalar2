`timescale 1ns / 1ps

import config_pkg::*;

module func_unit_imm(clk, imm_instr_a, out_a,
                     imm_instr_b, out_b);
    input logic clk;
    input  imm_rs_entry imm_instr_a, imm_instr_b;
    output cdb_entry out_a, out_b;

    imm_rs_entry instr_a_reg, instr_b_reg;

    logic [0:35] result_a_comb, result_b_comb;

    alu alu_a(.input1(instr_a_reg.value),
              .input2({24'b0, instr_a_reg.imm}),
              .opcode(instr_a_reg.opcode - 15),
              .result(result_a_comb) );

    alu alu_b(.input1(instr_b_reg.value),
              .input2({24'b0, instr_b_reg.imm}),
              .opcode(instr_b_reg.opcode - 15),
              .result(result_b_comb) );

    always_ff @ (posedge clk) begin
        instr_a_reg <= imm_instr_a;
        instr_b_reg <= imm_instr_b;
    end

    assign out_a.result = result_a_comb;
    assign out_a.id     = instr_a_reg.id;
    assign out_a.prf    = instr_a_reg.dest;

    assign out_b.result = result_b_comb;
    assign out_b.id     = instr_b_reg.id;
    assign out_b.prf    = instr_b_reg.dest;
endmodule
