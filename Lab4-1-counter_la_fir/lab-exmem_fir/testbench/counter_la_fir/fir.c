#include "fir.h"


void __attribute__ ( ( section ( ".mprjram" ) ) ) initfir() {
	//FIR initialize:
	for (int i = 0; i < N; i++) {
		inputbuffer[i]  = 0; // for data shift-in
		outputsignal[i] = 0;
	}
}

// Referred to the source code of lab2-FIR
int* __attribute__ ( ( section ( ".mprjram" ) ) ) fir() {
	initfir();
	//FIR operation
	// Y[t]
	for (int t = 0; t < N; t++) {
		// Data shift-in
		for (int l = N - 1; l > 0; l--) {
			inputbuffer[l] = inputbuffer[l - 1];
		}
		inputbuffer[0] = inputsignal[t];

		int y = 0; // initialize Y

		for (int i = 0; i < N; i++) {
			// Y[t] = sigma(h[i] * X[t-i])
			y += taps[i] * inputbuffer[i];
		}
		outputsignal[t] = y;
	}

	return outputsignal;
}
		
