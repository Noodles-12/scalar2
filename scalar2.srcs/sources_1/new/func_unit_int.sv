`timescale 1ns / 1ps

import config_pkg::*;

module func_unit_int(clk,
                     int_instr_a, result_a, id_a, dest_a,
                     int_instr_b, result_b, id_b, dest_b);
    input logic clk;
    input int_rs_entry int_instr_a, int_instr_b;
    
    output logic [0:35] result_a, result_b;
    output logic [0:5]  id_a, id_b;
    output logic [0:4]  dest_a, dest_b;

    logic [0:35] result_a_comb, result_b_comb;

    alu alu_a(.input1(int_instr_a.value1),
              .input2(int_instr_a.value2),
              .opcode(int_instr_a.opcode),
              .result(result_a_comb) );

    alu alu_b(.input1(int_instr_b.value1),
              .input2(int_instr_b.value2),
              .opcode(int_instr_b.opcode),
              .result(result_b_comb) );

    always_ff @ (posedge clk) begin
        result_a <= result_a_comb;
        id_a     <= int_instr_a.id;
        dest_a   <= int_instr_a.dest;

        result_b <= result_b_comb;
        id_b     <= int_instr_b.id;
        dest_b   <= int_instr_b.dest;
    end
endmodule
