## Clock - 100 MHz
set_property -dict { PACKAGE_PIN H16  IOSTANDARD LVCMOS33 } [get_ports { clk }]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports { clk }]

## Reset
set_property -dict { PACKAGE_PIN M19  IOSTANDARD LVCMOS33 } [get_ports { rst }]

## LEDs
set_property -dict { PACKAGE_PIN R14  IOSTANDARD LVCMOS33 } [get_ports { reg_op[0] }]
set_property -dict { PACKAGE_PIN P14  IOSTANDARD LVCMOS33 } [get_ports { reg_op[1] }]
set_property -dict { PACKAGE_PIN N16  IOSTANDARD LVCMOS33 } [get_ports { reg_op[2] }]
set_property -dict { PACKAGE_PIN M14  IOSTANDARD LVCMOS33 } [get_ports { reg_op[3] }]