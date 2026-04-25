`timescale 1ns / 1ps

import config_pkg::*;

module res_station_int(clk, instr_a, instr_b, almost_full);
    input logic clk;
    input int_rs_entry instr_a, instr_b;

    output logic almost_full;
    int filled_stations;

    int_rs_entry instr_a_reg, instr_b_reg;
    int_rs_entry res_station [0:15];

    logic [0:3] avail_entry_a, avail_entry_b;
    rs_int_demux_1x16 demux_a(.data(instr_a_reg),
                              .code(avail_entry_a),
                              .op(res_station) );

    rs_int_demux_1x16 demux_b(.data(instr_b_reg),
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
    
    always_comb begin
        // Find next available station index
        for(int i = 0; i < 16; i++) begin
            if (res_station[i] == 0) begin
                avail_entry_a = i;
                break;
            end
        end

        for(int i = 0; i < 16; i++) begin
            if (res_station[i] == 0) begin
                avail_entry_b = i;
                break;
            end
        end

        for(int i = 0; i < 16; i++) begin
            if(res_station[i] == 0) begin
                filled_stations++;
            end
        end
    end


endmodule
