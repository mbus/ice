# Top Level Design Parameters

# Clocks

create_clock -period 50.000000 -waveform {0.000000 25.000000} SYS_CLK
create_clock -period 50.000000 -waveform {0.000000 25.000000} FPGA_MB_DIN
create_clock -period 50.000000 -waveform {0.000000 25.000000} FPGA_MB_CIN
create_clock -period 500.000000 -waveform {0.000000 250.000000} n:ic1.mb0.mbus_clk
create_clock -period 500.000000 -waveform {0.000000 250.000000} n:ic1.mb0.mclw1.rf_addr_write
create_clock -period 500.000000 -waveform {0.000000 250.000000} n:ic1.mb0.mclw1.node0.swapper0.negp_int

# False Paths Between Clocks


# False Path Constraints


# Maximum Delay Constraints


# Multicycle Constraints


# Virtual Clocks
# Output Load Constraints
# Driving Cell Constraints
# Wire Loads
# set_wire_load_mode top

# Other Constraints
