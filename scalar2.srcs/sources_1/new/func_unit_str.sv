`timescale 1ns / 1ps

import config_pkg::*;

module func_unit_str(
    input logic clk,
    input logic rst,
    input str_disp_entry str_op_a,
    input str_disp_entry str_op_b,
    output str_disp_entry str_rob_a,
    output str_disp_entry str_rob_b
);

    always_ff @ (posedge clk) begin
        if(rst) begin
            str_rob_a <= '0;
        end else begin
            str_rob_a <= '0;

            if(str_op_a.valid) begin
                str_rob_a <= str_op_a;
                str_rob_a.mem_dest <= str_op_a.base_val + str_op_a.offset;
            end
        end
    end

    always_ff @ (posedge clk) begin
        if(rst) begin
            str_rob_b <= '0;
        end else begin
            str_rob_b <= '0;

            if(str_op_b.valid) begin
                str_rob_b <= str_op_b;
                str_rob_b.mem_dest <= str_op_b.base_val + str_op_b.offset;
            end
        end
    end
endmodule
