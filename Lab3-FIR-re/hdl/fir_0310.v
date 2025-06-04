///////////////////////////////////////////////
// Design: FIR engine
// Author: Kuan-Hsi(Vic) Chen
// Email : s179038@gmail.com
///////////////////////////////////////////////
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

    reg [(pDATA_WIDTH-1):0] x_len, h_len, x_cnt, y_cnt; // Configuration registers for testbench/SoC | Count the data number in RAM | Count the calculated Y
    reg                     x_cnfg, h_cnfg; // check if x_len and h_len are configured
    reg [(pADDR_WIDTH-3):0] i, t; // Address for data_RAM and tap_RAM (use decimal): y[t] = h[i] * x[t-i]
    reg [(pDATA_WIDTH-1):0] x_d, x_q, h_d, h_q, m_d, m_q, y_d, y_q, x, h, m, y;
    reg [(pADDR_WIDTH-1):0] init_addr;
    reg [(pDATA_WIDTH-1):0] data_ff; // Latch the data

    reg [(pADDR_WIDTH-1):0] i_l, t_l; // Latch for address
    reg [(pDATA_WIDTH-1):0] x_l, h_l, m_l; // Latch for data
    reg                     fir_en_d, fir_en_q, run_q; // Capture the trigger of arvalid or sm_tvalid

    reg [2:0] ap;             // bit0: ap_start; bit1: apone; bit2: ap_idle
    reg [3:0] pipeline_stage; // 4 stages; If last_y in stage 4 => sm_tvalid
    reg       run;            // If y_out is transfered, then keep running the next convolution
    reg       ss_en;          // Control the stream-in enable

    reg AWREADY, ARREADY, WREADY, RVALID;
    wire [(pADDR_WIDTH-1):0] h_addr, x_addr;
 
    assign rvalid  = RVALID;
    assign arready = ARREADY;
    assign awready = AWREADY;
    assign wready  = WREADY;
    assign rdata   = (arvalid)? (araddr[7])? tap_Do : (araddr == 12'h000)? ap : (araddr == 12'h010)? x_len : (araddr == 12'h014)? h_len : 0 : 0;

    assign ss_tready = ss_en & x_init & (~x_full) & (~ap[2]);
    assign sm_tvalid = (y_done);
    assign sm_tdata  = y;
    assign sm_tlast  = (~ap[2] & sm_tvalid & (y_cnt == x_len-1));

    assign h_addr = {i, 2'b00}; // Coefficient: h[i]
    assign x_addr = (i <= t)? {(t - i), 2'b00} : {(h_len + (t - i)), 2'b00}; // Data: x[t - i]
    assign x_full = (x_cnfg & (x_cnt == h_len)); // Check if data RAM is full (updated)
    assign x_last = ((i == h_len-1) & (~ap[2])); // Check if this is the last x in convolution
    assign x_init = (h_cnfg & (init_addr[(pADDR_WIDTH-1):2] == h_len)); // data RAM initialize
    assign y_done = pipeline_stage[0]; // y_done: finish current y's convolution
    assign fir_en = (x_init & run & ~(arvalid & araddr[7]) & (x_full | (ss_tready & ss_tvalid)) | (y_cnt == x_len-1)); // for pipeline stage and address generator

    assign tap_EN = (awaddr[7] | araddr[7] | ~ap[2]); // check if address start from 0x80
    assign tap_WE = {4{(wvalid & awvalid & awaddr[7])}}; // expand to 4'b1111
    assign tap_A  = (awvalid & awaddr[7])? {{(pADDR_WIDTH-7){1'b0}}, awaddr[6:0]} : 
                    (arvalid & araddr[7])? {{(pADDR_WIDTH-7){1'b0}}, araddr[6:0]} : h_addr; // write first
    assign tap_Di = wdata;

    assign data_EN = ((~ap[2] | ~x_init)); // ss_tvalid or data RAM not initialize yet
    assign data_WE = {4{(ss_tready | ~x_init)}}; // ss_tready or data RAM not initialize yet
    assign data_A  = (~x_init)? init_addr : x_addr;
    assign data_Di = (~x_init)? 0 : ss_tdata;

    // AXI-stream in enable
    always @(posedge axis_clk or negedge axis_rst_n) begin
        if (!axis_rst_n) ss_en <= 0;
        else begin
            if (ss_tlast & ss_tready & ss_tvalid) ss_en <= 0;
            if (ap[0])                ss_en <= 1;
        end
    end

    // Handle AXI-read when proccessing
    always @(posedge axis_clk) fir_en_q <= fir_en_d;
    always @(posedge axis_clk) run_q    <= run;
    always @*                  fir_en_d  = fir_en;

    always @(posedge axis_clk or negedge axis_rst_n) begin
        if (!axis_rst_n) begin
            x_l <= 0;
            h_l <= 0;
            m_l <= 0;
        end else begin // if there is arvalid or sm_tvalid, capture the current data(x), coefficient(h), product(m)
            x_l <= (fir_en_q & ~fir_en_d)? data_Do : (sm_tvalid & ~sm_tready & fir_en)? x : x_l;
            h_l <= (fir_en_q & ~fir_en_d)? tap_Do  : (sm_tvalid & ~sm_tready & fir_en)? h : h_l;
            m_l <= (sm_tvalid & ~sm_tready & fir_en)?  m : (i == 4)? 0 : m_l;
        end
    end

    always @(posedge axis_clk or negedge axis_rst_n) begin // Count the Y-out
        if (!axis_rst_n) y_cnt <= 0;
        else             y_cnt <= (ap[2])? 0 : (sm_tvalid & sm_tready)? y_cnt + 1 : y_cnt;
    end

    always @(posedge axis_clk or negedge axis_rst_n) begin
        if (!axis_rst_n) begin
            RVALID  <= 0;
            ARREADY <= 0;
            AWREADY <= 0;
            WREADY  <= 0;
        end else begin
            RVALID  <= (arvalid & rready & ~rvalid);
            ARREADY <= (arvalid & rready & ~arready);
            AWREADY <= (awvalid & wvalid & ~awready);
            WREADY  <= (awvalid & wvalid & ~wready);
        end
    end

    // For data RAM initialize: x_init = init_addr == h_len - 1
    always @(posedge axis_clk or negedge axis_rst_n) begin
        if (!axis_rst_n)
            init_addr <= 0;
        else begin
            if (ap[1])
                init_addr <= 0; // ap_done reset the init_addr
            else       
                init_addr <= (x_init)? init_addr : {(init_addr[(pADDR_WIDTH-1):2] + 1'b1), 2'b00};
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
            if (ap[2] & awvalid & wvalid & (awaddr == 12'h010)) begin
                x_len  <= wdata;
                x_cnfg <= 1;
            end
            if (ap[2] & awvalid & wvalid & (awaddr == 12'h014)) begin
                h_len  <= wdata;
                h_cnfg <= 1;
            end
        end
    end

    // Control signals (ap_start, ap_done, ap_idle)
    always @(posedge axis_clk or negedge axis_rst_n) begin
        if (!axis_rst_n) ap <= 3'b100;
        else begin
            if ((ap[2]) & awvalid & wvalid & wready & (awaddr == 12'h000)) ap[0] <= 1;
            else                                                           ap[0] <= 0;
            if (ap[0])                                                     ap[2] <= 0;
            if (ap[1])                                                     ap[2] <= 1;
            if (sm_tlast & sm_tvalid & sm_tready)                          ap[1] <= 1;
            if ((ap[1]) & arvalid & rvalid & (araddr == 12'h000))          ap[1] <= 0;
        end
    end

    // Control the datapath pipeline stage
    always @(posedge axis_clk or negedge axis_rst_n) begin
        if (!axis_rst_n) run <= 0;
        else begin
            if      (ap[0]) run <= 1;
            if      (ap[1]) run <= 0;
            if  (sm_tvalid) run <= (sm_tready)? 1 : 0;
        end
    end

    // Check if the data_RAM is full: x_cnt == h_len?
    always @(posedge axis_clk or negedge axis_rst_n) begin
        if (!axis_rst_n)
            x_cnt <= 0;
        else
            x_cnt <= (x_init)? (i == h_len - 1)? x_cnt - 1 : (ss_tvalid & ss_tready)? x_cnt + 1 : x_cnt : (h_len - 1);
    end

    // Address for x and h: y[t] = h[i] * x[t-i]
    always @(posedge axis_clk or negedge axis_rst_n) begin
        if (!axis_rst_n) begin
            i <= {(pADDR_WIDTH-1){1'b0}};
            t <= {(pADDR_WIDTH-1){1'b0}};
        end else begin
            if (fir_en | (sm_tvalid & sm_tready)) begin
                i <= (sm_tvalid & ~sm_tready)? i : (i != (h_len - 1))? i + 1 : 0;
                t <= (sm_tvalid & ~sm_tready)? t : (i == (h_len - 1))? ((t != h_len - 1)? t + 1 : 0) : t;
            end
            if (ap[1]) begin
                i <= 0;
                t <= 0;
            end
        end
    end

    // FIR pipeline stage: | Stage 0: get address | Stage 1: get data | Stage 2: multiplication | Stage 3: accumulation | Stage 4: output |
    //                                         .-----.             .-----.                                   .------------------.
    //                               h_addr ---| RAM |--- coeff ---| D Q |----------.        .-----.         |       .-----.    |
    //                               x_addr ---|     |--- dataX ---|     |---------(X)-------| D Q |--------(+)------| D Q |--- Y
    //                                         `-----`             `-----`                   `-----`                 `-----`
    always @(posedge axis_clk or negedge axis_rst_n) begin
        if (!axis_rst_n) begin
            x <= 0;
            h <= 0;
            m <= 0;
            y <= 0;
        end else begin
            x <= (fir_en)? (run & ~fir_en_q & fir_en_d)? x_l : (i == 1)? data_ff : data_Do : x; // RAM can't be read&write at the same time, so use the latched data when i==1
            h <= (fir_en)? (run & ~fir_en_q & fir_en_d)? h_l : tap_Do : h; // If AXI-lite read transaction done, resume with the latched data
            m <= (fir_en)? x * h : m;
            y <= (fir_en)? (~run_q & run)? m + m_l : ((sm_tvalid & ~sm_tready)? y : (i == 3)? m + m_l : m + y) : y; // Restart the accumulation of y when a new convolution start and flow through the pipeline stage 3 (accumulation)
        end
    end

    // Pipeline stage shifting
    always @(posedge axis_clk or negedge axis_rst_n) begin
        if (!axis_rst_n) 
            {pipeline_stage} <= 0;
        else if ((fir_en | sm_tvalid))// || (sm_tvalid & sm_tready))
            {pipeline_stage} <= (sm_tvalid)? (sm_tready)? {x_last, pipeline_stage[3:1]} : {pipeline_stage}: {x_last, pipeline_stage[3:1]};
    end

    // In one clk cycle, if data RAM is written, it can't be read, use the data which stored in data_FF.
    always @(posedge axis_clk or negedge axis_rst_n) begin
        if (!axis_rst_n)    data_ff <= 0;
        else if (ss_tvalid) data_ff <= ss_tdata;
    end

endmodule