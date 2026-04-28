`timescale 1ns / 1ps

import config_pkg::*;

module reorder_buffer(clk, rob_a, rob_b);
    input logic clk;
    input rob_entry rob_a, rob_b;

    rob_entry buffer [0:63];
endmodule
