`timescale 1ns / 1ps

import config_pkg::*;

module res_station_imm(
    input logic clk,
    input logic rst,
    input logic mispredict_signal,
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

    logic [RS_SIZE-1:0] free_bits, free_bits_masked;
    logic [RS_SIZE-1:0] onehot_a, onehot_b;

    imm_rs_entry instr_a_bypassed, instr_b_bypassed;

    assign almost_full = (filled_stations >= 6);

    always_ff @ (posedge clk) begin
        if (rst || mispredict_signal) begin
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
            end else
                instr_op <= '0;

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

        // Snoop the CDB for values arriving the same cycle an instruction is
        // dispatched into this RS, so a producer broadcasting this cycle isn't missed.
        instr_a_bypassed = instr_a;
        instr_b_bypassed = instr_b;

        for(int i = 0; i < CDB_SIZE; i++) begin
            if(!cdb_arr[i].valid) continue;

            if(!instr_a_bypassed.check_s && instr_a_bypassed.reg_s == cdb_arr[i].prf) begin
                instr_a_bypassed.value_s = cdb_arr[i].result;
                instr_a_bypassed.check_s = 1'b1;
            end

            if(!instr_b_bypassed.check_s && instr_b_bypassed.reg_s == cdb_arr[i].prf) begin
                instr_b_bypassed.value_s = cdb_arr[i].result;
                instr_b_bypassed.check_s = 1'b1;
            end
        end

        free_bits = '0;
        for(int i = 0; i < RS_SIZE; i++) begin
            if(!res_station[i].valid) free_bits[i] = 1'b1;
        end
        if(disp_req.valid) free_bits[disp_req.idx] = 1'b0;

        onehot_a = free_bits & (~free_bits + 1'b1);

        free_bits_masked = free_bits & (~onehot_a);
        onehot_b = free_bits_masked & (~free_bits_masked + 1'b1);

        idx_a = '0;
        for(int i = 0; i < RS_SIZE; i++) begin
            if(onehot_a[i]) idx_a |= i;
        end

        idx_b = '0;
        for(int i = 0; i < RS_SIZE; i++) begin
            if(onehot_b[i]) idx_b |= i;
        end

        done_a = |free_bits;
        done_b = |free_bits_masked;

        if(instr_a.valid) begin
            insert_reqs[0].valid = 1;
            insert_reqs[0].entry = instr_a_bypassed;
            insert_reqs[0].idx = idx_a;
        end

        if(instr_b.valid) begin
            insert_reqs[1].valid = 1;
            insert_reqs[1].entry = instr_b_bypassed;
            insert_reqs[1].idx = instr_a.valid ? idx_b : idx_a;
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

    always_comb begin
        filled_stations = '0;
        for(int i = 0; i < RS_SIZE; i++) begin
            if(res_station[i].valid) filled_stations = filled_stations + 1'b1;
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
