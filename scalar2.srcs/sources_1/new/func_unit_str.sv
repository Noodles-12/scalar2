`timescale 1ns / 1ps

import config_pkg::*;

module func_unit_str(
    input logic clk,
    input logic rst,
    input str_disp_entry str_op,
    // Dedicated pipeline between store_FU & ROB since stores don't write registers
    // But still need memory destination changed
    // Also for forwarding calculated addresses into stores
    output str_disp_entry str_rob
);

    always_ff @ (posedge clk) begin
        if(rst) begin
            str_rob <= '0;
        end else begin
            str_rob <= '0;

            if(str_op.valid) begin
                str_rob <= str_op;
                str_rob.mem_dest <= str_op.base_val + str_op.offset;
            end
        end
    end
endmodule
