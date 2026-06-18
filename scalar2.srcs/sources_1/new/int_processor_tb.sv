`timescale 1ns / 1ps

import config_pkg::*;

module int_processor_tb();
    logic clk, rst;

    int_processor proc(.clk(clk), 
                       .rst(rst) );

    initial clk = 0;
    always #5 clk = ~clk;

    logic [31:0] gold_regs [0:NUM_ARCH_REGS-1];

    task automatic gold_execute(input instruction instr);
        case(instr.opcode)
            1:  gold_regs[instr.reg_d] = gold_regs[instr.reg_s] + gold_regs[instr.reg_t];
            2:  gold_regs[instr.reg_d] = gold_regs[instr.reg_s] - gold_regs[instr.reg_t];
            15: gold_regs[instr.reg_d] = gold_regs[instr.reg_s] + instr.imm;
        endcase
    endtask

    initial begin
        gold_regs = '{default: '0};

        begin
            instruction instr;
            int fh;

            fh = $fopen("instr_mem.mem", "r");
            if (fh == 0) begin
                $display("ERROR: could not open instr_mem.mem");
                $finish;
            end
            while ($fscanf(fh, "%h\n", instr) == 1) begin
                gold_execute(instr);
            end
            $fclose(fh);
        end
        rst = 1; #10; rst = 0;

        #250;
        $finish;
    end
endmodule
