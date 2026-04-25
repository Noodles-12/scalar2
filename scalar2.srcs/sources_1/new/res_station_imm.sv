`timescale 1ns / 1ps

import config_pkg::*;

module res_station_imm(clk, instr_a, instr_b, almost_full);
    input logic clk;
    input imm_rs_entry instr_a, instr_b;
    output logic almost_full;

    int filled_stations;

    imm_rs_entry instr_a_reg, instr_b_reg;
    imm_rs_entry res_station [0:15];

    logic [0:3] avail_entry_a, avail_entry_b;
    rs_demux1x16 demux_a(.data(instr_a_reg),
                         .code(avail_entry_a),
                         .op(res_station) );

    rs_demux1x16 demux_b(.data(instr_b_reg),
                              .code(avail_entry_b),
                              .op(res_station) );

    initial begin
        avail_entry_a = 0;
        avail_entry_b = 1;    
    end

    always_ff @ (posedge clk) begin
        instr_a_reg <= instr_a;
        instr_b_reg <= instr_b;
    end
endmodule
