# Execute FIR code in user BRAM

## Simulation for FIR
```sh
$ cd ~/caravel-soc_fpga-lab/lab-exmem-fir/testbench/counter_la_fir
$ source run_clean
$ source run_sim
```
- above generate counter_la_fir.vcd, which we can use gtkwave to open it.

```sh
$ gtkwave counter_la_fir.vcd
```

## XSIM

```sh
$ make
```

- which will generate xsim.log in current directory.
