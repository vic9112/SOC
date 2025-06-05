#include "fir.h"
#include <stdint.h>

void __attribute__ ( ( section ( ".mprjram" ) ) ) initfir() {
	
	// program data length
	wb_write(reg_fir_len, data_length);

	// program coefficient
	for (uint32_t i = 0; i < 11; i++) {
		wb_write(adr_ofst(reg_fir_coeff, 4*i), taps[i]);
	}

}

void __attribute__ ( ( section ( ".mprjram" ) ) ) fir_excute() {
	// StartMark
        wb_write(checkbits, 0x00A50000);

        // ap_start
        wb_write(reg_fir_ap_ctrl, 0x1);
	
        uint8_t register t = 0;
//        uint8_t register x = 0;
//        int8_t  register y = 0;

        while (t < data_length) {
                // check ap_ctrl[4] (ss_tready is asserted)
//                if (wb_read(reg_fir_ap_ctrl) == 0x10) {
                        wb_write(reg_fir_x_in, t); // write X into fir
//                        x++;
//                }
                // check ap_ctrl[5] (sm_tvalid is asserted)
//                if (wb_read(reg_fir_ap_ctrl) == 0x20) {
                        outputsignal[t] =  wb_read(reg_fir_y_out);  // read Y from fir
                        t = t + 1;
//                }
        }

        // let TB check the final Y by using MPRJ[31:24]
        // and send the EndMark 5A signal at MPRJ[23:16]
        // check ap_done
        wb_read(reg_fir_ap_ctrl);
        wb_write(checkbits, outputsignal[N-1] << 24 | 0x005A0000);
        
}

