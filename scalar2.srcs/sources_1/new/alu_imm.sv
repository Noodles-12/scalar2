`timescale 1ns / 1ps

import config_pkg::*;

module alu_imm(input1, imm, opcode, result);
    input [31:0] input1;
    input [11:0] imm;
    input [5:0] opcode;
    output logic [31:0] result;

    logic [31:0] imm_extended;
    assign imm_extended = {20'b0, imm};

    always_comb begin
        unique case(ialu_opcode'(opcode))
            IALU_ADD:  result = input1 + imm_extended;          // addi
            IALU_SUB:  result = input1 - imm_extended;          // subi
            IALU_RSHI: result = input1 >> imm_extended[5:0];    // rshi
            IALU_LSHI: result = input1 << imm_extended[5:0];    // lshi
            IALU_AND:  result = input1 & imm_extended;          // andi
            IALU_OR:   result = input1 | imm_extended;          // ori
            IALU_EQ:   result = input1 == imm_extended;         // eqi
            IALU_GTE:  result = input1 >= imm_extended;         // gtei
            IALU_LTE:  result = input1 <= imm_extended;         // ltei
            IALU_GT:   result = input1 > imm_extended;          // gti
            IALU_LT:   result = input1 < imm_extended;          // lti
            default: result = 0;
        endcase
    end
endmodule