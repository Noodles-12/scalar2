`timescale 1ns / 1ps

import config_pkg::*;

module test_processor_tb();
    logic clk, rst;

    test_processor tp(.clk(clk), 
                      .rst(rst) );

    initial clk = 0;
    always #5 clk = ~clk;

    task automatic display_str_disp(
        input string label,
        input str_disp_entry str_disp
    );
        if(str_disp.valid) begin
            $display("%s: valid=%0b id=%0d idx=%0d base_val=0x%03x offset=0x%03x mem_dest=0x%03x value=0x%08x [%0t]",
                label,
                str_disp.valid,
                str_disp.id,
                str_disp.idx,
                str_disp.base_val,
                str_disp.offset,
                str_disp.mem_dest,
                str_disp.value,
                $time);
                
            assert (str_disp.id == tp.rs_mem.store_buffer[str_disp.idx].id)
                else $error("%s: id mismatch — str_disp.id=%0d but store_buffer[%0d].id=%0d [%0t]",
                    label, str_disp.id, str_disp.idx,
                    tp.rs_mem.store_buffer[str_disp.idx].id, $time);
        end
    endtask

    always @(posedge clk) begin
        display_str_disp("str_rob_a", tp.str_rob[0]);
        display_str_disp("str_rob_b", tp.str_rob[1]);
    end

    initial begin
        rst = 1; #10; rst = 0;
        #150;

        $finish;
    end
endmodule
