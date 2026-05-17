`timescale 1ns / 1ps

module test_processor_tb();
    logic clk, rst;

    test_processor tp(clk, rst);

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        rst = 1; #10; rst = 0;
        #100;
        $finish;
    end
endmodule
