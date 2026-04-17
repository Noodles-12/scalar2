`timescale 1ns / 1ps

module fetch_decode_pl_tb();
    logic clk;
    logic [0:29] instr_a;
    logic [0:29] instr_b;
    logic [0:29] instr_op_a [0:7];
    logic [0:29] instr_op_b [0:7];

    fetch_decode_pl fd(.clk(clk),
                       .instr_a(instr_a),
                       .instr_b(instr_b),
                       .instr_op_a(instr_op_a),
                       .instr_op_b(instr_op_b) );
                       
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
