`timescale 1ns / 1ps

module func_unit_branch(
    input logic clk,
    input logic rst,
    input logic mispredict_signal,
    input branch_rs_entry branch_instr,

    output branch_disp_entry result_op
);
    logic result;
    
    comparator comp(.input1(branch_instr.value_s),
                    .input2(branch_instr.value_t),
                    .opcode(branch_instr.opcode),
                    .result(result) );

    always_ff @ (posedge clk) begin
        if(rst || mispredict_signal) begin
            result_op <= '0;
        end else begin
            if(branch_instr.valid) begin
                result_op.valid <= 1;
                result_op.id <= branch_instr.id;
                result_op.result <= result;
            end else begin
                result_op <= '0;
            end
        end
    end
endmodule
