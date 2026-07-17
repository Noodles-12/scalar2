`timescale 1ns / 1ps

import config_pkg::*;

module reorder_buffer(
    input logic clk,
    input logic rst,
    input logic mispredict_signal,
    input rob_entry input_a,
    input rob_entry input_b,
    input cdb_entry cdb_arr [0:CDB_SIZE - 1],
    input str_disp_entry str_rob [0:1],
    input branch_disp_entry branch_rob,
    
    output rob_entry output_arr [0:1],
    output id_to_free ids_to_free [0:1]
);

    typedef struct packed {
        logic valid;
        logic [4:0] idx;
        logic [4:0] id;
    } commit_req;

    typedef struct packed {
        logic valid;
        logic [4:0] idx;
        rob_entry entry;
    } insert_req;

    (* max_fanout = 8 *) rob_entry buffer [0:31];

    (* max_fanout = 8 *) logic [4:0] lut [0:31];
    (* max_fanout = 8 *) logic lut_valid [0:31];

    (* max_fanout = 8 *) logic [4:0] head, head_p1, head_p2;
    (* max_fanout = 8 *) logic [4:0] tail;
    // 6 bits: must be able to hold 32 without wrapping to 0, which would make a
    // full ROB look empty and let inserts overwrite live entries
    (* max_fanout = 8 *) logic [5:0] count;

    logic full;

    assign full = (count >= 32);

    // Insert logics
    insert_req insert_reqs [0:1];
    logic [4:0] insert_tail;
    logic [4:0] insert_count;

    // Commit logics
    commit_req commit_reqs [0:1];
    logic [4:0] commit_head;
    logic [4:0] commit_count;

    // CDB logics
    logic [31:0] cdb_hit;
    logic [31:0] cdb_result [0:31];

    // str_rob logics
    logic [31:0] str_hit;
    logic [31:0] str_result [0:31];
    logic [11:0] str_dest [0:31];

    // branch_rob logics
    logic [31:0] branch_hit;
    logic branch_actual [0:31];

    always_ff @ (posedge clk) begin
        if (rst || mispredict_signal) begin
            buffer <= '{default: '0};

            head <= '0;
            head_p1 <= '0;
            head_p2 <= '0;

            tail <= '0;
            count <= '0;

            output_arr <= '{default: '0};
            ids_to_free <= '{default: '0};

            lut <= '{default: '0};
            lut_valid <= '{default: '0};

        end else begin
            // Inserts
            for (int i = 0; i < 2; i++) begin
                if (insert_reqs[i].valid) begin
                    buffer[insert_reqs[i].idx] <= insert_reqs[i].entry;
                    lut[insert_reqs[i].entry.reg_rob.id] <= insert_reqs[i].idx;
                    lut_valid[insert_reqs[i].entry.reg_rob.id] <= 1;
                end
            end

            // Commits
            for (int i = 0; i < 2; i++) begin
                if (commit_reqs[i].valid) begin
                    output_arr[i] <= buffer[commit_reqs[i].idx];
                    ids_to_free[i].valid <= 1;
                    ids_to_free[i].id <= buffer[commit_reqs[i].idx].reg_rob.id;
                    lut_valid[commit_reqs[i].id] <= 0;
                    buffer[commit_reqs[i].idx] <= '0;
                end else begin
                    output_arr[i] <= '0;
                    ids_to_free[i] <= '0;
                end
            end

            // CDB & str_rob updates
            for(int i = 0; i < 32; i++) begin
                if(cdb_hit[i]) begin
                    buffer[i].reg_rob.result <= cdb_result[i];
                    buffer[i].reg_rob.done <= 1;
                end

                if(str_hit[i]) begin
                    buffer[i].str_rob.done <= 1;
                    buffer[i].str_rob.value <= str_result[i];
                    buffer[i].str_rob.mem_dest <= str_dest[i];
                end

                if(branch_hit[i]) begin
                    buffer[i].branch_rob.done <= 1;
                    buffer[i].branch_rob.actual <= branch_actual[i];
                end
            end
            

            // Update head, tail, count
            head <= commit_head;
            head_p1 <= (commit_head == 31) ? 0 : commit_head + 1;
            head_p2 <= (commit_head >= 30) ? commit_head - 30 : commit_head + 2;

            tail <= insert_tail;
            count <= count + insert_count - commit_count;
        end
    end

    // Insert block
    always_comb begin
        insert_reqs = '{default: '0};
        insert_tail = tail;
        insert_count = '0;

        // Inserting into buffer
        if(input_a.reg_rob.valid && !full) begin
            insert_reqs[0].valid = 1;
            insert_reqs[0].entry = input_a;
            insert_reqs[0].idx = tail;
            insert_tail = (insert_tail == 31) ? 0 : insert_tail + 1;
            insert_count = insert_count + 1;
        end

        if(input_b.reg_rob.valid && (count + insert_count) < 32) begin
            insert_reqs[1].valid = 1;
            insert_reqs[1].entry = input_b;
            insert_reqs[1].idx = insert_tail;
            insert_tail = (insert_tail == 31) ? 0 : insert_tail + 1;
            insert_count = insert_count + 1;
        end
    end

    // Commit block
    always_comb begin
        commit_reqs = '{default: '0};
        commit_head = head;
        commit_count = '0;

        // Iteration 0 reads directly from registered head
        if (buffer[head].reg_rob.valid && buffer[head].reg_rob.done) begin
            commit_reqs[0].valid = 1;
            commit_reqs[0].idx = head;
            commit_reqs[0].id = buffer[head].reg_rob.id;
            commit_count = 1;
            commit_head = head_p1;

            // Iteration 1 only happens if first commit happened, unrolled dependency
            if (buffer[head_p1].reg_rob.valid && buffer[head_p1].reg_rob.done) begin
                commit_reqs[1].valid = 1;
                commit_reqs[1].idx = head_p1;
                commit_reqs[1].id = buffer[head_p1].reg_rob.id;
                commit_count = 2;
                commit_head = head_p2;
            end
        end
    end

    // CDB block
    always_comb begin
        cdb_hit = '0;
        cdb_result = '{default: '0};

        for(int i = 0; i < CDB_SIZE; i++) begin
            if (!cdb_arr[i].valid) continue;
            if (!lut_valid[cdb_arr[i].id]) continue;

            cdb_hit[lut[cdb_arr[i].id]] = 1;
            cdb_result[lut[cdb_arr[i].id]] = cdb_arr[i].result;
        end
    end

    // str_rob block
    always_comb begin
        str_hit = '0;
        str_result = '{default: '0};
        str_dest = '{default: '0};

        for (int i = 0; i < 2; i++) begin
            if (!str_rob[i].valid) continue;
            if (!lut_valid[str_rob[i].id]) continue;

            str_hit[lut[str_rob[i].id]] = 1;
            str_result[lut[str_rob[i].id]] = str_rob[i].mem_dest;
            str_dest[lut[str_rob[i].id]] = str_rob[i].mem_dest;
        end
    end

    // branch_rob block
    always_comb begin
        branch_hit = '0;
        branch_actual = '{default: '0};

        if (branch_rob.valid && lut_valid[branch_rob.id]) begin
            branch_hit[lut[branch_rob.id]] = 1;
            branch_actual[lut[branch_rob.id]] = branch_rob.result;
        end
    end
endmodule