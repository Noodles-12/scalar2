`timescale 1ns / 1ps

import config_pkg::*;

module test_processor(clk, rst, led);
    input logic clk, rst;
    output logic [0:4] led;

    // Program Counter
    logic [0:11] pc_next, pc_out;
    assign pc_next = pc_out + 12'd2;

    logic halted, started;

    // Fetch
    instruction instr_a, instr_b;

    // Rename
    rs_entry rename_a, rename_b;
    rob_entry rob_a, rob_b;

    program_counter pc(.clk(clk),
                       .write_enable(~rst),
                       .ip_addr(pc_next),
                       .op_addr(pc_out) );

    instruction_memory instr_mem(.clk(clk),
                                 .rst(rst),
                                 .ip_addr(pc_out),
                                 .instr_a(instr_a),
                                 .instr_b(instr_b) );

    reg_file rf(.clk(clk),
                .rst(rst),
                .og_instr_a(instr_a),
                .og_instr_b(instr_b),
                .cdb_arr(),
                .commit_arr(),
                .rename_a(rename_a),
                .rename_b(rename_b),
                .rob_a(rob_a),
                .rob_b(rob_b) );

    always_ff @(posedge clk) begin
        if (rst) begin
            led     <= 5'b00001;  // bit[4] on during reset
            halted  <= 0;
            started <= 0;
        end else begin
            led[4] <= 0;
            if (!halted) begin
                if (instr_a != '0 || instr_b != '0) begin
                    started  <= 1;
                    led[0:3] <= led[0:3]
                        + (instr_a != '0 ? 4'd1 : 4'd0)
                        + (instr_b != '0 ? 4'd1 : 4'd0);
                end else if (started) begin
                    halted <= 1;
                end
            end
        end
        $display("Count: %d", led[0:3]);
    end

endmodule