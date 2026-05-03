`timescale 1ns / 1ps

import config_pkg::*;

module func_unit_str(clk, str_a, str_b,
                        str_rob);
    input logic clk;
    input store_rs_entry str_a, str_b;

    // Dedicated pipelines between store_FU & ROB since stores don't write registers
    // But still need memory destination changed
    output str_rob_entry str_rob [0:1];

    store_rs_entry str_a_reg, str_b_reg;

    logic [0:ADDRBUS_SIZE - 1] mem_dest_a, mem_dest_b;

    always_ff @ (posedge clk) begin
        str_a_reg <= str_a;
        str_b_reg <= str_b;
    end

    always_comb begin
        if(str_a_reg != 0) begin
            str_rob[0].id = str_a_reg.id;
            str_rob[0].mem_dest = str_a_reg.value2 + str_a_reg.offset;
            str_rob[0].value = str_a_reg.value2;
        end

        if(str_b_reg != 0) begin
            str_rob[1].id = str_b_reg.id;
            str_rob[1].mem_dest = str_b_reg.value2 + str_b_reg.offset;
            str_rob[1].value = str_b_reg.value2;
        end
    end
endmodule
