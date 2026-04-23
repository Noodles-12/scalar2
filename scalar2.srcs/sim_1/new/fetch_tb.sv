`timescale 1ns / 1ps

import config_pkg::*;

module fetch_tb();
    logic clk;
    logic [0:ADDRBUS_SIZE - 1] ip_addr, passed_addr;
    instruction instr_a, instr_b;

    program_counter pc(.clk(clk),
                        .write_enable(1'b1),
                        .ip_addr(ip_addr),
                        .op_addr(passed_addr) );
    
    instruction_memory instrmem(.clk(clk),
                                .ip_addr(passed_addr),
                                .instr_a(instr_a),
                                .instr_b(instr_b) );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        ip_addr = 0; #10;
        ip_addr = 2; #10;
        ip_addr = 4; #10;
        $finish;
    end
endmodule
