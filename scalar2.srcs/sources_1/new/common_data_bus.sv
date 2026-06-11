`timescale 1ns / 1ps

import config_pkg::*;

module common_data_bus(
    input cdb_entry int_res, 
    input cdb_entry imm_res, 
    input cdb_entry load_res,
    
    output cdb_entry cdb_arr [0:CDB_SIZE - 1]
);
    assign cdb_arr[0] = int_res;
    assign cdb_arr[1] = imm_res;
    assign cdb_arr[2] = load_res;
endmodule
