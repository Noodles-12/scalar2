`timescale 1ns / 1ps

import config_pkg::*;

module comparator(
    input logic [31:0] input1,
    input logic [31:0] input2,
    input logic [5:0] opcode,

    output logic result
);
    always_comb begin
        unique case(comp_opcode'(opcode))
            COMP_EQ: result = (input1 == input2);
            COMP_NE: result = (input1 != input2);
            COMP_GE: result = ($signed(input1) >= $signed(input2));
            COMP_LT: result = ($signed(input1) < $signed(input2));
            COMP_GEU: result = (input1 >= input2);
            COMP_LTU: result = (input1 < input2);
        endcase
    end
endmodule
