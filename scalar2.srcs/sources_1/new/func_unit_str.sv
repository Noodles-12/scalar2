`timescale 1ns / 1ps

import config_pkg::*;

module func_unit_str(
    input logic clk,
    input logic rst,
    input str_disp_entry str_a,
    input str_disp_entry str_b,
    // Dedicated pipeline between store_FU & ROB since stores don't write registers
    // But still need memory destination changed
    // Also for forwarding calculated addresses into stores
    output str_disp_entry str_rob [0:1]
);

    always_ff @ (posedge clk) begin
        if(rst) begin
            str_rob[0] <= '0;
            str_rob[1] <= '0;
        end else begin
            str_rob[0] <= '0;
            str_rob[1] <= '0;

            if(str_a.valid) begin
                str_rob[0] <= str_a;
                str_rob[0].mem_dest <= str_a.base_val + str_a.offset;
            end

            if(str_b.valid) begin
                str_rob[1] <= str_b;
                str_rob[1].mem_dest <= str_b.base_val + str_b.offset;
            end
        end
    end
endmodule
