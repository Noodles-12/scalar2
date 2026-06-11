`timescale 1ns / 1ps

import config_pkg::*;

module res_station_imm(
    input logic clk,
    input logic rst,
    input imm_rs_entry instr_a,
    input imm_rs_entry instr_b,
    input cdb_entry cdb_arr [0:CDB_SIZE - 1],

    output imm_rs_entry instr_op,
    output logic almost_full
);

    typedef struct packed {
        logic valid;
        logic [4:0] idx;
        imm_rs_entry entry;
    } insert_req;

    typedef struct packed {
        logic valid;
        logic [4:0] idx;
        imm_rs_entry entry;
    } dispatch_req;

    logic [3:0] filled_stations;

    imm_rs_entry res_station [0:RS_SIZE - 1];

    // Insert logics
    insert_req insert_reqs [0:1];

    // Dispatch logics
    dispatch_req disp_req;

    logic done_a, done_b, done_c;
    logic [2:0] idx_a, idx_b, idx_c;

    assign almost_full = (filled_stations >= 7);

    always_ff @ (posedge clk) begin
        if (rst) begin
            res_station <= '{default: '0};

            instr_op <= '0;
        end else begin
            for(int i = 0; i < 2; i++) begin
                if(insert_reqs[i].valid) begin
                    res_station[insert_reqs[i].idx] <= insert_reqs[i].entry;
                end
            end

            if(disp_req.valid) begin
                instr_op <= disp_req.entry;
                res_station[disp_req.idx] <= '0;
            end

            for (int i = 0; i < CDB_SIZE; i++) begin
                if (!cdb_arr[i].valid) continue;
                for (int j = 0; j < RS_SIZE; j++) begin
                    if (!res_station[j].valid) continue;

                    if (res_station[j].reg_s == cdb_arr[i].prf) begin
                        res_station[j].value_s <= cdb_arr[i].result;
                        res_station[j].check_s <= 1;
                    end
                end
            end
        end
    end

    // Insert block
    always_comb begin
        insert_reqs = '{default: '0};

        done_a = 0; done_b = 0;
        idx_a = '0; idx_b = '0;

        // Always assume there will be an available entry
        for(int i = 0; i < RS_SIZE; i++) begin
            if(!res_station[i].valid) begin
                if(!done_a) begin
                    done_a = 1;
                    idx_a = i;
                end else if (!done_b) begin
                    done_b = 1;
                    idx_b = 1;
                end
            end
        end

        if(instr_a.valid) begin
            insert_reqs[0].valid = 1;
            insert_reqs[0].entry = instr_a;
            insert_reqs[0].idx = idx_a;
        end

        if(instr_b.valid) begin
            insert_reqs[1].valid = 1;
            insert_reqs[1].entry = instr_b;
            insert_reqs[1].idx = idx_b;
        end
    end

    // Dispatch to FU block
    always_comb begin
        disp_req = '0;

        done_c = 0; idx_c = '0;

        for(int i = 0; i < RS_SIZE; i++) begin
            if(res_station[i].check_s) begin
                if(!done_c) begin
                    done_c = 1;
                    idx_c = i;
                end
            end
        end

        if(done_c) begin
            disp_req.valid = 1;
            disp_req.idx = idx_c;
            disp_req.entry = res_station[idx_c];
        end
    end

    // CDB update block

    /* always_comb begin
        next_res_station = res_station;

        filled_stations = '0;

        // Get amount of filled
        for(int i = 0; i < RS_SIZE - 1; i++) begin
            if(next_res_station[i].id != 0) begin
                filled_stations++;
            end
        end
    end */
endmodule
