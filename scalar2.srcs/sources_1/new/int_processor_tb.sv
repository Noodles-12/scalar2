`timescale 1ns / 1ps

module int_processor_tb();
    logic clk, rst;

    int_processor proc(clk, rst);

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        rst = 1; #10; rst = 0;
        #140;
        $finish;
    end
endmodule
