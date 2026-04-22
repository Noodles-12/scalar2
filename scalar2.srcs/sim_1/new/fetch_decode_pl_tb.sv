`timescale 1ns / 1ps

module fetch_decode_pl_tb();
    logic clk;
    logic [0:29] instr_a;
    logic [0:29] instr_b;
    instruction instr_op_a;
    instruction instr_op_b;

    fetch_decode_pl fd(.clk(clk),
                       .instr_a(instr_a),
                       .instr_b(instr_b),
                       .instr_op_a(instr_op_a),
                       .instr_op_b(instr_op_b) );
                       
    initial clk = 0;
    always #5 clk = ~clk;
    
    initial begin
        instr_a = 30'b0000000000000000000000000000001; instr_b = 30'b000000000000000000000000000011; # 10;
        instr_a = 30'b0000000000000000000000000000010; instr_b = 30'b000000000000000000000000000001; # 10;
        instr_a = 30'b0000000000000000000000000000100; instr_b = 30'b000000000000000000000000000111; # 10;
        instr_a = 30'b0000000000000000000000000001000; instr_b = 30'b000000000000000000000000001111; # 10;
        $finish;
    end
                  
endmodule
