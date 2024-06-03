
module soisp_reg

              #(parameter NUM_WID = 8)
(
//================================================================================
//  I/O declaratioin
//================================================================================

//----------------------------------------------i2c master top
input                  i_i2cm_finish_tgl_0,
input                  i_i2cm_nack_ntfy_tgl_0,
input                  i_i2cm_finish_tgl_1,
input                  i_i2cm_nack_ntfy_tgl_1,

input   [7:0]          i_i2cm_wr_addr,                  
input   [7:0]          i_i2cm_wr_data,                  
input                  i_i2cm_wr_en,  
input   [7:0]          i_i2cm_rd_addr,    
input                  i_i2cm_chip_sel,                              

//------------------------------------------------master data page reg 
output  [7:0]          r_i2cm_data, 
//------------------------------------------------master config page reg 
output                 r_i2cm_nack_0,
output                 r_i2cm_nack_1,
output                 r_i2cm_type_0,
output                 r_i2cm_type_1,
output                 r_i2cm_stb_0,
output                 r_i2cm_stb_1,
output                 r_i2cm_seq_0,
output                 r_i2cm_seq_1,
output                 r_i2cm_trg_0,
output                 r_i2cm_trg_1,
output   [7:0]         r_i2cm_num_0,
output   [7:0]         r_i2cm_num_1,
output   [7:0]         r_i2cm_dev_id_0,
output   [7:0]         r_i2cm_dev_id_1,
output   [7:0]         r_i2cm_addr_0,
output   [7:0]         r_i2cm_addr_1,

// host I/F
input                  reg_we,                      
input  [7:0]           reg_addr,                     
input  [7:0]           reg_wdata,                    
output [7:0]           reg_rdata,                   

// clk
input                  i2csf_clk,                                                  
input                  i2csf_rst_n                      
);


//================================================================================
//  parameter
//================================================================================
localparam  ADDR_PAGE_IDX           = 8'hFF;                      //
localparam  PAGE_NUM                = 16;                         //
localparam  PAGE_IDX_WID            = $clog2(PAGE_NUM);           //

//================================================================================
//  signal declaration
//================================================================================
genvar                              i;                            //

reg         [PAGE_IDX_WID-1:0]      page_idx;                     //
wire        [PAGE_IDX_WID-1:0]      page_idx_nxt;                 //

wire        [PAGE_NUM-1:0]          page_sel;                     //
wire        [PAGE_NUM-1:0]          page_reg_we;                  //

wire        [15:0]                  page_reg_addr;                //

wire        [ 7:0]                  page_reg_rdata    [0:15];     //

//
wire                                reg_crop_sz_upd;              //

wire                                reg_pssr_sz_upd;              //

//-------------------------------------------------------------------------------- page 14
wire                                page_reg_we_p14;
wire        [15:0]                  page_reg_waddr_p14;
wire        [7:0]                   reg_wdata_p14;
wire        [15:0]                  page_reg_raddr_p14;
//================================================================================
//  behavior description
//================================================================================
assign page_idx_nxt = (reg_we & (reg_addr == ADDR_PAGE_IDX))? reg_wdata[3:0] : page_idx;

always @ (posedge i2csf_clk, negedge i2csf_rst_n) begin : PAGE_IDX
  if(!i2csf_rst_n)
    page_idx <= 0;
  else
    page_idx <= page_idx_nxt;
end

//
generate

for(i=0;i<PAGE_NUM;i=i+1) begin

assign page_sel[i]   = (page_idx == i);

end

endgenerate

//
assign page_reg_we   = {PAGE_NUM{reg_we}} & page_sel;
//
assign page_reg_addr = {8'b0,reg_addr};
//
assign reg_rdata     = (reg_addr == ADDR_PAGE_IDX)?
                   // page index value
                   {{(8-PAGE_IDX_WID){1'b0}},page_idx} :
                   // normal register value
                   {8{page_sel[ 0]}} & page_reg_rdata[ 0] |
                   {8{page_sel[ 2]}} & page_reg_rdata[ 2] |
                   {8{page_sel[ 3]}} & page_reg_rdata[ 3] |
                   {8{page_sel[ 4]}} & page_reg_rdata[ 4] |
                   {8{page_sel[ 6]}} & page_reg_rdata[ 6] |
                   {8{page_sel[ 7]}} & page_reg_rdata[ 7] |
                   {8{page_sel[ 8]}} & page_reg_rdata[ 8] |
                   {8{page_sel[10]}} & page_reg_rdata[10] |
                   {8{page_sel[14]}} & page_reg_rdata[14] |
                   {8{page_sel[15]}} & page_reg_rdata[15];

//--------------------------------------------------------------register data page 
assign page_reg_we_p14    = page_reg_we[14] | i_i2cm_wr_en;
assign page_reg_waddr_p14 = i_i2cm_wr_en ? {8'b0,i_i2cm_wr_addr} : page_reg_addr;
assign reg_wdata_p14      = i_i2cm_wr_en ? i_i2cm_wr_data : reg_wdata;
assign page_reg_raddr_p14 = i_i2cm_chip_sel ? {8'b0,i_i2cm_rd_addr} : page_reg_addr;
assign r_i2cm_data        = page_reg_rdata[14];
//================================================================================
//  module instantiation
//================================================================================


soisp_p14_reg data_page(
        //output
         .i2cm_data_0          (),
         .i2cm_data_1          (),
         .i2cm_data_10         (),
         .i2cm_data_11         (),
         .i2cm_data_12         (),
         .i2cm_data_13         (),
         .i2cm_data_14         (),
         .i2cm_data_15         (),
         .i2cm_data_2          (),
         .i2cm_data_20         (),
         .i2cm_data_21         (),
         .i2cm_data_22         (),
         .i2cm_data_23         (),
         .i2cm_data_24         (),
         .i2cm_data_25         (),
         .i2cm_data_26         (),
         .i2cm_data_27         (),
         .i2cm_data_28         (),
         .i2cm_data_29         (),
         .i2cm_data_3          (),
         .i2cm_data_30         (),
         .i2cm_data_31         (),
         .i2cm_data_4          (),
         .i2cm_data_5          (),
         .i2cm_data_6          (),
         .i2cm_data_7          (),
         .i2cm_data_8          (),
         .i2cm_data_9          (),
         .reg_rd               (page_reg_rdata[14]),
        //input 
         .reg_awb_bgain_07_00  (8'h00),
         .reg_awb_bgain_11_08  (4'h0),
         .reg_awb_ggain_07_00  (8'h00),
         .reg_awb_ggain_11_08  (4'h0),
         .reg_awb_rgain_07_00  (8'h00),
         .reg_awb_rgain_11_08  (4'h0),
         .reg_ssr_expln_07_00  (8'h00),
         .reg_ssr_expln_15_08  (8'h00),
         .reg_ssr_exptp_07_00  (8'h00),
         .reg_ssr_exptp_11_08  (4'h0),
         .clk                  (i2csf_clk),
         .rst_n                (i2csf_rst_n),
         .clk_ahbs_reg_wen     (page_reg_we_p14),
         .ahbs_reg_index_wr    (page_reg_waddr_p14[7:0]),
         .ahbs_reg_wd          (reg_wdata_p14),
         .ahbs_reg_index_rd    (page_reg_raddr_p14[7:0])   
);


soisp_p10_reg config_page(
         //output
         .r_i2cm_addr_0          (r_i2cm_addr_0),
         .r_i2cm_addr_1          (r_i2cm_addr_1),
         .r_i2cm_dev_id_0        (r_i2cm_dev_id_0),
         .r_i2cm_dev_id_1        (r_i2cm_dev_id_1),
         .r_i2cm_nack_0          (r_i2cm_nack_0),
         .r_i2cm_nack_1          (r_i2cm_nack_1),
         .r_i2cm_num_0           (r_i2cm_num_0),
         .r_i2cm_num_1           (r_i2cm_num_1),
         .r_i2cm_seq_0           (r_i2cm_seq_0),
         .r_i2cm_seq_1           (r_i2cm_seq_1),
         .r_i2cm_stb_0           (r_i2cm_stb_0),
         .r_i2cm_stb_1           (r_i2cm_stb_1),
         .r_i2cm_trg_0           (r_i2cm_trg_0),
         .r_i2cm_trg_1           (r_i2cm_trg_1),
         .r_i2cm_type_0          (r_i2cm_type_0),
         .r_i2cm_type_1          (r_i2cm_type_1),
         .clr_i_i2cm_finish_0    (),
         .clr_i_i2cm_finish_1    (),
         .clr_i_i2cm_nack_ntfy_0 (),
         .clr_i_i2cm_nack_ntfy_1 (),
         .reg_rd                 (page_reg_rdata[10]),
         //input 
         .i_i2cm_finish_0        (1'b0),
         .i_i2cm_finish_1        (1'b0),
         .i_i2cm_nack_ntfy_0     (1'b0),
         .i_i2cm_nack_ntfy_1     (1'b0),
         .clr_r_i2cm_trg_0       (r_i2cm_trg_0),
         .clr_r_i2cm_trg_1       (r_i2cm_trg_1),
         .clk                    (i2csf_clk),
         .rst_n                  (i2csf_rst_n),
         .clk_ahbs_reg_wen       (page_reg_we[10]),
         .ahbs_reg_index         (page_reg_addr[7:0]),
         .ahbs_reg_wd            (reg_wdata)
);



endmodule



