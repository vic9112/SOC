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

![screenshot_wv](https://github.com/vic9112/SOC/assets/137171415/5196340b-72e1-42eb-885c-74f703e21642)

## XSIM

```sh
$ make
```
- which will generate xsim.log in current directory.

![螢幕擷取畫面 2023-11-28 013233](https://github.com/vic9112/SOC/assets/137171415/f3bf62dd-3e35-401b-8c8b-0d0c3ef37570)

![螢幕擷取畫面 2023-11-28 013255](https://github.com/vic9112/SOC/assets/137171415/ca25dceb-722f-4b9e-9c62-7c85dfed71d4)
