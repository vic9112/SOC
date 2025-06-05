#ifndef __FIR_H__
#define __FIR_H__

#define reg_fir_ap_ctrl  0x30000000 // ap_control

#define reg_fir_len      0x30000010 // data length
#define reg_fir_tap      0x30000014 // tap length

#define reg_fir_coeff    0x30000080 // Load into TapRAM

#define reg_fir_x_in     0x30000040 // Load X into DataRAM
#define reg_fir_y_out    0x30000044 // Take the output Y

#define checkbits        0x2600000C // MPRJ I/O

#define N 64
#define data_length N
//#define H 11
#define H 12
//#define H 15
//#define H 32
#define tap_length H

int taps[32] = {4, -6, 9, -6, 7, -4, 3, 0, -7, 4, 2, -7, -7, -9, 1, 6, -8, 9, 8, 5, -9, 4, -8, -7, -7, -6, 3, -3, 2, 5, -9, 10};

int outputsignal[N];

#define adr_ofst(target, offset) (target + offset)
#define wb_write(target, data)   (*(volatile uint32_t*)(target)) = data // wishbone write
#define wb_read(target)          (*(volatile uint32_t*)(target))        // wishbone read 



#endif
