# SOC Lab Final Project

[TOC]

---

## Computation System Overview

在本次 final project 中，我們根據 Lab 4、Lab 6 的基礎，設計Arbitrary、DMA、SDRAM 與硬體加速器，希望能夠改進先前的結果。硬體加速器的部分包含之前 Lab3、4 使用的 Fir 以及新設計的 Matrix Multipication 和 Qsort 三個 module，利用三個DMA去配合它們的資料傳輸，而彼此資料的先後順序交由 Arbitrary 這個 module 去權重。而儲存instructions 和 data sets 的工作則使用 SDRAM，讓硬體不必透過 CPU 去收發資料以減少 cycle。進一步的 Prefetch 設計能在 3T 的 latency 中拿取更多的 Data，能夠再減少用於抓資料的時間。

![image](https://hackmd.io/_uploads/rJ4f2cMFT.png)


---

## Firmware
先更改section.ids ，這是為了把需要計算的data放在SDRAM。

 ![螢幕擷取畫面 2024-01-16 212642](https://hackmd.io/_uploads/Hyy4E-4tT.png =40%x) ![螢幕擷取畫面 2024-01-16 212631](https://hackmd.io/_uploads/HJImV-4Kp.png =50%x)

我們的 Firmware 在這次的 final project 主要用於設定資料地址以及確認完成所有運算。A、B、C 為矩陣乘法用到的位置，X、Y 為 FIR 用到的位置，Q 為 qsort 用到的位置。

![image](https://hackmd.io/_uploads/BJavg5MFT.png)

![image](https://hackmd.io/_uploads/HkFsxcMYp.png)

![image](https://hackmd.io/_uploads/ByEbZcfFa.png)

由於這三種運算是同時進行，因此我們從 waveform 判斷 FIR 是運行最慢的，因此我們設定當收到 FIR 最後的資料就回到 AB51，同時我們也可以藉由此方法來判斷我們的算完的值確實也寫入SDRAM的位置。

![image](https://hackmd.io/_uploads/S1LSb9MYa.png)

---

## Hardware Accelerator

在 Lab 6 中，我們利用 firmware code 在 carvel soc 上跑 fir、mm、qs，但是 cpu 運算的時間過長，因此希望透過使用硬體去加快它們的計算速度。

### FIR & DMA

![image](https://hackmd.io/_uploads/SkBFPZVF6.png)

Fir 的設計沿用在 Lab3、4 的架構，並加上 Y_buffer 讓 DMA 到 Buffer 去接收計算完的 data。當 Fir 計算完成時會送資料到 y_buffer 並送出 full 的訊號讓 DMA 接收資料，同時也等待 DMA 送新的 X 進來。

![image](https://hackmd.io/_uploads/HJ2skYGF6.png)

DMA_fir 的功能涵蓋先前 Lab 4 的 decoder 與 DMA 本身，其運作圍繞 4 個 state，分別是 RESET、IDLE、X_addr 與 Y_addr。

首先，在 IDLE state 時若發現 X_FF 是空的 (~x_FF_full)，就會進入 X_addr state 去等待 arb 送資料進來，而當dma_ack_o 拉起來時便會回到 IDLE；而若 X_FF 是滿的而 y_FF 也是滿的 (y_FF_full) ，則會進入 Y_addr state 等待 arb 來收資料，而當dma_ack_o 拉起來時也會回到 IDLE。

![image](https://hackmd.io/_uploads/ryzRUtGKT.png)


### Matrix Multiplication

MM 的 datapath 如下圖，我們使用 shift register 去設計 A_Ram、B_Ram 讓它配合後面乘法的步驟。我們一樣採用 pipeline 的設計，讓它在 16 個cycle 就能算完所有的 data。

![image](https://hackmd.io/_uploads/ByvbsKGFT.png)



### Q Sort
我們利用insert sorting的方法來插入，利用十個比較器，找出index來決定要插入的位置。

![image](https://hackmd.io/_uploads/HkPL1qzKT.png =50%x) ![image](https://hackmd.io/_uploads/r1zMyqMt6.png)

### Arbitrary
有優先順序的arb。
![image](https://hackmd.io/_uploads/rkqmkMEK6.png)



---


## SDRAM with SDRAM Controller

### Original Block Diagram

- The overall diagram of SDRAM are shown below:
![螢幕擷取畫面 2024-01-16 211732](https://hackmd.io/_uploads/SyJbM-Vta.png)

- The wishbone cycle will pass through SDRAM controller and store/write data from/into SDRAM. We have do some optimize since the memory size of the original source code of SDRAM is not enough.

#### FSM in SDRAM controller:

![螢幕擷取畫面 2024-01-16 215237](https://hackmd.io/_uploads/ryYVcWNFp.png)

- Some details about each state:

![螢幕擷取畫面 2024-01-16 215401](https://hackmd.io/_uploads/H1s5c-4YT.png)

- **tCASL=3T tPRE=3T tACT=3T tREF=7T**

#### In SDRAM:

![螢幕擷取畫面 2024-01-16 215526](https://hackmd.io/_uploads/S19Acb4Fp.png)

- We decode the command sent from controller and mode register defined by user.

![螢幕擷取畫面 2024-01-16 215632](https://hackmd.io/_uploads/HJkmi-VKp.png)

- Read/write enable and address/data input/output

![螢幕擷取畫面 2024-01-16 221328](https://hackmd.io/_uploads/rJrSyMVYp.png)

- Command pipelined

![螢幕擷取畫面 2024-01-16 221527](https://hackmd.io/_uploads/HkAF1f4tp.png)

- MUX select the operation at current state.
- MUX detect read/write command.


**We may be curious about the meaning of `Active` state and `Precharge` state. Here we have a brief explanation about SDRAM:**

1. Dynamic Storage:
    *SDRAM stores data in cells that use capacitors to hold charges. SDRAM cells lose their charge over time due to leakage. To maintain the stored data, SDRAM needs to periodically refresh the charges in the cells.*
3. Row Activation:
    *Activating a row in SDRAM involves loading the contents of that row into a row buffer for read/write operations, which allows for faster access to the data in the row.*
5. Precharge Operation:
    *After accessing a row, it needs to be precharged to restore the charge in the cells. This is essential for the proper functioning of the memory and to prepare it for the activation of others rows.*


### Problems/Solved about Original code:

#### Problem 1 - Address Mapping

``` verilog=
`define BA 9:8
`define RA 22:10
`define CA 7:0
```
- We may encounter a situation that all data are stored in the same bank since our linker was designed as shown below:

![螢幕擷取畫面 2024-01-16 212631](https://hackmd.io/_uploads/HJImV-4Kp.png)

![螢幕擷取畫面 2024-01-16 212642](https://hackmd.io/_uploads/Hyy4E-4tT.png)

- Each data type needs at least 12-bit,but SDRAM only takes 8-bit for column address, and bank_address[9:8] will restrict our size.

#### Problem 2 - Address send into SDRAM

- In SDRAM, we have 4 banks to store data, source code are shown below:

``` verilog=
blkRam$(.SIZE(mem_sizes), .BIT_WIDTH(DQ_BITS))
Bank0(
    .clk(Sys_clk),
    .we(bwen[0]),
    .re(bren[0]),
    .waddr(Col_brst[9:0]),
    .raddr(Col_brst[9:0]),
    .d(bdi[0]),
    .q(bqd[0])
);
```

- Only 10-bit for column address

``` verilog=
READ: begin
    cmd_d = CMD_READ;
    a_d = {2'b0, 1'b0, addr_q[7:0], 2'b0};
    state_d = WAIT;
end
```

- Since the address of assembly code plus 4 each time, we may not need to add the 2’b0 at the LSB. 

=> **Original memory size: 2^10(width)/4(shift left) * 4(banks) = 1K bytes**

#### Solution

- My design (remapping)
``` verilog=
`define Ba 13:12
`define Ra 22:14
`define CA 11:0
```
- Then we can get 12 bits for column address.

- I also remap the `a_d` since `a_d[10]`is the precharge signal. Note that `BA` is 13:12.

``` verilog=
READ: begin
    cmd_d   = CMD_READ;
    a_d     = {addr_q[11:10], 1'b0, addr_q[9:0]};
    ba_d    = addr_q[9:8];
    state_d = WAIT;
end
```

- When read:

``` verilog=
If (Read_enable) begin
    Bank     <= Ba;
    Col      <= {Addr[12:11], Addr[9:0]};
    Col_brst <= {Addr[12:11], Addr[9:0]};
end
```

- Decode the remapping address, prevent the `addr[10]` (precharge bit) load into block memory.

- Now, address load into memory have 12 bits:

``` verilog=
blkRam$(.SIZE(mem_sizes), .BIT_WIDTH(DQ_BITS))
Bank0(
    .clk(Sys_clk),
    .we(bwen[0]),
    .re(bren[0]),
    .waddr(Col_brst[11:0]),
    .raddr(Col_brst[11:0]),
    .d(bdi[0]),
    .q(bqd[0])
);
```

- Also, seems that the block memory in the source code don't have the row address, it may not support the on/off page characteristic.

=> **Memory size: 2^12(width) * 4 = 16K bytes**

---

## Optimization

我們先知道如果資料讀取順利，latancy=1T的狀況下，這三個硬體所需要的時間分別為 64x11=704 (fir)、10x2+10+10x2=50 (qsort)、32x2+16+16=96 (mm)。所以我們優化目標應該以此最長的cycle為優化目標。

首先第一部分，我們的設計如下：

![image](https://hackmd.io/_uploads/rJ4f2cMFT.png)


我們分別去測量fir qsort mm 所需時間分別為
fir (1471 cycles)

![image](https://hackmd.io/_uploads/HyuYOZVFp.png)

mm (756 cycles)

![image](https://hackmd.io/_uploads/SJd4_-EtT.png)

qsort (315 cycles)

![image](https://hackmd.io/_uploads/rJgYu-NKT.png)

但是因為有arb的功用其實可以concurrent!

所以實際上完成三個的時間為(1570):

![image](https://hackmd.io/_uploads/Hkm2K-EY6.png)


waveform:

![image](https://hackmd.io/_uploads/rJns1GVtT.png)

![image](https://hackmd.io/_uploads/ryx1ezNF6.png)

![image](https://hackmd.io/_uploads/B1rWlGNKp.png)


所以由上面我們可以知道SDRAM的read至少多要花7個cycle才會回ack。所以如果要進一步的優化，我們要設計sdram有burst的功能並且搭配prefetch。

---

## SDRAM with Prefetch Buffer

### Design Consideration

- Here we may want to prefetch data for faster reading access since SDRAM have the 3T delay for CAS latency when reading.


### Block Diagram

![螢幕擷取畫面 2024-01-16 220839](https://hackmd.io/_uploads/H1mfCZ4K6.png)

### Prefetch Buffer:

![螢幕擷取畫面 2024-01-16 223444](https://hackmd.io/_uploads/SJrGEMNt6.png)

- We have 3 prefetch buffers (FIR/MM/QS), here I use FIR buffer to explan our idea.

Our prefetch buffer acts like shift registers, it shift out the stored data when the read access came. It prefetch data untill all buffers are filled up before our workload start. If the buffer is empty, controller will send a `Empty` signal to tell the **arbiter** to let the priority of that buffer to be the last since the status of that buffer is `busy`, it is being filled up.


### Prefetch Controller:

![螢幕擷取畫面 2024-01-16 223725](https://hackmd.io/_uploads/Hyn3NM4K6.png)

Above figure shows our design about prefetch controller.

--- Setup
- When setup(before all buffers are FULL), data will store in SDRAM first.
- After we got the initial address(sent by DMA) => start prefetch.
- Fill the data until it buffer length, then set the state of that buffer to 'FULL'.
- After all prefetch buffer is 'FULL', call ap_start.

--- Running
- If input address meet the saving address => HIT
- If HIT, terminate the wishbone read request by sending the ACK immediately.
- If the buffer is Empty, start prefetch the data from SDRAM into buffer.

### SDRAM burst

- Since our prefetch buffer have the length of 8, if we can achieve the burst length of 8, it can fill up the empty buffer rapidly.











#### burst result

![image](https://hackmd.io/_uploads/HJCdOGNKa.png)

![image](https://hackmd.io/_uploads/HyD1tzVKT.png)

![image](https://hackmd.io/_uploads/H1SIFGEFa.png)

![image](https://hackmd.io/_uploads/B12gcMVYT.png)


---

## Uart with I/O FIFO
### Design for Optimization
Original UART implementation flow vs.  UART with FIFO
![image](https://hackmd.io/_uploads/H1Hxw0GKa.png =40%x) to![image](https://hackmd.io/_uploads/BkoqPAzFp.png =50%x)
With FIFO, we can lower the number of interrupt to make the execution faster since we can first keep the data sent in the buffer and wait until the buffer is full, then we send the data all at once.
### How to implement into original design
![image](https://hackmd.io/_uploads/ByImR14Y6.png)
Signals in FIFO
![IMG_1852](https://hackmd.io/_uploads/S1B6YbNt6.jpg)
![JPEG影像-4094-965B-FD-0](https://hackmd.io/_uploads/SJCedWNY6.jpg) 


#### Simulation
In simulation we only sent 8 data.

**Without FIFO**
![IMG_1847](https://hackmd.io/_uploads/BJrDyxNK6.jpg)
Latnecy=8397900ns

**FIFO with depth 4**
![IMG_1849](https://hackmd.io/_uploads/S1EEegEFp.jpg)
Latnecy=1966020ns


### **FPGA**
In FPGA, we sent 512 data.
**Without FIFO**
![IMG_1850](https://hackmd.io/_uploads/SJdWkgVta.jpg)
Latency = 2.68s
**FIFO with depth 4**
![IMG_1848](https://hackmd.io/_uploads/B19y1lEFa.jpg)
Latency = 2.17s
#### Performance
|       | Latency(cycle * period) | Metric(ms) | Improvement |
|:-----:|:--------:|:-------------------------:|:-------------------------:|
|  Without FIFO       |  114582 * 25ns   |          44.78           |  *  |
|  FIFO depth 4       |  54076  * 25ns   |          10.48           |4.27x|



---

## Performance Summary

|       | Software(cycles) | Hardware without prefetch(cycles) | Hardware with prefetch (cycles)  |
|:-----:|:--------:|:-------------------------:|:-------------------------: |
|  MM   |  55303   |            756            |    X(no test)                       |
|  FIR  |  65890   |            1471           |  X(no test)                       |
|  QS   |  14394   |            315            |     X(no test)
Total| 135587|1570|801

---

## Problem & Solution


