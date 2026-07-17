`timescale 1ns / 1ps

import config_pkg::*;

module func_unit_int(
    input logic clk,
    input logic rst,
    input logic mispredict_signal,
    input int_rs_entry int_instr,
    
    output cdb_entry cdb_result 
);
    logic [31:0] result;

    alu alu_a(.input1(int_instr.value_s),
              .input2(int_instr.value_t),
              .opcode(int_instr.opcode),
              .result(result) );

    always_ff @ (posedge clk) begin
        if (rst || mispredict_signal) begin
            cdb_result <= '0;
        end else begin
            if (int_instr.valid) begin
                cdb_result.valid <= 1;
                cdb_result.result <= result;
                cdb_result.id <= int_instr.id;
                cdb_result.prf <= int_instr.dest;
            end else
                cdb_result <= '0;
        end
    end
endmodule