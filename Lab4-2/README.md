# Execute FIR in user project by reading firmware code in user BRAM

## Simulation for FIR
```sh
$ cd ~/Lab4-2/lab-caravel_fir/testbench/counter_la_fir
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
