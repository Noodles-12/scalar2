`timescale 1ns / 1ps

import config_pkg::*;

module data_memory();

    logic [0:DATABUS_WIDTH - 1] memory [0:DATA_MEM_SIZE - 1];
endmodule
