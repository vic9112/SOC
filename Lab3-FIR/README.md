# FIR by using SRAM instead of shift registers

## Goal
- Since we want to reduce the utilization in our design, we may not store our data in shift registers.
- Instead we use the SRAM(but BRAM in FPGA), and use AXI interface to communicate.

## Datapath
![image](https://github.com/vic9112/SOC/assets/137171415/e91d231f-4467-44f7-af0b-b013cb842eaa)
