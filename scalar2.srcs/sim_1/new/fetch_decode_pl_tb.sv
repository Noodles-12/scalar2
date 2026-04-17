`timescale 1ns / 1ps

module fetch_decode_pl_tb();
    logic clk;
    logic [0:29] instr_a;
    logic [0:29] instr_b;
    logic [0:5] opcode_a;
    logic [0:5] opcode_b;

    fetch_decode_pl fd(.clk(clk),
                       .instr_a(instr_a),
                       .instr_b(instr_b),
                       .opcode_a(opcode_a),
                       .opcode_b(opcode_b) );
                       
    initial clk = 0;
    always #5 clk = ~clk;
    
    initial begin
        instr_a = 30'b0000010000000000000000000000000; instr_b = 30'b0000010000000000000000000000000; # 10;
        instr_a = 30'b0000100000000000000000000000000; instr_b = 30'b0000110000000000000000000000000; # 10;
        instr_a = 30'b0001000000000000000000000000000; instr_b = 30'b0001110000000000000000000000000; # 10;
        instr_a = 30'b0001000000000000000000000000000; instr_b = 30'b0001110000000000000000000000000; # 10;
        $finish;
    end
                  
endmodule
