# Execute FIR in user project by reading firmware code in user BRAM

## Simulation for FIR
```sh
$ cd ~/Lab4-2/lab-caravel_fir/testbench/counter_la_fir
$ source run_clean
$ source run_sim
```
- Above generate counter_la_fir.vcd
- Then we can see the waveform by using gtkwave to open .vcd file.

```sh
$ gtkwave counter_la_fir.vcd
```
![螢幕擷取畫面 2023-12-05 225846](https://github.com/vic9112/SOC/assets/137171415/b5a41745-a4f1-41d2-9d6e-143b9792cfbe)

## XSIM

```sh
$ make
```
- which will generate xsim.log in current directory.

![螢幕擷取畫面 2023-12-06 211318](https://github.com/vic9112/SOC/assets/137171415/d282ae85-83bc-4122-8cbd-f2685cea643d)

# Update

- 12/19
  Achieve 12T to process one data
