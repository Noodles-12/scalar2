`timescale 1ns / 1ps

module predict_tb();
    logic clk, rst;

    logic [ADDRBUS_SIZE-1:0] pc_addr;

    logic [31:0] instr_a, instr_b;
    logic [ADDRBUS_SIZE-1:0] addr_a, addr_b;

    program_counter pc(
        .clk(clk),
        .rst(rst),
        .write_enable(1'b1),
        .ip_addr(ctrl.next_pc),
        .op_addr(pc_addr)
    );

    instruction_memory instr_mem(
        .clk(clk),
        .ip_addr(pc_addr),

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

    
    );

    controller ctrl(
        .code_a(),
        .code_b(),
    );
endmodule
