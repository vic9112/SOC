//////////////////////////////////////////////////////////
// Design: FIR engine
// Author: Kuan-Hsi(Vic) Chen
// Email : s179038@gmail.com
// Update: [2025/03/10]: FIR engine
//         [2025/03/15]: Enable read tap when processing
//         [2025/04/03]: Disable read tap when processing
//         [2025/04/03]: Add Latch to decouple stream-in interface and data_RAM
//////////////////////////////////////////////////////////
`default_nettype wire

module fir 
#(  parameter pADDR_WIDTH = 12,
    parameter pDATA_WIDTH = 32
)
(
    output  wire                     awready,
    output  wire                     wready,
    input   wire                     awvalid,
    input   wire [(pADDR_WIDTH-1):0] awaddr,
    input   wire                     wvalid,
    input   wire [(pDATA_WIDTH-1):0] wdata,
    output  wire                     arready,
    input   wire                     rready,
    input   wire                     arvalid,
    input   wire [(pADDR_WIDTH-1):0] araddr,
    output  wire                     rvalid,
    output  wire [(pDATA_WIDTH-1):0] rdata,    
    input   wire                     ss_tvalid, 
    input   wire [(pDATA_WIDTH-1):0] ss_tdata, 
    input   wire                     ss_tlast, 
    output  wire                     ss_tready, 
    input   wire                     sm_tready, 
    output  wire                     sm_tvalid, 
    output  wire [(pDATA_WIDTH-1):0] sm_tdata, 
    output  wire                     sm_tlast, 
    
    // bram for tap RAM
    output  wire [3:0]               tap_WE,
    output  wire                     tap_EN,
    output  wire [(pDATA_WIDTH-1):0] tap_Di,
    output  wire [(pADDR_WIDTH-1):0] tap_A,
    input   wire [(pDATA_WIDTH-1):0] tap_Do,

    // bram for data RAM
    output  wire [3:0]               data_WE,
    output  wire                     data_EN,
    output  wire [(pDATA_WIDTH-1):0] data_Di,
    output  wire [(pADDR_WIDTH-1):0] data_A,
    input   wire [(pDATA_WIDTH-1):0] data_Do,

    input   wire                     axis_clk,
    input   wire                     axis_rst_n
);
    //  (pDATA_WIDTH-1)
    reg [              9:0] x_len, h_len, x_cnt, y_cnt; // Configuration registers for testbench/SoC | Count the data number in RAM | Count the calculated Y
    reg                     x_cnfg, h_cnfg;             // check if x_len and h_len are configured
    reg [(pADDR_WIDTH-3):0] i, t;                       // Address for data_RAM and tap_RAM (use decimal): y[t] = h[i] * x[t-i]
    reg [(pDATA_WIDTH-1):0] x, h, m, y;                 // x[t-i], h[i], x * h, y[t]
    reg [(pADDR_WIDTH-1):0] init_addr;                  // data RAM initialize address
    reg [(pDATA_WIDTH-1):0] data_ff;                    // Latch the stream-in data X

    reg [(pADDR_WIDTH-1):0] i_l, t_l;      // Latch address
    reg [(pDATA_WIDTH-1):0] x_l, h_l, m_l; // Latch data
    reg                     fir_en_q, run_q, sm_tvalid_q, x_full_q; // Capture the trigger of arvalid or sm_tvalid

    reg       ap_start, ap_done, ap_idle;
    reg [3:0] pipeline_y; // 4 stages pipeline: If  last_y in stage 4 (Y calculated) => sm_tvalid
    reg [2:0] pipeline_x; // 4 stages pipeline: if first_x in stage 3 (accumulation) => restart the accumulation of Y
    reg       run;        // If y_out is transfered, then keep running the next convolution
    reg       ss_en;      // Control the stream-in enable
    reg       ff_valid;   // asserted when data_ff have stored value. if not, trigger ss_tready

    reg  awready_q, arready_q, wready_q, rvalid_q;
    reg  [(pDATA_WIDTH-1):0] rdata_q;
    wire [(pDATA_WIDTH-1):0] y_new, y_old;
    wire [(pADDR_WIDTH-1):0] h_addr, x_addr;
    wire x_full, x_init, x_last, x_strt, y_done, fir_en, read_h;
    wire x_ready; // when data RAM is ready for new data
 
    assign rvalid  =  rvalid_q;
    assign arready = arready_q;
    assign awready = awready_q;
    assign wready  =  wready_q;
    assign rdata   =   rdata_q;
    //////////
    assign ss_tready = ss_en & (~ff_valid); // if can receive stream data
    assign x_ready   = x_init & (~x_full) & (~ap_idle); // data_RAM is initialized & not full
    //////////
    assign sm_tvalid = (y_done);
    assign sm_tdata  = y;
    assign sm_tlast  = (~ap_idle & sm_tvalid & (y_cnt == x_len-1)); // If the last Y is calculated

    assign h_addr = {i, 2'b00}; // Coefficient: h[i]
    assign x_addr = (i <= t)? {(t - i), 2'b00} : {(h_len + (t - i)), 2'b00}; // Data: x[t - i]
    assign x_full = (h_cnfg & (x_cnt == h_len));   // Check if data RAM is full (updated)
    assign x_last = ((i == h_len-1) & (~ap_idle)); // Check if this is the last x in convolution
    assign x_strt = ((i == 0) & (~ap_idle));       // Check if this is the first x in convolution and start the first pipeline stage {x_strt, pipeline_x[2:1]}
    assign x_init = (h_cnfg & (init_addr[(pADDR_WIDTH-1):2] == h_len)); // data RAM initialize
    assign y_done = pipeline_y[0];       // y_done: finish current y's convolution
    assign read_h = arvalid & araddr[7]; // read tap RAM
    assign fir_en = (x_init & x_cnfg & run & ((x_full | (ff_valid & x_ready)) | (y_cnt == x_len-1))); // for pipeline stage and address generator
    
    // Restart the accumulation of y when a new convolution start and flow through the pipeline stage 3 (accumulation)
    // pipeline_x[0] Means new FIR product(m) flow through this stage_Y (i == 3)
    assign y_new = (sm_tvalid & ~sm_tready)? 0 : ((~run_q & run) || pipeline_x[0])? m   : m;
    assign y_old = (sm_tvalid & ~sm_tready)? y : ((~run_q & run) || pipeline_x[0])? m_l : y;

    assign tap_EN = (awaddr[7] | araddr[7] | ~ap_idle);  // check if address start from 0x80
    assign tap_WE = {4{(wvalid & awvalid & awaddr[7])}}; // expand to 4'b1111
    assign tap_A  = (awvalid & awaddr[7])? {{(pADDR_WIDTH-7){1'b0}}, awaddr[6:0]} : 
                    (ap_idle & read_h)?    {{(pADDR_WIDTH-7){1'b0}}, araddr[6:0]} : h_addr; // write first
    assign tap_Di = wdata;

    assign data_EN = ((~ap_idle | ~x_init)); // ss_tvalid or data RAM not initialize yet
    assign data_WE = {4{(x_ready | ~x_init)}}; // ss_tready or data RAM not initialize yet
    assign data_A  = (~x_init)? init_addr : x_addr;
    assign data_Di = (~x_init)? 0 : data_ff;

    // AXI-stream in enable
    always @(posedge axis_clk or negedge axis_rst_n) begin
        if (!axis_rst_n) ss_en <= 0;
        else begin
            if (ss_tlast & ss_tready & ss_tvalid) ss_en <= 0;
            else if (ap_start)                    ss_en <= 1;
        end
    end

    //----------------------------------------------------------------------------------
    // Assume CPU burst 2 data (1st&2nd), and 3rd X came after 20T ( > processing time )
    // Latch ss_tdata (if available) and return ss_tready immediately
    // Store the latched data into RAM once RAM is not full.
    //              .---------.         .----------.
    // ss_tdata --->| data_ff |----.--->| data_RAM |---> x (i!=1)
    //              '---------'    |    `----------'
    //               available?    |      not_full?
    //                             `---> x (i==1)
    // Waveform:
    // clk       |   |   |   |   |   |   |   .....   |   |   |
    // ss_tvalid ____/```````\_______________.....___/```\____
    // ss_tdata  ____X 0 X 1 X_______________________X 3 X____
    // ss_tready ````````````\_(processing...)_/`````````\____ (use as available signal of data_ff)
    // data_ff   ____X 0 X 1 ________________________X 3 _____
    // i         ____ 10 X 0 X 1 X 2 X ....... X 
    // x_full    ____/````````````````
    // data_WE   ____/```\___________
    //----------------------------------------------------------------------------------
    
    // Latch the stream-in X
    // In one clk cycle, if data RAM is written, it can't be read, use the data which stored in data_FF.
    always @(posedge axis_clk or negedge axis_rst_n) begin
        if (!axis_rst_n)                data_ff <= 0;
        else if (ss_tvalid & ss_tready) data_ff <= ss_tdata;
    end

    always @(posedge axis_clk or negedge axis_rst_n) begin
        if (!axis_rst_n) ff_valid <= 0;
        else begin
            if (ap_start)
                ff_valid <= 0;
            else if (x_ready & ff_valid)
                ff_valid <= 0;
            else if (ss_tvalid & ss_tready) // If receive data
                ff_valid <= 1;
        end
    end

    // Handle 1. AXI-read 2. Y finished 3. Y stalled 4. data FF, when proccessing
    always @(posedge axis_clk) fir_en_q    <= fir_en;
    always @(posedge axis_clk) run_q       <= run;
    always @(posedge axis_clk) sm_tvalid_q <= sm_tvalid;
    always @(posedge axis_clk) x_full_q    <= x_full;

    always @(posedge axis_clk or negedge axis_rst_n) begin
        if (!axis_rst_n) begin
            x_l <= 0;
            h_l <= 0;
            m_l <= 0;
        end else begin // if AXI read request(arvalid), latch the current output from RAMs | if sm_tvalid but slave can't take it, capture the current data(x), coefficient(h), product(m)
            x_l <= (fir_en_q & ~fir_en)? data_Do : (sm_tvalid & ~sm_tready & fir_en)? x : x_l;
            h_l <= (fir_en_q & ~fir_en)?  tap_Do : (sm_tvalid & ~sm_tready & fir_en)? h : h_l;
            m_l <= (sm_tvalid & ~sm_tready & fir_en)? m : (sm_tvalid_q & ~sm_tvalid)? 0 : m_l;
        end                                              // Means the current Y is finished, clear the accumulation
    end


    // Check if the data_RAM is updated: x_cnt == h_len?
    always @(posedge axis_clk or negedge axis_rst_n) begin
        if (!axis_rst_n)
            x_cnt <= 0;
        else // Receive new X => x_cnt + 1; final x in current convolution(fir_en) been taken => x_cnt - 1
            x_cnt <= (x_init)? (fir_en & (i == h_len-1))? x_cnt - 1 : (ff_valid & x_ready)? x_cnt + 1 : x_cnt : (h_len - 1); // (ss_tready & ss_tvalid)
    end

    always @(posedge axis_clk or negedge axis_rst_n) begin
        if (!axis_rst_n) begin
            rvalid_q  <= 0;
            arready_q <= 0;
            awready_q <= 0;
            wready_q  <= 0;
            rdata_q   <= 0;
        end else begin
            rvalid_q  <= (rvalid & rready)? 0 : (arvalid & arready)? 1 : rvalid;
            arready_q <= (arvalid & ~arready);
            awready_q <= (awvalid & wvalid & ~awready);
            wready_q  <= (awvalid & wvalid & ~wready);
            rdata_q   <= (arvalid & arready)? (araddr[7])? (ap_idle)? tap_Do : 32'hFFFF_FFFF :
                                              (araddr == 12'h000)? {29'd0, ap_idle, ap_done, ap_start} :
                                              (araddr == 12'h010)? x_len : 
                                              (araddr == 12'h014)? h_len : rdata : rdata;
        end
    end

    // For data RAM initialize: x_init = init_addr == h_len - 1
    always @(posedge axis_clk or negedge axis_rst_n) begin
        if (!axis_rst_n)
            init_addr <= 0;
        else begin
            if (ap_done) init_addr <= 0; // ap_done reset the init_addr
            else         init_addr <= (x_init)? init_addr : {(init_addr[(pADDR_WIDTH-1):2] + 1'b1), 2'b00};
        end
    end

    // For AXI-lite configuration write & read
    always @(posedge axis_clk or negedge axis_rst_n) begin
        if (!axis_rst_n) begin
            x_len <= 32'd0;
            h_len <= 32'd0;
            x_cnfg <= 0;
            h_cnfg <= 0;
        end else begin
            if (ap_idle & awvalid & wvalid & (awaddr == 12'h010)) begin
                x_len  <= wdata;
                x_cnfg <= 1;
            end
            if (ap_idle & awvalid & wvalid & (awaddr == 12'h014)) begin
                h_len  <= wdata;
                h_cnfg <= 1;
            end
        end
    end

    // Control signals (ap_start, ap_done, ap_idle)
    always @(posedge axis_clk or negedge axis_rst_n) begin
        if (!axis_rst_n) {ap_idle, ap_done, ap_start} <= 3'b100;
        else begin
            if ((ap_idle) & awvalid & wvalid & wready & (awaddr == 12'h000)) ap_start <= 1;
            else                                                             ap_start <= 0;
            if      (ap_start)                                               ap_idle  <= 0;
            else if (ap_done)                                                ap_idle  <= 1;
            if      (sm_tlast & sm_tready & sm_tvalid)                       ap_done  <= 1; // after last data transferred => ap_done
            else if ((ap_done) & arvalid & arready & (araddr == 12'h000))    ap_done  <= 0; // clear ap_done if read 0x00
        end
    end

    // Control the datapath pipeline stage
    always @(posedge axis_clk or negedge axis_rst_n) begin
        if (!axis_rst_n) run <= 0;
        else begin
            if      (ap_start)  run <= 1;
            else if (ap_done)   run <= 0;
            else if (sm_tvalid) run <= (sm_tready)? 1 : 0;
        end
    end

    // Address for x and h: y[t] = E h[i] * x[t-i]
    always @(posedge axis_clk or negedge axis_rst_n) begin
        if (!axis_rst_n) begin
            i <= {(pADDR_WIDTH-1){1'b0}};
            t <= {(pADDR_WIDTH-1){1'b0}};
        end else begin // if 1. Y-out is valid but not taken 2. DATA_RAM need update => stall
            if (fir_en | (sm_tvalid & sm_tready)) begin // address update is permitted if arready assert in the next cycle when arvalid came
                i <= ((sm_tvalid & ~sm_tready))? i : (i != (h_len - 1))? i + 1 : 0;
                t <= ((sm_tvalid & ~sm_tready))? t : (i == (h_len - 1))? ((t != h_len - 1)? t + 1 : 0) : t;
            end else if (ap_done) begin // Reset convolution address when ap_done
                i <= 0;
                t <= 0;
            end
        end
    end

    // FIR pipeline stage: | Stage 0: get address | Stage 1: get data | Stage 2: multiplication | Stage 3: accumulation | Stage 4: output |
    always @(posedge axis_clk or negedge axis_rst_n) begin
        if (!axis_rst_n) begin
            x <= 0;
            h <= 0;
            m <= 0;
            y <= 0;
        end else if (fir_en) begin // Enable shifting when "fir_en" | "(run & ~fir_en_q & fir_en)": arvalid/sm_tvalid gone=> use the latched data
            x <= (run & ~fir_en_q & fir_en)? x_l : (x_full & ~x_full_q)? data_ff : data_Do; // RAM can't be read & write at the same time, so use the latched data when x stored into RAM (i==1)
            h <= (run & ~fir_en_q & fir_en)? h_l : tap_Do; // If AXI-lite read transaction done, resume with the latched data
            m <= x * h;
            y <= y_new + y_old;  
        end
    end

    // Pipeline stage shifting
    always @(posedge axis_clk or negedge axis_rst_n) begin
        if (!axis_rst_n) begin
            {pipeline_y} <= 0;
            {pipeline_x} <= 0;
        end else if ((fir_en | sm_tvalid)) begin // stall if Y-out have not been taken
            {pipeline_y} <= (sm_tvalid)? (sm_tready)? {x_last, pipeline_y[3:1]} : {pipeline_y}: {x_last, pipeline_y[3:1]}; // To know whether last X is finished => Y (stage 4)
            {pipeline_x} <= {x_strt, pipeline_x[2:1]}; // To know whether 1st X flow through accumulation stage (stage 3)
        end
    end

    // Count the transfered Y
    always @(posedge axis_clk or negedge axis_rst_n) begin
        if (!axis_rst_n) y_cnt <= 0;
        else             y_cnt <= (ap_idle)? 0 : (sm_tvalid & sm_tready)? y_cnt + 1 : y_cnt;
    end

endmodule