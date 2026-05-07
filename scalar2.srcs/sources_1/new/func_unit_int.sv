`timescale 1ns / 1ps

import config_pkg::*;

module func_unit_int(clk, rst, int_instr_a, out_a,
                     int_instr_b, out_b);
    input logic clk, rst;
    input  int_rs_entry int_instr_a, int_instr_b;
    output cdb_entry out_a, out_b;

    int_rs_entry instr_a_reg, instr_b_reg;

    logic [0:35] result_a_comb, result_b_comb;

    alu alu_a(.input1(instr_a_reg.value1),
              .input2(instr_a_reg.value2),
              .opcode(instr_a_reg.opcode),
              .result(result_a_comb) );

    alu alu_b(.input1(instr_b_reg.value1),
              .input2(instr_b_reg.value2),
              .opcode(instr_b_reg.opcode),
              .result(result_b_comb) );
    
    always_ff @ (posedge clk) begin
        if (rst) begin
            instr_a_reg <= '0;
            instr_b_reg <= '0;
        end else begin
            instr_a_reg <= int_instr_a;
            instr_b_reg <= int_instr_b;
        end
    end

    assign out_a.result = result_a_comb;
    assign out_a.id     = instr_a_reg.id;
    assign out_a.prf    = instr_a_reg.dest;

    assign out_b.result = result_b_comb;
    assign out_b.id     = instr_b_reg.id;
    assign out_b.prf    = instr_b_reg.dest;
endmodule
