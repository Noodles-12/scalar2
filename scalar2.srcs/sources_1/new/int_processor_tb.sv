`timescale 1ns / 1ps

module int_processor_tb();
    logic clk, rst;

    int_processor proc(.clk(clk), 
                       .rst(rst) );

    initial clk = 0;
    always #5 clk = ~clk;

    logic [31:0] gold_regs [0:NUM_ARCH_REGS-1];

    initial begin
        rst = 1; #10; rst = 0;
        #140;
        $finish;
    end
endmodule
