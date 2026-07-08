`timescale 1ns / 1ps

import config_pkg::*;

module alu(
    input logic [31:0] input1,
    input logic [31:0] input2,
    input logic [5:0] opcode,
    
    output logic [31:0] result
);

    always_comb begin
        unique case(opcode)
            ALU_ADD: result = input1 + input2;
            ALU_SUB: result = input1 - input2;
            ALU_LSHIFT: result = input1 << input2[5:0];
            ALU_RSHIFT: result = input1 >> input2[5:0];
            ALU_EQ: result = input1 == input2;
            ALU_GTE: result = input1 >= input2;
            ALU_LTE: result = input1 <= input2;
            ALU_GT: result = input1 > input2;
            ALU_LT: result = input1 < input2;
            ALU_AND: result = input1 & input2;
            ALU_OR: result = input1 | input2;
            ALU_NOR: result = ~(input1 | input2);
            ALU_NAND: result = ~(input1 & input2);
            ALU_XOR: result = input1 ^ input2;
            default: result = 0;
        endcase
    end
endmodule
