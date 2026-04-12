`timescale 1ns / 1ps

import config_pkg::*;

module alu(input1, input2, opcode, result, is_zero);
    input [0:36] input1;
    input [0:36] input2;
    input [0:5] opcode;
    
    output logic [0:36] result;
    output logic is_zero;
    
    assign is_zero = (result == 0);
    
    always @ (*) begin
        case(opcode)
            ALU_ADD:  result <= input1 + input2;
            ALU_SUB:  result <= input1 - input2;
            ALU_LSHIFT: result <= input1 << input2;
            ALU_RSHIFT: result <= input1 >> input2;
            ALU_MOD:  result <= input1 % input2;
            ALU_EQ:   result <= input1 == input2;
            ALU_GTE:  result <= input1 >= input2;
            ALU_LTE:  result <= (input1 <= input2);
            ALU_GT:   result <= input1 > input2;
            ALU_LT:   result <= input1 < input2;
            ALU_AND:  result <= input1 & input2;
            ALU_OR:   result <= input1 | input2;
            ALU_NOR:  result <= ~(input1 | input2);
            ALU_NAND: result <= ~(input1 & input2);
            ALU_XOR:  result <= input1 ^ input2;
        default:  result <= 0;
    endcase
    end
endmodule
