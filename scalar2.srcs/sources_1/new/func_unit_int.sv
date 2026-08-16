`timescale 1ns / 1ps

import config_pkg::*;

module func_unit_int(
    input logic clk,
    input logic rst,
    input logic mispredict_signal,
    input int_rs_entry int_instr_a,
    input int_rs_entry int_instr_b,

    output cdb_entry cdb_result_a,
    output cdb_entry cdb_result_b
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
        if (rst || mispredict_signal) begin
            cdb_result_a <= '0;
        end else begin
            if (int_instr_a.valid) begin
                cdb_result_a.valid <= 1;
                cdb_result_a.result <= result_a;
                cdb_result_a.id <= int_instr_a.id;
                cdb_result_a.prf <= int_instr_a.dest;
            end else
                cdb_result_a <= '0;
        end
    end

    always_ff @ (posedge clk) begin
        if (rst || mispredict_signal) begin
            cdb_result_b <= '0;
        end else begin
            if (int_instr_b.valid) begin
                cdb_result_b.valid <= 1;
                cdb_result_b.result <= result_b;
                cdb_result_b.id <= int_instr_b.id;
                cdb_result_b.prf <= int_instr_b.dest;
            end else
                cdb_result_b <= '0;
        end
    end
endmodule
