`timescale 1ns / 1ps

// Can probably optimize space regarding result & extended result
import config_pkg::*;
// Include CarryOut & 
module alu(input1, input2, opcode, result, is_zero, carry_out, neg);
    input [0:35] input1;
    input [0:35] input2;
    input [0:5] opcode;
    
    output logic [0:35] result;
    output logic is_zero;
    output logic carry_out;
    output logic neg;
    
    logic [0:36] extended_result;
    
    assign is_zero = (result == 0);
    assign neg = (result < 0);
    assign carry_out = extended_result[0];
    
    // Case check just for carry_out
    always_comb begin
        case(opcode)
            ALU_ADD: extended_result <= {1'b0, input1} + {1'b0, input2};
            ALU_SUB: extended_result <= {1'b0, input1} - {1'b0, input2};
            default: extended_result <= 0;
        endcase
    end
    
    always_comb begin
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
