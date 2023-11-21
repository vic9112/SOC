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

![螢幕擷取畫面 2023-11-21 194643](https://github.com/vic9112/SOC/assets/137171415/ba4076ee-d9d8-4b0e-94c4-163bcd2ca741)

![螢幕擷取畫面 2023-11-21 194624](https://github.com/vic9112/SOC/assets/137171415/acb7f54b-6b57-41b4-89a2-3593b8bb500f)
