# Combine 4 Workloads and Execute on Caravel SoC

- Also can refer to Report.pdf for more details when we working in this project.

## Simulation for 4 Workloads (Test INTERRUPT)

```sh
$ cd ~/Lab6-wlos/testbench/combined
$ source run_clean
$ source run_sim
```
- Result:

![螢幕擷取畫面 2023-12-17 215416](https://github.com/vic9112/SOC/assets/137171415/e1864ce1-7854-40eb-ba38-3dcf4979d20d)

Above we can see that the INTERRUPT let us execute UART and FIR parallelly.

## Host Code (Jupyter Notebook) Simulation on PYNQ Board

- Since the speed of sampling data in python is much slower than the speed of verilog testbench,
- we need to add while loop on the signal we want to test, as following:

![螢幕擷取畫面 2023-12-17 231852](https://github.com/vic9112/SOC/assets/137171415/50079de1-6d29-4d94-a92d-854f1661ea85)

![螢幕擷取畫面 2023-12-17 231903](https://github.com/vic9112/SOC/assets/137171415/6cff69a5-b720-439e-803c-394df562ee55)

- Result:

![螢幕擷取畫面 2023-12-17 215318](https://github.com/vic9112/SOC/assets/137171415/e8cca2d6-d8ee-4da6-a17a-438b5eb9fc2f)
