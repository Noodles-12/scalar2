`timescale 1ns / 1ps

module fetch_decode_pl(clk, instr_a, instr_b, instr_op_a, instr_op_b);
    input clk;
    input [0:29] instr_a;
    input [0:29] instr_b;
    
    output logic [0:29] instr_op_a [0:7];
    output logic [0:29] instr_op_b [0:7];
    
    logic [0:29] instr_a_reg;
    logic [0:29] instr_b_reg;
    
    logic [0:2] code_a;
    logic [0:2] code_b;
    
    demux_1x8 d_a(.data(instr_a_reg),
                  .code(code_a),
                  .op(instr_op_a) );
                  
    demux_1x8 d_b(.data(instr_b_reg),
                  .code(code_b),
                  .op(instr_op_b) );

    always_ff @ (posedge clk) begin
        instr_a_reg <= instr_a;
        instr_b_reg <= instr_b;
    end
    
    always_comb begin
        if (instr_a_reg[24:29] > 0 && instr_a_reg[24:29] < 16) begin
            code_a = 1;
        end
        
        if (instr_b_reg[24:29] > 0 && instr_b_reg[24:29] < 16) begin
            code_b = 1;
        end
    end
endmodule
