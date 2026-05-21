`timescale 1ns / 1ps

import config_pkg::*;

module res_station_imm(
    input logic clk,
    input logic rst,
    input imm_rs_entry instr_a,
    input imm_rs_entry instr_b,
    input cdb_entry cdb_arr [0:CDB_SIZE - 1],

    output imm_rs_entry output_a_reg,
    output imm_rs_entry output_b_reg,
    output logic almost_full
);

    logic [3:0] filled_stations;

    imm_rs_entry res_station [0:RS_SIZE - 1];
    imm_rs_entry next_res_station [0:RS_SIZE - 1];

    imm_rs_entry output_a, output_b;

    logic done_a, done_b, done_c, done_d;
    logic [2:0] idx_a, idx_b, idx_c, idx_d;

    assign almost_full = (filled_stations >= 7);

    always_ff @ (posedge clk) begin
        if (rst) begin
            res_station <= '{default: '0};

            output_a_reg <= '0;
            output_b_reg <= '0;
        end else begin
            res_station <= next_res_station;

            output_a_reg <= output_a;
            output_b_reg <= output_b;
        end
    end

    always_comb begin
        next_res_station = res_station;

        filled_stations = '0;
        done_a = 0; done_b = 0;
        idx_a = '0; idx_b = '0;
        done_c = 0; done_d = 0;
        idx_c = '0; idx_d = '0;

        output_a = '0; output_b = '0;

        // Dispatch finished instructions to FU
        for(int i = 0; i < RS_SIZE - 1; i++) begin
            if(res_station[i].check_s) begin
                if(!done_c) begin
                    done_c = 1;
                    idx_c = i;
                end else if (!done_d) begin
                    done_d = 1;
                    idx_d = i;
                end
            end
        end

        if(done_c) begin
            output_a = next_res_station[idx_c];
            next_res_station[idx_c] = '0;
        end

        if(done_d) begin
            output_b = next_res_station[idx_d];
            next_res_station[idx_d] = '0;
        end

        // Insert instructions
        for(int i = 0; i < RS_SIZE - 1; i++) begin
            if (!next_res_station[i].valid) begin
                if (!done_a) begin
                    idx_a = i;
                    done_a = 1;
                end else if (!done_b) begin
                    idx_b = i;
                    done_b = 1;
                end
            end
        end

        // Could possibly check if A was inserted in the first one
        //  If so, insert b at idx_b
        //  If not, insert b at idx_a
        if(done_a && instr_a.valid) begin
            next_res_station[idx_a] = instr_a;
        end

        if(done_b && instr_b.valid) begin
            next_res_station[idx_b] = instr_b;
        end

        // Take in CDB to adjust RS entries
        for(int i = 0; i < CDB_SIZE; i++) begin
            if (!cdb_arr[i].valid) continue;
            for(int j = 0; j < RS_SIZE - 1; j++) begin
                if (!next_res_station[j].valid) continue;

                if(next_res_station[j].reg_s == cdb_arr[i].prf) begin
                    next_res_station[j].value_s = cdb_arr[i].result;
                    next_res_station[j].check_s = 1;
                end
            end
        end

        // Get amount of filled
        for(int i = 0; i < RS_SIZE - 1; i++) begin
            if(next_res_station[i].id != 0) begin
                filled_stations++;
            end
        end
    end
endmodule
