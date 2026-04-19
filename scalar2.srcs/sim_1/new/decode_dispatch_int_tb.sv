`timescale 1ns / 1ps

import config_pkg::*;

module decode_dispatch_int_tb();
    logic [0:29] instr_a;
    logic [0:29] instr_b;
    logic clk;
    
    logic [0:5] opcode_a;
    logic [0:3] instr_dest_a;
    logic [0:3] instr_src1_a;
    logic [0:3] instr_src2_a;
    
    logic [0:5] opcode_b;
    logic [0:3] instr_dest_b;
    logic [0:3] instr_src1_b;
    logic [0:3] instr_src2_b;
    
    decode_dispatch_int ddi(.instr_a(instr_a),
                            .instr_b(instr_b),
                            .clk(clk),
                            .opcode_a(opcode_a),
                            .instr_dest_a(instr_dest_a),
                            .instr_src1_a(instr_src1_a),
                            .instr_src2_a(instr_src2_a),
                            .opcode_b(opcode_b),
                            .instr_dest_b(instr_dest_b),
                            .instr_src1_b(instr_src1_b),
                            .instr_src2_b(instr_src2_b) );
    initial clk = 0;
    always #5 clk = ~clk;
         
    initial begin
        instr_a = 30'b000000000000_0011_0010_0001_000001; 
        instr_b = 30'b000000000000_0011_1000_0100_000011; #10;
    
        instr_a = 30'b000000000000_0011_0110_1011_000010; 
        instr_b = 30'b000000000000_0101_1001_1101_000001; #10;
    
        instr_a = 30'b000000000000_0110_0001_0011_000100; 
        instr_b = 30'b000000000000_1100_1000_0010_000111; #10;
    
        instr_a = 30'b000000000000_1001_0111_0101_001000; 
        instr_b = 30'b000000000000_1010_1110_1111_001111; #10;
        $finish;
    end
endmodule
