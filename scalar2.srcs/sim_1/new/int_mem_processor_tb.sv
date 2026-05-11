`timescale 1ns / 1ps

module int_mem_processor_tb();
    logic clk, rst;
    logic [0:3] amount_executed;

    int_mem_processor im_proc(clk, rst, amount_executed);

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        rst = 1; #10; rst = 0;
        #200;
        $finish;
    end
endmodule
