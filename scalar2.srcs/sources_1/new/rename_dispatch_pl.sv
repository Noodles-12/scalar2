`timescale 1ns / 1ps

import config_pkg::*;

module rename_dispatch_pl(clk, rename_a, rename_b,
                            output_a, output_b);
    input clk;
    input rs_entry rename_a, rename_b;
    output rs_entry output_a, output_b;

    rs_entry rename_a_reg, rename_b_reg;
    logic [0:1] code_a, code_b;

    dispatch_demux_1x4 dispatch_a(.data(rename_a_reg),
                                  .code(code_a),
                                  .op(output_a) );

    dispatch_demux_1x4 dispatch_b(.data(rename_b_reg),
                                  .code(code_b),
                                  .op(output_b) );

    always_ff @ (posedge clk) begin
        rename_a_reg <= rename_a;
        rename_b_reg <= rename_b;
    end

    always_comb begin
        // Dispatch Logic
        case(rename_a) inside
            [1:15] : code_a = 0;
            [16:27]: code_b = 1;
        endcase
    end
endmodule
