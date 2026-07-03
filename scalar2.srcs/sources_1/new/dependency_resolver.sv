`timescale 1ns / 1ps

module dependency_resolver(
    input logic clk,
    input logic rst,
    input instruction instr_a,
    input instruction instr_b,
    input logic [11:0] addr_a,
    input logic [11:0] addr_b,
    input logic mispredict_flush,
    input logic enable,

    output instruction instr_a_op,
    output instruction instr_b_op,
    output logic [11:0] recov_addr_a,
    output logic [11:0] recov_addr_b
);
    logic instr_code code_a, code_b;

    assign code_a = instr_a.code;
    assign code_b = instr_b.code;

    always_ff @ (posedge clk) begin
        if(rst || mispredict_flush) begin
            instr_a_op <= '0;
            instr_b_op <= '0;
            recov_addr_a <= '0;
            recov_addr_b <= '0;
        end else if(enable) begin
            instr_a_op <= instr_a;

            // code_a[0] being 1 represents if instr_a is taken branch or jump
            instr_b_op <= code_a[0] ? '0 : instr_b;
        end
    end
endmodule
