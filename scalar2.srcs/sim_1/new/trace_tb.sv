`timescale 1ns / 1ps

import config_pkg::*;

/*
    Scratch diagnostic testbench: dumps internal signals of int_branch_processor
    cycle by cycle so we can see exactly what happens to PC/flush/commit signals
    around the misprediction on the sample program's `beq` instruction.
*/

module trace_tb();
    logic clk, rst;

    int_branch_processor dut(
        .clk(clk),
        .rst(rst)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0; rst = 1; #10; rst = 0;
        #400;
        $finish;
    end

    always @(posedge clk) begin
        if (!rst) begin
            $display("[%0t] pc=%0d next_pc=%0d predict_flush=%0b mispredict_flush=%0b commit_misp=%0b commit_misp_addr=%0d",
                $time, dut.pc_addr, dut.next_pc, dut.predict_flush, dut.mispredict_flush,
                dut.commit_misp, dut.commit_misp_addr);

            if (dut.rob_out_arr[0].reg_rob.valid)
                $display("    rob_out[0]: id=%0d code=%0d arch=r%0d result=0x%08x done=%0b",
                    dut.rob_out_arr[0].reg_rob.id, dut.rob_out_arr[0].reg_rob.code,
                    dut.rob_out_arr[0].reg_rob.arch, dut.rob_out_arr[0].reg_rob.result,
                    dut.rob_out_arr[0].reg_rob.done);
            if (dut.rob_out_arr[1].reg_rob.valid)
                $display("    rob_out[1]: id=%0d code=%0d arch=r%0d result=0x%08x done=%0b",
                    dut.rob_out_arr[1].reg_rob.id, dut.rob_out_arr[1].reg_rob.code,
                    dut.rob_out_arr[1].reg_rob.arch, dut.rob_out_arr[1].reg_rob.result,
                    dut.rob_out_arr[1].reg_rob.done);

            if (dut.commit_a.reg_rob.valid)
                $display("    commit_a: id=%0d code=%0d arch=r%0d result=0x%08x",
                    dut.commit_a.reg_rob.id, dut.commit_a.reg_rob.code,
                    dut.commit_a.reg_rob.arch, dut.commit_a.reg_rob.result);
            if (dut.commit_b.reg_rob.valid)
                $display("    commit_b: id=%0d code=%0d arch=r%0d result=0x%08x",
                    dut.commit_b.reg_rob.id, dut.commit_b.reg_rob.code,
                    dut.commit_b.reg_rob.arch, dut.commit_b.reg_rob.result);
        end
    end
endmodule
