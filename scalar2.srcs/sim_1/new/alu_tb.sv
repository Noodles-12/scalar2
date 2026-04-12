`timescale 1ns / 1ps

module alu_tb();
    reg [0:36] input1;
    reg [0:36] input2;
    reg [0:5] opcode;
    
    reg [0:36] result;
    reg is_zero;
    
    alu alu1(.input1(input1),
             .input2(input2),
             .opcode(opcode),
             .result(result),
             .is_zero(is_zero) );
             
    initial begin
        input1 = 2; input2 = 2; opcode = 1; #10; // 2 + 2 = 4 | 0
        input1 = 0; input2 = 0; opcode = 1; #10; // 0 + 0 = 0 | 1
        
        input1 = 5; input2 = 2; opcode = 2; #10;
        input1 = 2; input2 = 2; opcode = 3; #10;
        $finish;
    end
endmodule
