`timescale 1ns / 1ps

import config_pkg::*;

module alu_imm(input1, imm, opcode, result);
    input [0:35] input1;
    input [0:11] imm;
    input [0:5] opcode;
    output logic [0:35] result;

    logic [0:35] imm_extended;
    assign imm_extended = {24'b0, imm};

    always_comb begin
        case(opcode)
            16: result = input1 + imm_extended;          // addi
            17: result = input1 - imm_extended;          // subi
            18: result = input1 >> imm_extended[30:35];  // rshi
            19: result = input1 << imm_extended[30:35];  // lshi
            20: result = input1 & imm_extended;          // andi
            21: result = input1 | imm_extended;          // ori
            22: result = input1 == imm_extended;         // eqi
            23: result = input1 >= imm_extended;         // gtei
            24: result = input1 <= imm_extended;         // ltei
            25: result = input1 >  imm_extended;         // gti
            26: result = input1 <  imm_extended;         // lti
            default: result = 0;
        endcase
    end
endmodule