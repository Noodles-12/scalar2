`timescale 1ns / 1ps

module common_data_bus(int_a, int_b, imm_a, imm_b,
                        cdb_arr);
    input cdb_entry int_a, int_b, imm_a, imm_b;

    output cdb_entry cdb_arr [0:3];

    assign cdb_arr[0] = int_a;
    assign cdb_arr[1] = int_b;
    assign cdb_arr[2] = imm_a;
    assign cdb_arr[3] = imm_b;
endmodule
