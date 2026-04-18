`timescale 1ns / 1ps
module decode_dispatch_int(instr_a, instr_b, clk,
                            opcode_a, instr_dest_a, instr_src1_a, instr_src2_a,
                            opcode_b, instr_dest_b, instr_src1_b, instr_src2_b);
    input [0:29] instr_a;
    input [0:29] instr_b;
    input clk;
    
    output logic [0:5] opcode_a;
    output logic [0:3] instr_dest_a;
    output logic [0:3] instr_src1_a;
    output logic [0:3] instr_src2_a;
    
    output logic [0:5] opcode_b;
    output logic [0:3] instr_dest_b;
    output logic [0:3] instr_src1_b;
    output logic [0:3] instr_src2_b;
    
    logic [0:29] instr_a_reg;
    logic [0:29] instr_b_reg;
    
    always_ff @ (posedge clk) begin
        instr_a_reg <= instr_a;
        instr_b_reg <= instr_b;
    end
    
    always_comb begin
        if (instr_a_reg != 0) begin
            opcode_a     = instr_a_reg[24:29];
            instr_dest_a = instr_a_reg[20:23];
            instr_src1_a = instr_a_reg[16:19];
            instr_src2_a = instr_a_reg[12:15];
        end
        
        if (instr_b_reg != 0) begin
            opcode_b     = instr_b_reg[24:29];
            instr_dest_b = instr_b_reg[20:23];
            instr_src1_b = instr_b_reg[16:19];
            instr_src2_b = instr_b_reg[12:15];
        end
    end
endmodule