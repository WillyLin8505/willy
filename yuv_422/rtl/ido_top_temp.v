// ------------------------------------------------------------------------------
// (C) Copyright. 2015
// SILICON OPTRONICS CORPORATION ALL RIGHTS RESERVED
//
// This design is confidential and proprietary owned by Silicon Optronics Corp.
// Any distribution and modification must be authorized by a licensing agreement
// ------------------------------------------------------------------------------
// Filename        : ido_top_rtl.v
// Author          : Evan Tsai
//
// Description     : image data output mux
// ------------------------------------------------------------------------------//

module ido_top_temp

#(// user config.
  parameter IMG_HSZ = 1280+8*2,         // MAX H size from TVP/HSC output (src 648)
  parameter IMG_VSZ = 720+6*2           // MAX V size from TVP/P2I output (src 492)
)
(
//================================================================================
//  I/O declaratioin
//================================================================================

// output
output                        ido_vstr,               // frame start
output                        ido_vend,               // frame end
output                        ido_hstr,               // line start
output                        ido_hend,               // line end
output                        ido_dvld,               // data valid
output      [ 7:0]            ido_data_r,             // R / Y  / Y data output
output      [ 7:0]            ido_data_g,             // G / Cb / U data output
output      [ 7:0]            ido_data_b,             // B / Cr / V data output

// input


input                         isp_vstr,               // ISP RGB/YCbCr
input                         isp_vend,               //
input                         isp_hstr,               //
input                         isp_hend,               //
input                         isp_dvld,               //
input       [ 7:0]            isp_data_r,             //
input       [ 7:0]            isp_data_g,             //
input       [ 7:0]            isp_data_b,             //

input                         tvp_vstr,               // TVP YCbCr
input                         tvp_vend,               //
input                         tvp_hstr,               //
input                         tvp_hend,               //
input                         tvp_dvld,               //
input       [ 7:0]            tvp_data_y,             //
input       [ 7:0]            tvp_data_cb,            //
input       [ 7:0]            tvp_data_cr,            //

input                         tve_vstr,               // TVE YUV
input                         tve_vend,               //
input                         tve_hstr,               //
input                         tve_hend,               //
input                         tve_dvld,               //
input       [ 7:0]            tve_data_y,             //
input       [ 7:0]            tve_data_u,             //
input       [ 7:0]            tve_data_v,             //

// reg
input       [ 2:0]            reg_ido_format,         // output format select
                                                      // 0 => CV_RGB   , 1 => ORG_RGB
input                         reg_ido_ycbcr_sel,      // YCbCr source select:
                                                      // 0 => ISP YCbCr, 1 => TVP YCbCr
input                         reg_ido_yuv_sel,        // YUV / YCbCr select:
                                                      // 0 => YCbCr    , 1 => YUV
input                         reg_ido_ycbcr_rng,      // YCbCr with nominal range
                                                      // 0=> 0~255     , 1=> 16~235/16~240
input                         r_yuv_422_swap_yc,      // 0=> YUYV      , 1=> UYVY
// clk
input                         pclk,                   // pixel clock
input                         prst_n                  // sync reset @ pclk
);

//================================================================================
//  parameter
//================================================================================
localparam IDO_FMT_RAW        = 3'b000;               //
localparam IDO_FMT_YUV        = 3'b001;               //
localparam IDO_FMT_RGB        = 3'b010;               //
localparam IDO_FMT_YUV_422    = 3'b100;               //
//================================================================================
//  Internal wire declaration
//================================================================================

// IDO format decode
wire                          ido_format_raw;
wire                          ido_format_rgb;
wire                          ido_format_yuv;
wire                          ido_format_yuv_422;

// IDO_MUX
reg                           ido_mux_vstr;
reg                           ido_mux_vend;
reg                           ido_mux_hstr;
reg                           ido_mux_hend;
reg                           ido_mux_dvld;
reg         [7:0]             ido_mux_data_r;
reg         [7:0]             ido_mux_data_g;
reg         [7:0]             ido_mux_data_b;

reg                           ido_mux_vstr_nxt;
reg                           ido_mux_vend_nxt;
reg                           ido_mux_hstr_nxt;
reg                           ido_mux_hend_nxt;
reg                           ido_mux_dvld_nxt;
reg         [7:0]             ido_mux_data_r_nxt;
reg         [7:0]             ido_mux_data_g_nxt;
reg         [7:0]             ido_mux_data_b_nxt;


// IDO_YUV (MUX with sync)
wire                          ido_yuv_vstr;
wire                          ido_yuv_vend;
wire                          ido_yuv_hstr;
wire                          ido_yuv_hend;
wire                          ido_yuv_dvld;
wire        [7:0]             ido_yuv_data_y;
wire        [7:0]             ido_yuv_data_u;
wire        [7:0]             ido_yuv_data_v;

// IDO_YCbCr (MUX only data)
wire                          ido_ycbcr_vstr;
wire                          ido_ycbcr_vend;
wire                          ido_ycbcr_hstr;
wire                          ido_ycbcr_hend;
wire                          ido_ycbcr_dvld;
wire        [7:0]             ido_ycbcr_data_y;
wire        [7:0]             ido_ycbcr_data_cb;
wire        [7:0]             ido_ycbcr_data_cr;

// YCbCr 422 
wire                          ido_yuv_422_vstr;
wire                          ido_yuv_422_vend;
wire                          ido_yuv_422_hstr;
wire                          ido_yuv_422_hend;
wire                          ido_yuv_422_dvld;
wire        [15:0]            ido_yuv_422_data;


// NOMINAL_YCbCr
wire        [7:0]             nominal_ycbcr_data_y;
wire        [7:0]             nominal_ycbcr_data_cb;
wire        [7:0]             nominal_ycbcr_data_cr;

// ORG_YCbCr (MUX with sync)
wire                          org_ycbcr_vstr;
wire                          org_ycbcr_vend;
wire                          org_ycbcr_hstr;
wire                          org_ycbcr_hend;
wire                          org_ycbcr_dvld;
wire        [7:0]             org_ycbcr_data_y;
wire        [7:0]             org_ycbcr_data_cb;
wire        [7:0]             org_ycbcr_data_cr;

// ISP_YCbCr
wire        [7:0]             isp_data_y;
wire        [7:0]             isp_data_cb;
wire        [7:0]             isp_data_cr;

//================================================================================
//  Behavior description
//================================================================================

// IDO format decode
assign ido_format_raw     = (reg_ido_format == IDO_FMT_RAW);
assign ido_format_rgb     = (reg_ido_format == IDO_FMT_RGB);
assign ido_format_yuv     = (reg_ido_format == IDO_FMT_YUV);
assign ido_format_yuv_422 = (reg_ido_format == IDO_FMT_YUV_422);

// output wire
assign ido_vstr    = ido_mux_vstr;
assign ido_vend    = ido_mux_vend;
assign ido_hstr    = ido_mux_hstr;
assign ido_hend    = ido_mux_hend;
assign ido_dvld    = ido_mux_dvld;

// input data
assign isp_data_y  = isp_data_r;
assign isp_data_cb = isp_data_g;
assign isp_data_cr = isp_data_b;

//input wire
assign  ido_yuv_vstr = isp_vstr;
assign  ido_yuv_vend = isp_vend;
assign  ido_yuv_hstr = isp_hstr;
assign  ido_yuv_hend = isp_hend;
assign  ido_yuv_dvld = isp_dvld;

//
always @ (posedge pclk, negedge prst_n) begin : IDO_MUX
  if(!prst_n) begin
    ido_mux_vstr   <= 0;
    ido_mux_vend   <= 0;
    ido_mux_hstr   <= 0;
    ido_mux_hend   <= 0;
    ido_mux_dvld   <= 0;
    ido_mux_data_r <= 0;
    ido_mux_data_g <= 0;
    ido_mux_data_b <= 0;
  end
  else begin
    ido_mux_vstr   <= ido_mux_vstr_nxt;
    ido_mux_vend   <= ido_mux_vend_nxt;
    ido_mux_hstr   <= ido_mux_hstr_nxt;
    ido_mux_hend   <= ido_mux_hend_nxt;
    ido_mux_dvld   <= ido_mux_dvld_nxt;
    ido_mux_data_r <= ido_mux_data_r_nxt;
    ido_mux_data_g <= ido_mux_data_g_nxt;
    ido_mux_data_b <= ido_mux_data_b_nxt;
  end
end

// IDO_MUX
always @ (*) begin
  // default
  ido_mux_vstr_nxt       = 0;
  ido_mux_vend_nxt       = 0;
  ido_mux_hstr_nxt       = 0;
  ido_mux_hend_nxt       = 0;
  ido_mux_dvld_nxt       = 0;
  ido_mux_data_r_nxt     = 0;
  ido_mux_data_g_nxt     = 0;
  ido_mux_data_b_nxt     = 0;
  //
  case(reg_ido_format)
    //
    IDO_FMT_RAW: begin
      ido_mux_vstr_nxt   = 1'h0;
      ido_mux_vend_nxt   = 1'h0;
      ido_mux_hstr_nxt   = 1'h0;
      ido_mux_hend_nxt   = 1'h0;
      ido_mux_dvld_nxt   = 1'h0;
      ido_mux_data_r_nxt = 8'h00;
      ido_mux_data_g_nxt = 8'h00;
      ido_mux_data_b_nxt = 8'h00;
    end
    //
    IDO_FMT_RGB: begin
      ido_mux_vstr_nxt   = 1'h0;
      ido_mux_vend_nxt   = 1'h0;
      ido_mux_hstr_nxt   = 1'h0;
      ido_mux_hend_nxt   = 1'h0;
      ido_mux_dvld_nxt   = 1'h0;
      ido_mux_data_r_nxt = 8'h00;
      ido_mux_data_g_nxt = 8'h00;
      ido_mux_data_b_nxt = 8'h00;
    end
    //
    IDO_FMT_YUV: begin
      ido_mux_vstr_nxt   = 1'h0;
      ido_mux_vend_nxt   = 1'h0;
      ido_mux_hstr_nxt   = 1'h0;
      ido_mux_hend_nxt   = 1'h0;
      ido_mux_dvld_nxt   = 1'h0;
      // !!! please watch out the channel mapping to match DVP data port requirement !!!
      // (G <-> Y, B <-> Cb/U, R <-> Cr/V)
      ido_mux_data_r_nxt = 8'h00;
      ido_mux_data_g_nxt = 8'h00;
      ido_mux_data_b_nxt = 8'h00;
    end
    //
    IDO_FMT_YUV_422: begin
      ido_mux_vstr_nxt   = ido_yuv_422_vstr;
      ido_mux_vend_nxt   = ido_yuv_422_vend;
      ido_mux_hstr_nxt   = ido_yuv_422_hstr;
      ido_mux_hend_nxt   = ido_yuv_422_hend;
      ido_mux_dvld_nxt   = ido_yuv_422_dvld;
      ido_mux_data_r_nxt = ido_yuv_422_data[7:0];
      ido_mux_data_g_nxt = 8'h00;
      ido_mux_data_b_nxt = ido_yuv_422_data[15:8];
    end
    //
  endcase
end

// IDO_YUV MUX
assign {ido_yuv_vstr,
        ido_yuv_vend,
        ido_yuv_hstr,
        ido_yuv_hend,
        ido_yuv_dvld,
        ido_yuv_data_y,
        ido_yuv_data_u,
        ido_yuv_data_v} =
        //
        (reg_ido_yuv_sel)?
        // TVE_YUV
        {tve_vstr,
         tve_vend,
         tve_hstr,
         tve_hend,
         tve_dvld,
         tve_data_y,
         tve_data_u,
         tve_data_v} :
        // IDO_YCbCr
        {ido_ycbcr_vstr,
         ido_ycbcr_vend,
         ido_ycbcr_hstr,
         ido_ycbcr_hend,
         ido_ycbcr_dvld,
         ido_ycbcr_data_y,
         ido_ycbcr_data_cb,
         ido_ycbcr_data_cr};

assign {ido_ycbcr_data_y,
        ido_ycbcr_data_cb,
        ido_ycbcr_data_cr} =
        //
        (reg_ido_ycbcr_rng)?
        // NOMINAL_YCbCr
        {nominal_ycbcr_data_y,
         nominal_ycbcr_data_cb,
         nominal_ycbcr_data_cr} :
        // ORG_YCbCr
        {org_ycbcr_data_y,
         org_ycbcr_data_cb,
         org_ycbcr_data_cr};

// ORG_YCbCr (MUX with sync)
assign {org_ycbcr_vstr,
        org_ycbcr_vend,
        org_ycbcr_hstr,
        org_ycbcr_hend,
        org_ycbcr_dvld,
        org_ycbcr_data_y,
        org_ycbcr_data_cb,
        org_ycbcr_data_cr} =
        //
        (reg_ido_ycbcr_sel)?
        // TVP_YCbCr
        {tvp_vstr,
         tvp_vend,
         tvp_hstr,
         tvp_hend,
         tvp_dvld,
         tvp_data_y,
         tvp_data_cb,
         tvp_data_cr} :
        // ISP_YCbCr
        {isp_vstr,
         isp_vend,
         isp_hstr,
         isp_hend,
         isp_dvld,
         isp_data_y,
         isp_data_cb,
         isp_data_cr};

//

//================================================================================
//  Module instantiation
//================================================================================

//--------------------------------------------------------------------------------
//  YCbCr(0~255) to nominal range: Y(16~235) C(16~240)
//--------------------------------------------------------------------------------
ycbcr_nominal_rng
ido_ycbcr_nominal_rng(
// output
      .dout_y (nominal_ycbcr_data_y ),
      .dout_cb(nominal_ycbcr_data_cb),
      .dout_cr(nominal_ycbcr_data_cr),

// input
      .din_y (org_ycbcr_data_y ),
      .din_cb(org_ycbcr_data_cb),
      .din_cr(org_ycbcr_data_cr)
);

ip_yuv_422 ip_yuv_422
(

    .o_422_vstr     (ido_yuv_422_vstr),
    .o_422_vend     (ido_yuv_422_vend),
    .o_422_hstr     (ido_yuv_422_hstr),
    .o_422_hend     (ido_yuv_422_hend),
    .o_422_dvld     (ido_yuv_422_dvld),
    .o_422_data     (ido_yuv_422_data),

    .yuv_422_clk    (pclk),
    .yuv_422_rst_n  (prst_n),
    .i_vstr         (ido_yuv_vstr),
    .i_vend         (ido_yuv_vend),
    .i_hstr         (ido_yuv_hstr),
    .i_hend         (ido_yuv_hend),
    .i_dvld         (ido_yuv_dvld),
    .i_yuv_data_y   (ido_yuv_data_y),
    .i_yuv_data_cb  (ido_yuv_data_u),
    .i_yuv_data_cr  (ido_yuv_data_v),
    .r_yuv_swap_yc  (r_yuv_422_swap_yc)

);


endmodule

