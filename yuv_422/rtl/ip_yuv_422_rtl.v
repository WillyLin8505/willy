// +FHDR -----------------------------------------------------------------------
// Copyright (c) Silicon Optronics. Inc. 2014
//
// File Name:           ip_yuv422.v
// Author:              Willy Lin
// Version:             $Revision$
// Last Modified On:    2021/11/17
// Last Modified By:    $Author$
//
// File Description:    convert yuv444 to yuv422
//                      
// Clock Domain:         
// -FHDR -----------------------------------------------------------------------
module ip_yuv_422
(
//----------------------------------------------//
// Output declaration                           //
//----------------------------------------------//

output reg                     o_422_vstr,
output reg                     o_422_vend,
output reg                     o_422_hstr,
output reg                     o_422_hend,
output reg                     o_422_dvld,
output reg [15:0]              o_422_data,

//----------------------------------------------//
// Input declaration                            //
//----------------------------------------------//

input                          yuv_422_clk,
input                          yuv_422_rst_n,
input                          i_vstr,
input                          i_vend,
input                          i_hstr,
input                          i_hend,
input                          i_dvld,
input [7:0]                    i_yuv_data_y,
input [7:0]                    i_yuv_data_cb,
input [7:0]                    i_yuv_data_cr,
input                          r_yuv_swap_yc

);

//----------------------------------------------//
// Register & Wire declaration                  //
//----------------------------------------------//
//--------------------------------------------------------data part
reg  [7:0]                     i_yuv_data_y_q; 
wire [7:0]                     yuv_data_cb_cr_1st;
wire [7:0]                     yuv_data_cb_cr_2nd;
wire [8:0]                     yuv_data_cb_cr_add;
wire [7:0]                     yuv_data_cb_cr_mean;
reg  [7:0]                     i_yuv_data_cb_q;
reg  [7:0]                     i_yuv_data_cr_q;
reg  [7:0]                     i_yuv_data_cr_q2;
wire [15:0]                    o_422_data_nxt;
//--------------------------------------------------------counter part 
wire                           sel_cnt_nxt;
reg                            sel_cnt;
wire                           sel_cnt_inc;
wire                           sel_cnt_clr;
//---------------------------------------------------------output 
reg                            i_dvld_q;
reg                            i_vstr_q;   
reg                            i_vend_q;
reg                            i_hstr_q;
reg                            i_hend_q;
//----------------------------------------------//
// Code Descriptions                            //
//----------------------------------------------//
//----------------------------------------------------------------------data part
assign yuv_data_cb_cr_1st  = sel_cnt_nxt ? i_yuv_data_cb : i_yuv_data_cr_q ;
assign yuv_data_cb_cr_2nd  = sel_cnt_nxt ? i_yuv_data_cb_q : i_yuv_data_cr_q2;
assign yuv_data_cb_cr_add  = yuv_data_cb_cr_1st + yuv_data_cb_cr_2nd;
assign yuv_data_cb_cr_mean = yuv_data_cb_cr_add[8:1];
assign o_422_data_nxt      = (r_yuv_swap_yc ? {yuv_data_cb_cr_mean,i_yuv_data_y_q}:{i_yuv_data_y_q,yuv_data_cb_cr_mean}) & {16{i_dvld_q}};
//----------------------------------------------------------------------counter part
assign sel_cnt_nxt         = (sel_cnt_inc ? sel_cnt + 1'b1 : sel_cnt) & !sel_cnt_clr; //sel cb or cr
assign sel_cnt_inc         = i_dvld_q;
assign sel_cnt_clr         = ~i_dvld_q;

always@(posedge yuv_422_clk or negedge yuv_422_rst_n)begin 
  if(!yuv_422_rst_n) begin 
//-----------------------------------------data
    i_yuv_data_y_q        <= 8'h00;
    i_yuv_data_cb_q       <= 8'h00;
    i_yuv_data_cr_q       <= 8'h00;
    i_yuv_data_cr_q2      <= 8'h00;
    o_422_data            <= 8'h00;
//-----------------------------------------counter
    sel_cnt               <= 1'b0;
//-----------------------------------------output 
    i_dvld_q              <= 1'b0;
    i_vstr_q              <= 1'b0;   
    i_vend_q              <= 1'b0;
    i_hstr_q              <= 1'b0;
    i_hend_q              <= 1'b0;
    o_422_dvld            <= 1'b0;
    o_422_vstr            <= 1'b0;    
    o_422_vend            <= 1'b0; 
    o_422_hstr            <= 1'b0;   
    o_422_hend            <= 1'b0;
  end
  else begin 
//-----------------------------------------data
    i_yuv_data_y_q        <= i_yuv_data_y;
    i_yuv_data_cb_q       <= i_yuv_data_cb;
    i_yuv_data_cr_q       <= i_yuv_data_cr;
    i_yuv_data_cr_q2      <= i_yuv_data_cr_q;
    o_422_data            <= o_422_data_nxt;
//-----------------------------------------counter
    sel_cnt               <= sel_cnt_nxt;
//-----------------------------------------output
    i_dvld_q              <= i_dvld;   
    i_vstr_q              <= i_vstr;     
    i_vend_q              <= i_vend;    
    i_hstr_q              <= i_hstr;    
    i_hend_q              <= i_hend;  
    o_422_dvld            <= i_dvld_q;   
    o_422_vstr            <= i_vstr_q;    
    o_422_vend            <= i_vend_q;    
    o_422_hstr            <= i_hstr_q;    
    o_422_hend            <= i_hend_q; 
  end
end

endmodule  
