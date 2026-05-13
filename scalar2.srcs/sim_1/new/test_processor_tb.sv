`timescale 1ns / 1ps

module test_processor_tb();
    logic clk, rst;
    logic [0:4] led;

    test_processor tp(clk, rst, led);

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        rst = 1; #10; rst = 0;
        #200;
        $finish;
    end
endmodule
