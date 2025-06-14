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


### Origin Design / Bottleneck

- During this lab, we have encounter some problem cause by the latency of CPU access data:

![螢幕擷取畫面 2024-01-17 145602](https://hackmd.io/_uploads/Sk8VcgrtT.png)

- Orange part is the latency hardware calculating FIR, and the blue part is the latency CPU fetch code from user project and execute.
- Origin run in **7497 cycles** for FIR calculating.

![螢幕擷取畫面 2024-01-17 145907](https://hackmd.io/_uploads/Hy6pqeSYa.png)

While our ability to make significant changes to the hardware is limited, there are still potential improvements we can make in optimizing the time it takes for the CPU to read assembly code:

- Instruction Pipeline Optimization: Evaluate and optimize the instruction pipeline to enable the concurrent execution of instructions in different stages, enhancing overall execution efficiency. This can be achieved through redesigning pipeline stages or increasing instruction caching.
- Cache Optimization: Ensure that frequently used instructions and data are stored in high-speed caches, reducing the need to fetch them from main memory and improving overall system performance."

- First, let's clarify some definitions.

![螢幕擷取畫面 2024-01-17 150225](https://hackmd.io/_uploads/SJQ5igBt6.png)

- Then take a look about the while loop in our origin firmware code:

![image](https://hackmd.io/_uploads/r1e82lrK6.png )

- It generate the following assembly code:

![螢幕擷取畫面 2024-01-17 150617](https://hackmd.io/_uploads/By9uhxBKa.png)

- But we only get the cache deph of 16 in our Caravel SOC:

![image](https://hackmd.io/_uploads/SkoA3lSFT.png)

- CPU has 16 instructions cache, but loop code has 17 instructions.

**So, our first goal is to shorten the assembly code**

### Optimization

![螢幕擷取畫面 2024-01-17 151008](https://hackmd.io/_uploads/By8PTlBKa.png )

- We can add the command -O2, -O3, -Ofast to optimize the assemnly code generated by our riscv tool. Results show below:

![螢幕擷取畫面 2024-01-17 151143](https://hackmd.io/_uploads/Syk6alSFa.png )

- **Executes in 1701T**

![螢幕擷取畫面 2024-01-17 151252](https://hackmd.io/_uploads/SyqZRxBYa.png)

![螢幕擷取畫面 2024-01-17 151345](https://hackmd.io/_uploads/rJv4AerF6.png)

- Result:
![螢幕擷取畫面 2024-01-17 151413](https://hackmd.io/_uploads/rJHUAlHYT.png)

### **Futher Optimization**

- We can do futher optimization by re-ordering some of assembly codes.

- Original code:

![image](https://hackmd.io/_uploads/Hyzlr-Btp.png)

![螢幕擷取畫面 2024-01-17 154300](https://hackmd.io/_uploads/Sk7EHWHY6.png)

- Re-order to the following result:

![螢幕擷取畫面 2024-01-17 154536](https://hackmd.io/_uploads/HJm2BZSFa.png)

- Y->X result

![螢幕擷取畫面 2024-01-17 154612](https://hackmd.io/_uploads/H100BZBFT.png)

### Some Problem

- We may wonder why there is a `STB` without `CYC` here:

![螢幕擷取畫面 2024-01-17 154807](https://hackmd.io/_uploads/SJrBIWrtp.png)

![螢幕擷取畫面 2024-01-17 154836](https://hackmd.io/_uploads/rygDL-BFp.png)

![螢幕擷取畫面 2024-01-17 154906](https://hackmd.io/_uploads/Hykt8ZrKT.png )

![螢幕擷取畫面 2024-01-17 155110](https://hackmd.io/_uploads/rJGZw-HK6.png)

![螢幕擷取畫面 2024-01-17 155143](https://hackmd.io/_uploads/BkxmDWBFa.png)
