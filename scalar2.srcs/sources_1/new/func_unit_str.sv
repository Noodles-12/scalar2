`timescale 1ns / 1ps

import config_pkg::*;

module func_unit_str(clk, rst, str_a, str_b,
                        str_rob);
    input logic clk, rst;
    input store_rs_entry str_a, str_b;

    // Dedicated pipeline between store_FU & ROB since stores don't write registers
    // But still need memory destination changed
    // Also for forwarding calculated addresses into stores
    output str_rob_entry str_rob [0:1];

    store_rs_entry str_a_reg, str_b_reg;

    always_ff @ (posedge clk) begin
        if(rst) begin
            str_a_reg <= '0;
            str_b_reg <= '0;
        end else begin
            str_a_reg <= str_a;
            str_b_reg <= str_b;
        end
    end

    always_comb begin
        str_rob[0] = '0;
        str_rob[1] = '0;

        if(str_a_reg.id != 0) begin
            str_rob[0].id = str_a_reg.id;
            str_rob[0].mem_dest = str_a_reg.value1 + str_a_reg.offset;
            str_rob[0].value = str_a_reg.value2;
            $display("Store id: %d storing %d at %d | %t", str_rob[0].id, str_rob[0].value, str_rob[0].mem_dest, $time);
        end

        if(str_b_reg.id != 0) begin
            str_rob[1].id = str_b_reg.id;
            str_rob[1].mem_dest = str_b_reg.value1 + str_b_reg.offset;
            str_rob[1].value = str_b_reg.value2;
            $display("Store id: %d storing %d at %d | %t", str_rob[1].id, str_rob[1].value, str_rob[1].mem_dest, $time);
        end
    end
endmodule
