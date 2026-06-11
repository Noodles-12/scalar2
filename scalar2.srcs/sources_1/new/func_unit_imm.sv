`timescale 1ns / 1ps

import config_pkg::*;

module func_unit_imm(
    input logic clk,
    input logic rst,
    input imm_rs_entry imm_instr,

    output cdb_entry cdb_result
);
    logic [31:0] result;

    alu_imm alu_a(.input1(imm_instr.value_s),
                  .imm(imm_instr.imm),
                  .opcode(imm_instr.opcode),
                  .result(result) );

    // Testing to see if checking for invalid instruction even matters
    always_ff @ (posedge clk) begin
        if (rst) begin
            cdb_result <= '0;
        end else begin
            if(imm_instr.valid) begin
                cdb_result.valid <= 1;
                cdb_result.result <= result;
                cdb_result.id <= imm_instr.id;
                cdb_result.prf <= imm_instr.dest;
            end else
                cdb_result <= '0;
        end
    end
endmodule
