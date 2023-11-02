# Execute FIR code in user BRAM

## Simulation for FIR
### First, change the path to our testbench
```sh
$ cd lab-exmem-fir/testbench/counter_la_fir
```
### Then start to run simulation
```sh
$ ./run_clean ($ source run_clean)
$ ./run_sim   ($ source run_sim)
```
After this step, we can get `counter_la_fir.hex`,
and dump `counter_la_fir.vcd`.
We can use GTKWave to see the waveform of the result
```sh
$ gtkwave counter_la_fir.vcd
```
## Start xsim
```sh
$ make
```
Then the result will be in xsim.log
