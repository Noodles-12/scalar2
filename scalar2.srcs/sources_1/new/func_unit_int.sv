`timescale 1ns / 1ps

import config_pkg::*;

module func_unit_int(
    input logic clk,
    input logic rst,
    input int_rs_entry int_instr_a,
    input int_rs_entry int_instr_b,
    
    output cdb_entry out_a,
    output cdb_entry out_b
);

    logic [31:0] result_a, result_b;

    alu alu_a(.input1(int_instr_a.value_s),
              .input2(int_instr_a.value_t),
              .opcode(int_instr_a.opcode),
              .result(result_a) );

    alu alu_b(.input1(int_instr_b.value_s),
              .input2(int_instr_b.value_t),
              .opcode(int_instr_b.opcode),
              .result(result_b) );

    always_ff @ (posedge clk) begin
        if (rst) begin
            out_a <= '0;
            out_b <= '0;
        end else begin
            if (int_instr_a.valid) begin
                out_a.valid <= 1;
                out_a.result <= result_a;
                out_a.id <= int_instr_a.id;
                out_a.prf <= int_instr_a.dest;
            end else
                out_a <= '0;

            if (int_instr_b.valid) begin
                out_b.valid <= 1;
                out_b.result <= result_b;
                out_b.id <= int_instr_b.id;
                out_b.prf <= int_instr_b.dest;
            end else
                out_b <= '0;
        end
    end

endmodule
