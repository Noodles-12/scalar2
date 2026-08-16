`timescale 1ns / 1ps

module func_unit_branch(
    input logic clk,
    input logic rst,
    input logic mispredict_signal,
    input branch_rs_entry branch_instr_a,
    input branch_rs_entry branch_instr_b,

    output branch_disp_entry result_op_a,
    output branch_disp_entry result_op_b
);
    logic result_a, result_b;

    comparator comp_a(.input1(branch_instr_a.value_s),
                    .input2(branch_instr_a.value_t),
                    .opcode(branch_instr_a.opcode),
                    .result(result_a) );

    comparator comp_b(.input1(branch_instr_b.value_s),
                    .input2(branch_instr_b.value_t),
                    .opcode(branch_instr_b.opcode),
                    .result(result_b) );

    always_ff @ (posedge clk) begin
        if(rst || mispredict_signal) begin
            result_op_a <= '0;
        end else begin
            if(branch_instr_a.valid) begin
                result_op_a.valid <= 1;
                result_op_a.id <= branch_instr_a.id;
                result_op_a.result <= result_a;
            end else begin
                result_op_a <= '0;
            end
        end
    end

    always_ff @ (posedge clk) begin
        if(rst || mispredict_signal) begin
            result_op_b <= '0;
        end else begin
            if(branch_instr_b.valid) begin
                result_op_b.valid <= 1;
                result_op_b.id <= branch_instr_b.id;
                result_op_b.result <= result_b;
            end else begin
                result_op_b <= '0;
            end
        end
    end
endmodule
