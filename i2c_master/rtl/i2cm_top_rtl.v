// +FHDR -----------------------------------------------------------------------
// Copyright (c) Silicon Optronics. Inc. 2014
//
// File Name:           ip_i2c_m_top_trl.v
// Author:              Willy Lin
// Version:             $Revision$
// Last Modified On:    10/13
// Last Modified By:    $Author$
//
// File Description:    i2c master top , have two trigger
//                      
// Clock Domain: input:384k,1536k,2048k,3072k
//               output(SCL):96k,384k,512k,768k
//               output(CLK):384k,1536k,2048k,3072k
// -FHDR -----------------------------------------------------------------------

module i2cm_top

   #( 
      parameter    I2C_NUM     = 32,              //number of data need i2c master to read or write  
      parameter    NUM_WID     = $clog2(I2C_NUM),
      parameter    TRG_CDC     = "ASYNC",         // "SYNC"/"ASYNC"
      parameter    TRG_TYPE    = "MUTI",
      parameter    FIFO_DWID   = 16,
      parameter    FIFO_DEPTH  = 4,
      parameter    DO_FFO_EN   = 0,
      parameter    MEM_TYPE    = "DFF"

     )

(

//----------------------------------------------//
// Output declaration                           //
//----------------------------------------------//

//----------------------------------------------original output 
output                 o_i2cm_sda_en,
output                 o_i2cm_scl_en,
output                 o_i2cm_finish_tgl_0,
output                 o_i2cm_nack_ntfy_tgl_0,
output                 o_i2cm_finish_tgl_1,
output                 o_i2cm_nack_ntfy_tgl_1,
//-----------------------------------------------control output 
output [7:0]           o_i2cm_wr_addr,                  //write address for register page , i2c slave clk domain 
output [7:0]           o_i2cm_wr_data,                  //write data for register page    , i2c slave clk domain 
output                 o_i2cm_wr_en,                    //write enable for register page  , i2c slave clk domain 
output [7:0]           o_i2cm_rd_addr,                  //read address for register page  , i2c master clk domain 
output                 o_i2cm_op,                       //mark as the read enable for data page register 
//----------------------------------------------//
// Input declaration                            //
//----------------------------------------------//

//------------------------------------------------master domain input 
input                  i2cm_clk,
input                  i2cm_rst_n,
input [7:0]            i_i2cm_data,                    //the data need to be change frequencely , so the head mark is i_ rather then using r_
input                  r_i2cm_nack_0,
input                  r_i2cm_type_0,
input                  r_i2cm_stb_0,
input                  r_i2cm_seq_0,
input                  i_i2cm_trg_0,
input [7:0]            r_i2cm_num_0,
input [7:0]            r_i2cm_dev_id_0,
input [7:0]            r_i2cm_addr_0,
input                  r_i2cm_nack_1, 
input                  r_i2cm_type_1,
input                  r_i2cm_stb_1,
input                  r_i2cm_seq_1,
input                  r_i2cm_trg_1,
input [7:0]            r_i2cm_num_1,
input [7:0]            r_i2cm_dev_id_1,
input [7:0]            r_i2cm_addr_1,
//------------------------------------------------slave domain input 
input                  i2cs_clk,
input                  i2cs_rst_n,
//----------------------------------------------//
// Inoutput declaration                         //
//----------------------------------------------//

inout                  io_sda, 
inout                  io_scl

);

//----------------------------------------------//
// Register & Wire declaration                  //
//----------------------------------------------//
//----------------------------------------------i2cm_arbiter
wire                   abr_stb;
wire                   abr_seq;
wire [7:0]             abr_dev_id;
wire                   abr_nack;
wire                   abr_type;
wire [NUM_WID-1:0]     abr_num;
wire [7:0]             abr_addr;
wire [7:0]             abr_data;
wire                   abr_int_flag;
wire                   i2cm_abr_trg; 
//----------------------------------------------i2cm
wire                   i2cm_finish_pulse;
wire                   i2cm_wdata_nack;
wire [NUM_WID-1:0]     i2cm_num_cnt;
wire [7:0]             i2cm_addr_cnt;
wire                   i2cm_clr_smo;
wire                   i2cm_write_addr_smo;
wire [7:0]             i2cm_data_addr;
wire [7:0]             i2cm_wr_data;
wire                   i2cm_wr_data_wen;
wire                   i2cm_addr_done;
wire                   i2cm_type_flag;
wire                   i2cm_num_cnt_inc;
wire                   i2cm_addr_cnt_set;
//----------------------------------------------

//----------------------------------------------//
// Code Descriptions                            //
//----------------------------------------------//


//----------------------------------------------//
// Module Instance                              //
//----------------------------------------------//

i2cm_arbiter 
              #(
         .I2C_NUM                 (I2C_NUM),
         .TRG_CDC                 (TRG_CDC),
         .TRG_TYPE                (TRG_TYPE)
               )

i2cm_arbiter(
         .o_finish_tgl_0          (o_i2cm_finish_tgl_0),
         .o_nack_ntfy_tgl_0       (o_i2cm_nack_ntfy_tgl_0),
         .o_finish_tgl_1          (o_i2cm_finish_tgl_1),
         .o_nack_ntfy_tgl_1       (o_i2cm_nack_ntfy_tgl_1),
         .o_abr_op                (o_i2cm_op),

         .o_abr_trg_cfg           (i2cm_abr_trg),
         .o_abr_stb_cfg           (abr_stb),
         .o_abr_seq_cfg           (abr_seq),
         .o_abr_dev_id_cfg        (abr_dev_id),
         .o_abr_nack_cfg          (abr_nack),
         .o_abr_type_cfg          (abr_type),
         .o_abr_num_nxt           (abr_num),
         .o_abr_addr_nxt          (abr_addr),
         .o_abr_data_nxt          (abr_data),
         .o_abr_int_flag_nxt      (abr_int_flag),

         .i2c_clk                 (i2cm_clk),
         .i2c_rst_n               (i2cm_rst_n),               
         .r_i2cm_nack_0           (r_i2cm_nack_0),
         .r_i2cm_type_0           (r_i2cm_type_0),
         .r_i2cm_stb_0            (r_i2cm_stb_0),
         .r_i2cm_seq_0            (r_i2cm_seq_0),
         .i_i2cm_trg_0            (i_i2cm_trg_0),
         .r_i2cm_num_0            (r_i2cm_num_0),
         .r_i2cm_dev_id_0         (r_i2cm_dev_id_0),
         .r_i2cm_addr_0           (r_i2cm_addr_0),
         .r_i2cm_nack_1           (r_i2cm_nack_1),
         .r_i2cm_type_1           (r_i2cm_type_1),
         .r_i2cm_stb_1            (r_i2cm_stb_1),
         .r_i2cm_seq_1            (r_i2cm_seq_1),
         .r_i2cm_trg_1            (r_i2cm_trg_1),
         .r_i2cm_num_1            (r_i2cm_num_1),
         .r_i2cm_dev_id_1         (r_i2cm_dev_id_1),
         .r_i2cm_addr_1           (r_i2cm_addr_1),
         .i_i2cm_data             (i_i2cm_data),

         .i_i2cm_finish_pulse     (i2cm_finish_pulse),
         .i_i2cm_wdata_nack       (i2cm_wdata_nack),
         .i_i2cm_num_cnt          (i2cm_num_cnt),
         .i_i2cm_addr_cnt         (i2cm_addr_cnt),
         .i_i2cm_clr_smo          (i2cm_clr_smo),
         .i_i2cm_write_addr_smo   (i2cm_write_addr_smo),
         .i_i2cm_addr_done        (i2cm_addr_done),
         .i_i2cm_type_flag        (i2cm_type_flag),
         .i_i2cm_num_cnt_inc      (i2cm_num_cnt_inc)
);


i2cm 
              #(
         .NUM_WID                 (NUM_WID),
         .TRG_CDC                 (TRG_CDC)
               )
i2cm(
         .o_sda_en                (o_i2cm_sda_en),
         .o_scl_en                (o_i2cm_scl_en),

         .o_data_addr             (i2cm_data_addr),
         .o_wr_data               (i2cm_wr_data),
         .o_wr_data_wen           (i2cm_wr_data_wen),
         .o_trans_finish_pulse    (i2cm_finish_pulse),
         .o_wdata_nack            (i2cm_wdata_nack),
         .o_num_cnt               (i2cm_num_cnt),
         .o_addr_cnt              (i2cm_addr_cnt),
         .o_i2c_clr_smo           (i2cm_clr_smo),
         .o_i2c_write_addr_smo    (i2cm_write_addr_smo),
         .o_addr_done             (i2cm_addr_done),
         .o_type_flag             (i2cm_type_flag),
         .o_num_cnt_inc           (i2cm_num_cnt_inc),

         .i2c_clk                 (i2cm_clk),
         .i2c_rst_n               (i2cm_rst_n),
         .i_i2cm_nack             (abr_nack),
         .i_i2cm_type             (abr_type),
         .i_i2cm_stb              (abr_stb),
         .i_i2cm_seq              (abr_seq),
         .i_i2cm_trg              (i2cm_abr_trg),
         .i_i2cm_dev_id           (abr_dev_id), 
         .i_i2cm_num              (abr_num),
         .i_i2cm_addr             (abr_addr),
         .i_i2cm_data             (abr_data), 
         .i_int_flag              (abr_int_flag),

         .io_sda                  (io_sda), 
         .io_scl                  (io_scl)
);


 i2cm_cdc_fifo

    #(
         .FIFO_CDC                (TRG_CDC),
         .MEM_TYPE                (MEM_TYPE),
         .FIFO_DWID               (FIFO_DWID),
         .FIFO_DEPTH              (FIFO_DEPTH),
         .DO_FFO_EN               (DO_FFO_EN)
     )

 i2cm_cdc_fifo(
//----------------slave clock domain
         .i2cs_clk                (i2cs_clk),
         .i2cs_rst_n              (i2cs_rst_n),
         .o_i2cm_wr_addr          (o_i2cm_wr_addr),
         .o_i2cm_wr_data          (o_i2cm_wr_data),
         .o_i2cm_wr_en            (o_i2cm_wr_en),
//----------------master clock domain
         .o_i2cm_rd_addr          (o_i2cm_rd_addr),
//----------------master clock domain
         .i2cm_clk                (i2cm_clk),
         .i2cm_rst_n              (i2cm_rst_n),
         .i_i2cm_data             (i2cm_wr_data),
         .i_i2cm_addr             (i2cm_data_addr),
         .i_i2cm_data_wen         (i2cm_wr_data_wen)


);





endmodule 
