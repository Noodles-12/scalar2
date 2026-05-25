`timescale 1ns / 1ps

import config_pkg::*;

module test_processor_tb();
    logic clk, rst;

    test_processor tp(.clk(clk), 
                      .rst(rst) );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        rst = 1; #10; rst = 0;
        #150;

        // Check what's in the load buffer
        for (int i = 0; i < 8; i++) begin
            if (tp.rs_mem.load_buffer[i].valid) begin
                $display("load_buffer[%0d] | valid=%b check_s=%b pending=%b offset=%h",
                    i,
                    tp.rs_mem.load_buffer[i].valid,
                    tp.rs_mem.load_buffer[i].check_s,
                    tp.rs_mem.load_buffer[i].pending_addr,
                    tp.rs_mem.load_buffer[i].offset);
            end
        end

        // Check store buffer
        for (int i = 0; i < 8; i++) begin
            if (tp.rs_mem.store_buffer[i].valid) begin
                $display("store_buffer[%0d] | valid=%b check_s=%b offset=%h",
                    i,
                    tp.rs_mem.store_buffer[i].valid,
                    tp.rs_mem.store_buffer[i].check_s,
                    tp.rs_mem.store_buffer[i].offset);
            end
        end
    $finish;
end
endmodule
