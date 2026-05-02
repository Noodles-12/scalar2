`timescale 1ns / 1ps

import config_pkg::*;

module res_station_int(clk, instr_a, instr_b, cdb_arr, almost_full,
                        output_a, output_b);
    input logic clk;
    input int_rs_entry instr_a, instr_b;
    input cdb_entry cdb_arr [0:3];

    output int_rs_entry output_a, output_b;
    output logic almost_full;

    logic [0:4] filled_stations;

    int_rs_entry instr_a_reg, instr_b_reg;

    int_rs_entry res_station [0:15] = '{default: '0};
    int_rs_entry next_res_station [0:15];

    // a & b used for finding available entries; c & d used for pushing first two finished instructions
    logic done_a, done_b, done_c, done_d;

    assign almost_full = (filled_stations >= 14);

    always_ff @ (posedge clk) begin
        instr_a_reg <= instr_a;
        instr_b_reg <= instr_b;

        res_station <= next_res_station;
    end
    
    always_comb begin
        next_res_station = res_station;
        filled_stations = 0;
        done_a = 0;
        done_b = 0;
        done_c = 0;
        done_d = 0;
        output_a = 0;
        output_b = 0;

        // Dispatch finished instructions to FU
        for(int i = 0; i < 16; i++) begin
            if(res_station[i].check1 == 1 && res_station[i].check2 == 1) begin
                if(!done_c) begin
                    output_a = res_station[i];
                    done_c = 1;
                    next_res_station[i] = 0;
                end else if (!done_d) begin
                    output_b = res_station[i];
                    done_d = 1;
                    next_res_station[i] = 0;
                end
            end
        end

        // Fill in available registers
        for(int i = 0; i < 16; i++) begin
            if (next_res_station[i] == 0) begin
                if (!done_a) begin
                    next_res_station[i] = instr_a_reg;
                    done_a = 1;
                end else if (!done_b) begin
                    next_res_station[i] = instr_b_reg;
                    done_b = 1;
                end
            end
        end

        // Take in CDB to adjust RS entries
        for(int i = 0; i < 4; i++) begin
            if (cdb_arr[i] == 0) continue;
            for(int j = 0; j < 16; j++) begin
                if (next_res_station[j] == 0) continue;

                if (next_res_station[j].reg1 == cdb_arr[i].prf) begin
                    next_res_station[j].value1 = cdb_arr[i].result;
                    next_res_station[j].check1 = 1;
                end
                if (next_res_station[j].reg2 == cdb_arr[i].prf) begin
                    next_res_station[j].value2 = cdb_arr[i].result;
                    next_res_station[j].check2 = 1;
                end
            end 
        end

        // Get amount of filled
        for(int i = 0; i < 16; i++) begin
            if(next_res_station[i] != 0) begin
                filled_stations++;
            end
        end
    end
endmodule
