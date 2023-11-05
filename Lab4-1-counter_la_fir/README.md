[TOC]

# Execute FIR code in user BRAM

## Simulation for FIR
### First, change the path to our testbench
```sh
$ cd lab-exmem_fir/testbench/counter_la_fir
```
### Start the simulation
```sh
$ source run_clean
$ source run_sim
```
- After this step, we can get `counter_la_fir.hex`,
and dump `counter_la_fir.vcd`.
- We can see the waveform of the result by using GTKwave:
```sh
$ gtkwave counter_la_fir.vcd
```
![waveform](https://github.com/vic9112/SOC/assets/137171415/427f4c89-52ce-43b2-817f-09cb9f8dc8e7)

## Start xsim
```sh
$ make
```
- Then the result will be in xsim.log
