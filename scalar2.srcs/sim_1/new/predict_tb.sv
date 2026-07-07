`timescale 1ns / 1ps

module predict_tb();
    logic clk, rst;

    logic [ADDRBUS_SIZE-1:0] pc_addr;
    logic [ADDRBUS_SIZE-1:0] next_pc;

    instruction instr_a, instr_b;
    logic [ADDRBUS_SIZE-1:0] addr_a, addr_b;

    instruction mod_instr_a, mod_instr_b;
    logic [ADDRBUS_SIZE-1:0] predict_a, predict_b;
    logic [ADDRBUS_SIZE-1:0] recov_a, recov_b;

    logic predict_flush, mispredict_flush;
    logic [ADDRBUS_SIZE-1:0] mispredict_addr;

    program_counter pc(
        .clk(clk),
        .rst(rst),
        .enable(1'b1),
        .ip_addr(next_pc),
        .op_addr(pc_addr)
    );

    controller ctrl(
        .code_a(mod_instr_a.code),
        .code_b(mod_instr_b.code),
        .target_a(predict_a),
        .target_b(predict_b),
        .curr_pc(pc_addr),
        .mispredict_signal(1'b0),
        .recov_addr(mispredict_addr),

        .predict_flush(predict_flush),
        .mispredict_flush(mispredict_flush),
        .next_pc(next_pc),
        .enable()
    );

    instruction_memory instr_mem(
        .clk(clk),
        .ip_addr(pc_addr),
        .predict_flush(predict_flush),
        .mispredict_flush(mispredict_flush),

        .instr_a(instr_a),
        .instr_b(instr_b),
        .instr_a_addr(addr_a),
        .instr_b_addr(addr_b)
    );

    branch_predictor bp(
        .clk(clk),
        .rst(rst),
        .instr_a(instr_a),
        .addr_a(addr_a),
        .instr_b(instr_b),
        .addr_b(addr_b),
        .predict_flush(predict_flush),
        .mispredict_flush(mispredict_flush),
        .enable(1'b1),

        .instr_a_op(mod_instr_a),
        .instr_b_op(mod_instr_b),
        .predict_addr_a(predict_a),
        .predict_addr_b(predict_b),
        .recov_addr_a(recov_a),
        .recov_addr_b(recov_b)
    );

    dependency_resolver dep_rsvr(
        .clk(clk),
        .rst(rst),
        .instr_a(mod_instr_a),
        .instr_b(mod_instr_b),
        .addr_a(recov_a),
        .addr_b(recov_b),
        .mispredict_flush(mispredict_flush),
        .enable(1'b1),

        .instr_a_op(),
        .instr_b_op(),
        .recov_addr_a(),
        .recov_addr_b()
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0; rst = 1; #10;
        rst = 0;

        #70;

        $finish;
    end
endmodule
