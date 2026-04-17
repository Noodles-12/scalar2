`timescale 1ns / 1ps

module fetch_decode_pl(clk, instr_a, instr_b, opcode_a, opcode_b);
    input clk;
    input [0:30] instr_a;
    input [0:30] instr_b;
    
    output logic [0:5] opcode_a;
    

    output logic [0:5] opcode_b;
    
    logic [0:30] instr_a_reg;
    logic [0:30] instr_b_reg;

    always_ff @ (posedge clk) begin
        instr_a_reg <= instr_a;
        instr_b_reg <= instr_b;
    end
    
    assign opcode_a = instr_a_reg[0:5];
    assign opcode_b = instr_b_reg[0:5];
endmodule
