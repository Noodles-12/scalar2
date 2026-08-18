`timescale 1ns / 1ps

import config_pkg::*;

module res_station_branch(
    input logic clk,
    input logic rst,
    input logic mispredict_signal,
    input logic enable,
    input branch_rs_entry instr_a,
    input branch_rs_entry instr_b,
    input cdb_entry cdb_arr [0:CDB_SIZE - 1],

    output branch_rs_entry instr_op_a,
    output branch_rs_entry instr_op_b,
    output logic almost_full
);

    typedef struct packed {
        logic valid;
        logic [4:0] idx;
        branch_rs_entry entry;
    } insert_req;

    typedef struct packed {
        logic valid;
        logic [4:0] idx;
        branch_rs_entry entry;
    } dispatch_req;

    logic [3:0] filled_stations;

    branch_rs_entry res_station [0:RS_SIZE - 1];

    insert_req insert_reqs [0:1];

    dispatch_req disp_req_a, disp_req_b;

    logic done_a, done_b, done_c, done_d;
    logic [2:0] idx_a, idx_b, idx_c, idx_d;

    logic [RS_SIZE-1:0] free_bits, free_bits_masked;
    logic [RS_SIZE-1:0] onehot_a, onehot_b;

    logic [RS_SIZE-1:0] ready_bits, ready_bits_masked;
    logic [RS_SIZE-1:0] disp_onehot_a, disp_onehot_b;

    branch_rs_entry instr_a_bypassed, instr_b_bypassed;

    assign almost_full = (filled_stations >= 6);

    always_ff @ (posedge clk) begin
        if (rst || mispredict_signal) begin
            res_station <= '{default: '0};

            instr_op_a <= '0;
            instr_op_b <= '0;
        end else begin
            for(int i = 0; i < 2; i++) begin
                if(insert_reqs[i].valid) begin
                    res_station[insert_reqs[i].idx] <= insert_reqs[i].entry;
                end
            end

            if(disp_req_a.valid) begin
                instr_op_a <= disp_req_a.entry;
                res_station[disp_req_a.idx] <= '0;
            end else
                instr_op_a <= '0;

            if(disp_req_b.valid) begin
                instr_op_b <= disp_req_b.entry;
                res_station[disp_req_b.idx] <= '0;
            end else
                instr_op_b <= '0;

            for(int i = 0; i < CDB_SIZE; i++) begin
                if(!cdb_arr[i].valid) continue;
                for(int j = 0; j < RS_SIZE; j++) begin
                    if(!res_station[j].valid) continue;

                    if(res_station[j].reg_s == cdb_arr[i].prf) begin
                        res_station[j].value_s <= cdb_arr[i].result;
                        res_station[j].check_s <= 1;
                    end
                    if(res_station[j].reg_t == cdb_arr[i].prf) begin
                        res_station[j].value_t <= cdb_arr[i].result;
                        res_station[j].check_t <= 1;
                    end
                end
            end
        end
    end

    // Insert block
    always_comb begin
        insert_reqs[0].valid = 0;
        insert_reqs[1].valid = 0;

        done_a = 0; done_b = 0;
        idx_a = '0; idx_b = '0;

        filled_stations = '0;

        instr_a_bypassed = instr_a;
        instr_b_bypassed = instr_b;

        for(int i = 0; i < CDB_SIZE; i++) begin
            if(!cdb_arr[i].valid) continue;

            if(!instr_a_bypassed.check_s && instr_a_bypassed.reg_s == cdb_arr[i].prf) begin
                instr_a_bypassed.value_s = cdb_arr[i].result;
                instr_a_bypassed.check_s = 1'b1;
            end
            if(!instr_a_bypassed.check_t && instr_a_bypassed.reg_t == cdb_arr[i].prf) begin
                instr_a_bypassed.value_t = cdb_arr[i].result;
                instr_a_bypassed.check_t = 1'b1;
            end

            if(!instr_b_bypassed.check_s && instr_b_bypassed.reg_s == cdb_arr[i].prf) begin
                instr_b_bypassed.value_s = cdb_arr[i].result;
                instr_b_bypassed.check_s = 1'b1;
            end
            if(!instr_b_bypassed.check_t && instr_b_bypassed.reg_t == cdb_arr[i].prf) begin
                instr_b_bypassed.value_t = cdb_arr[i].result;
                instr_b_bypassed.check_t = 1'b1;
            end
        end

        free_bits = '0;
        for(int i = 0; i < RS_SIZE; i++) begin
            if(!res_station[i].valid) begin
                free_bits[i] = 1'b1;
            end else begin
                filled_stations++;
            end
        end
        if(disp_req_a.valid) free_bits[disp_req_a.idx] = 1'b0;
        if(disp_req_b.valid) free_bits[disp_req_b.idx] = 1'b0;

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
            insert_reqs[0].idx = idx_a;
            insert_reqs[0].entry = instr_a_bypassed;
        end

        if(instr_b.valid) begin
            insert_reqs[1].valid = 1;
            insert_reqs[1].idx = instr_a.valid ? idx_b : idx_a;
            insert_reqs[1].entry = instr_b_bypassed;
        end
    end

    always_comb begin
        disp_req_a = '0;
        disp_req_b = '0;
        done_c = 0; idx_c = '0;
        done_d = 0; idx_d = '0;

        ready_bits = '0;
        for(int i = 0; i < RS_SIZE; i++) begin
            if(res_station[i].valid && res_station[i].check_s && res_station[i].check_t) begin
                ready_bits[i] = 1'b1;
            end
        end

        disp_onehot_a = ready_bits & (~ready_bits + 1'b1);

        ready_bits_masked = ready_bits & (~disp_onehot_a);
        disp_onehot_b = ready_bits_masked & (~ready_bits_masked + 1'b1);

        idx_c = '0;
        for(int i = 0; i < RS_SIZE; i++) begin
            if(disp_onehot_a[i]) idx_c |= i;
        end

        idx_d = '0;
        for(int i = 0; i < RS_SIZE; i++) begin
            if(disp_onehot_b[i]) idx_d |= i;
        end

        done_c = |ready_bits;
        done_d = |ready_bits_masked;

        if(done_c) begin
            disp_req_a.valid = 1;
            disp_req_a.idx = idx_c;
            disp_req_a.entry = res_station[idx_c];
        end

        if(done_d) begin
            disp_req_b.valid = 1;
            disp_req_b.idx = idx_d;
            disp_req_b.entry = res_station[idx_d];
        end
    end
endmodule
