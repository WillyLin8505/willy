// ------------------------------------------------------------------------------//
// (C) Copyright. 2022
// SILICON OPTRONICS CORPORATION ALL RIGHTS RESERVED
//
// This design is confidential and proprietary owned by Silicon Optronics Corp.
// Any distribution and modification must be authorized by a licensing agreement
// ------------------------------------------------------------------------------//
// Filename        :
// Author          : Willylin
// Version         : $Revision$
// Create          : 2022/2/8
// Last Modified On: 
// Last Modified By: $Author$
// 
// Description     :
// ------------------------------------------------------------------------------//

// defination & include
`timescale 1ns/1ns  
`define   TB_TOP            border_ver3_tb
`define   MONITOR_TOP       border_ver3_mon
`define   BORDER            `TB_TOP.border
`define   SENSOR            `TB_TOP.sensor
`define   SSR_TOP           `TB_TOP.sensor       //get error when scarcing this parameter
`define   HOST_WR           nope                 //get error when scarcing this parameter
`define   PPM_MON           `TB_TOP.ppm_monitor
// module start 
module border_ver3_tb();

//================================================================================
// simulation config console
//================================================================================

`include "reg_wire_declare.name"

string               ini_file_name                = "reg_config.ini";
string               test_pat_name                = "";
string               ppm_file_name                = "";
string               gold_img_num                 = "";
string               gold_vec_file                = "one_direction"; 
string               gold_num                     = "";
//================================================================================
//  parameter declaration
//================================================================================
//----------------------------------------------------------------tb
parameter           PERIOD                  = 10;

//----------------------------------------------------------------border
parameter  BORDER_BLANK                     = 32;
parameter  BORDER_COR_WIDTH                 = 12;
//----------------------------------------------------------------sensor
// pixel rate (pixel number per clock) depend on TX type
parameter           SSR_PX_RATE             = 1;
parameter           SSR_PX_FMT              = "RGB8";

// sensor pixel size (used by ISP sensor interface)
parameter           SSR_PX_SZ               = (SSR_PX_FMT == "RAW8" )? 8  :
                                              (SSR_PX_FMT == "RAW10")? 10 :
                                              (SSR_PX_FMT == "RAW12")? 12 :
                                              (SSR_PX_FMT == "RGB8" )? 24 :
                                              (SSR_PX_FMT == "RGB10")? 30 : 10;

parameter           SSR_PX_SZ_MAX           = 24;

// pixel data color sequence (only valid when SSR_PX_RATE !=1)
parameter           SSR_PX_CSEQ             = "G_LSB";

// exposure rate (exposure number per frame)
parameter           SSR_EXPO_RATE           = 1;

//================================================================================
//  signal declaration
//================================================================================
//--------------------------------------------------------------------------------tb 
reg                                       rst_n;
reg                                       clk;
//reg                                       rst_n_2;
//reg                                       clk_2;
reg                                       sensor_start;
wire                                      sensor_start_nxt;
//---------------------------------------------------------------------------------sensor
wire        [23:0]                        ssr_data;  
wire                                      ssr_field;   
wire                                      ssr_href;
wire                                      ssr_vref;
wire                                      ssr_vstr;
wire                                      ssr_vend;
wire                                      ssr_vsync;
//
reg         [15:0]                        ini_ssr_hwin_sz;
reg         [ 3:0]                        reg_ssr_hpad_sz;

reg         [15:0]                        ini_ssr_vwin_sz;
reg         [ 3:0]                        reg_ssr_vpad_sz;


// tatal blank = sensor_hsync_sz + sensor_hblkf_sz + sensor_hblkb_sz
// vblk = vtotal - (vwin+2*vpad) = 750-720 = 30

reg         [16*SSR_EXPO_RATE-1:0]        sensor_vblkf1_sz        = (SSR_EXPO_RATE == 2)? {16'd6,16'd2} : 16'd6;
reg         [15:0]                        sensor_vblkf2_sz        = 0;
reg         [15:0]                        sensor_vblkb1_sz        = 2;
reg         [16*SSR_EXPO_RATE-1:0]        sensor_vblkb2_sz        = (SSR_EXPO_RATE == 2)? {16'd2,16'd6} : 16'd4;

//
reg         [ 2:0]                        sensor_pal_cyc_ofst     = 2;

//
wire        [15:0]                        sensor_field_hofst;
reg         [15:0]                        sensor_field_vofst      = 0;

//
reg         [6:0]                         sensor_gain             = 0;
reg                                       sensor_ae_stbl          = 1'b1;
reg                                       sensor_ae_upd           = 1'b0;

reg                                       ssr_vsync_q;
reg                                       ssr_vref_q;
reg                                       ssr_href_q;
reg         [23:0]                        ssr_data_q;

wire                                      sen_fstr;  
wire                                      sen_fend;            
wire                                      sen_vstr;           
wire                                      sen_vend;             
wire                                      sen_hstr;            
wire                                      sen_hend;               
wire        [23:0]                        sen_data;    
wire                                      sen_dvld;

//----------------------------------------------------------------------------------------border
reg                                       i_border_trg;
wire                                      border_hstr;
wire                                      border_hend;
wire                                      border_vstr;
wire                                      border_vend;
wire                                      border_dvld;
wire        [7:0]                         border_data_y;
wire        [7:0]                         border_data_cb;
wire        [7:0]                         border_data_cr;
wire                                      border_finish_tgl;
reg                                       border_finish_tgl_dly;
//------- ---------------------------------------------------------------------------------patten
reg                                       border_trg_dly;
reg                                       border_trg_dly2;
reg                                       border_trg_dly3;
reg         [7:0]                         border_y_keep;
wire        [7:0]                         border_y_keep_nxt;
//----------------------------------------------------------------------------------------config
reg                                       TB_SYS_CLK;
reg                                       reg_ini_done;
//--------------------------------------------------------------------------------
//  clocking and reset
//--------------------------------------------------------------------------------


initial  begin 

 rst_n=0;
 #50;
 rst_n=1;

end

/*
initial  begin 
 #3;
 rst_n_2=0;
 #50;
 rst_n_2=1;

end
*/

initial begin 
clk = 0;
forever #(PERIOD/2) clk = ~clk;
end

/*
initial begin 
clk_2 = 0;
#3
forever #(PERIOD/2) clk_2 = ~clk_2;
end
*/
//================================================================================
//  behavior description
//================================================================================
//----------------------------------------------------------------------------------sensor 

assign sensor_field_hofst     = 16'h0000;

assign sen_fstr               = ssr_vsync==1'b0 & ssr_vsync_q==1'b1;
assign sen_fend               = ssr_vsync==1'b1 & ssr_vsync_q==1'b0 & sensor_start;
assign sen_vstr               = ssr_vref ==1'b1 & ssr_vref_q ==1'b0;
assign sen_vend               = ssr_vref ==1'b0 & ssr_vref_q ==1'b1;
assign sen_hstr               = ssr_href ==1'b1 & ssr_href_q ==1'b0;
assign sen_hend               = ssr_href ==1'b0 & ssr_href_q ==1'b1;
assign sen_data               = ssr_data_q;
assign sen_dvld               = ssr_href_q;
assign sensor_start_nxt       = (sen_fstr | sensor_start);

//----------------------------------------------------------------------------------border 
assign i_border_trg           = (border_finish_tgl_dly ^ border_finish_tgl) | (sen_fstr);
assign border_y_keep_nxt      = border_y_keep + i_border_trg ; 
always@(posedge clk or negedge rst_n) begin 
  if(!rst_n) begin 
  ssr_vsync_q              <= 1'h0;
  ssr_vref_q               <= 1'h0;
  ssr_href_q               <= 1'h0; 
  ssr_data_q               <= 24'h000000;
  sensor_start             <= 1'h0;
  border_finish_tgl_dly    <= 0;
  border_trg_dly           <= 0;
  border_trg_dly2          <= 0;
  border_trg_dly3          <= 0;
  border_y_keep            <= r_border_y;
  end
  else begin
  ssr_vsync_q              <= ssr_vsync;
  ssr_vref_q               <= ssr_vref;
  ssr_href_q               <= ssr_href;
  ssr_data_q               <= ssr_data;
  sensor_start             <= sensor_start_nxt;
  border_finish_tgl_dly    <= border_finish_tgl;
  border_trg_dly           <= i_border_trg;
  border_trg_dly2          <= border_trg_dly;
  border_trg_dly3          <= border_trg_dly2;
  border_y_keep            <= border_y_keep_nxt;
  end
end
//--------------------------------------------------------------------------------
// simulation patten
//--------------------------------------------------------------------------------
initial begin
wait(reg_ini_done)
#1000
`SENSOR.sensor_en = 1'b1;
end

//================================================================================
//  module instantiation
//================================================================================

sensor

#(.PX_RATE   (SSR_PX_RATE),

  .PX_FMT    (SSR_PX_FMT),

  .PX_CSEQ   ("NORMAL"),

  .EXPO_RATE (1),

  .SHOW_MSG  (1))

sensor(
// output
      .ssr_vsync              (ssr_vsync),
      .ssr_vref               (ssr_vref),

      .ssr_hsync              (),
      .ssr_href               (ssr_href),

      .ssr_blue               (),
      .ssr_hbyps              (),
      .ssr_field              (ssr_field),

      .ssr_vstr               (ssr_vstr),
      .ssr_vend               (ssr_vend),

      .ssr_data               (ssr_data),

// input control
      .ssr_href_en            (1'b1),               //control enable
// reg
      .reg_ssr_raw_bit        (4'ha),
      .reg_ssr_halfln_md      (1'b0),
      .reg_hwin_sz            (ini_ssr_hwin_sz),    //control horizontial 
      .reg_vwin_sz            (ini_ssr_vwin_sz),    //control vertical 

      .reg_hpad_sz            (4'h0),    
      .reg_vpad_sz            (4'h0),     

      .reg_hsync_sz           (15'h4),              //control(just control the bit count )
      .reg_hblkf_sz           (ini_sensor_hblkf_sz),//control sync black 
      .reg_hblkb_sz           (ini_sensor_hblkb_sz),//control sync black 

      .reg_vsync_sz           (15'h2),              //control(just control the bit count )
      .reg_vblkf1_sz          (sensor_vblkf1_sz),
      .reg_vblkf2_sz          (sensor_vblkf2_sz),
      .reg_vblkb1_sz          (sensor_vblkb1_sz),
      .reg_vblkb2_sz          (sensor_vblkb2_sz),

      .reg_tpat_en            (ini_sensor_tpat_en), //control 1:counter ; 0:picture 
      .reg_dvp_x1             (1'b0),

      .reg_tv_pal             (1'b0),
      .reg_pal_cyc_ofst       (sensor_pal_cyc_ofst),

      .reg_field_hofst        (sensor_field_hofst),
      .reg_field_vofst        (sensor_field_vofst),

// clk
      .clk                    (clk),
      .rst_n                  (rst_n)
);

border #(  
      .BORDER_COR_WIDTH       (BORDER_COR_WIDTH)
       ) 

border (
      .o_hstr                 (border_hstr),
      .o_hend                 (border_hend),
      .o_vstr                 (border_vstr),
      .o_vend                 (border_vend),
      .o_dvld                 (border_dvld ),
      .o_data_y               (border_data_y),
      .o_data_cb              (border_data_cb),
      .o_data_cr              (border_data_cr),
      .o_finish_tgl           (border_finish_tgl),


//----------------------------------------------//
// Input declaration                            //
//----------------------------------------------//

      .i_vstr                 (sen_vstr), 
      .i_vend                 (sen_vend), 
      .i_hstr                 (sen_hstr), 
      .i_hend                 (sen_hend), 
      .i_dvld                 (sen_dvld),
      .i_fstr                 (sen_fstr),
      .i_fend                 (sen_fend),
      .i_data_y               (sen_data[23:16]),
      .i_data_cb              (sen_data[15:8]),
      .i_data_cr              (sen_data[7:0]),

      .r_border_trg           (i_border_trg),
      .r_border_en            (r_border_en),
      .r_border_type          (r_border_type),
      .r_border_y             (border_y_keep),
      .r_border_cb            (r_border_cb),
      .r_border_cr            (r_border_cr),
      .r_border_width         (r_border_width),
      .r_trn_rate             (r_trn_rate),

      .r_coord_0_1st          (r_coord_0_1st),
      .r_coord_0_2nd          (r_coord_0_2nd), 
      .r_coord_1_1st          (r_coord_1_1st),
      .r_coord_1_2nd          (r_coord_1_2nd), 
      .r_coord_2_1st          (r_coord_2_1st),
      .r_coord_2_2nd          (r_coord_2_2nd), 
      .r_coord_3_1st          (r_coord_3_1st),
      .r_coord_3_2nd          (r_coord_3_2nd),           
      .r_coord_4_1st          (r_coord_4_1st),
      .r_coord_4_2nd          (r_coord_4_2nd), 

      .r_dest_hwin            (r_dest_hwin),
      .r_dest_vwin            (r_dest_vwin),
                                                                   
      .border_clk             (clk),             
      .border_rst_n           (rst_n)               
);



//--------------------------------------------------------------------------------
// register setting (override initial value)
//--------------------------------------------------------------------------------
initial begin: REG_INI
  reg_ini_done = 0;
  reg_ini.open_ini(ini_file_name);
  @ (posedge clk);
  reg_ini_done = 1;
end

//================================================================================
//  task
//================================================================================

task nope;
input port1;
input port2;
endtask 

//--------------------------------------------------------------------------------
// simulation patten
//--------------------------------------------------------------------------------


border_ver3_mon 
border_ver3_mon();

ppm_monitor #(
            .PX_FMT       ("RGB8"),
            .IMG_HSZ      (1600),
            .IMG_VSZ      (1200),
            .GOLD_HOFT    (0),
            .GOLD_VOFT    (0)
         )
ppm_monitor  (

            .vstr         (border_vstr),          
            .vend         (border_vend),            
            .hstr         (border_hstr),           
            .hend         (border_hend),            
            .dvld         (border_dvld & !r_border_type),                  //compare picture only occur in type 0   
            .bidx         (1'b0),         
            .data         ({border_data_cr,border_data_cb,border_data_y}),         
            .clk          (clk),           
            .rst_n        (rst_n)       
);


//--------------------------------------------------------------------------------
//  waveform dump setting
//--------------------------------------------------------------------------------

initial begin 
      $fsdbDumpfile("./wave/border_tb");
      $fsdbDumpvars(0,border_ver3_tb,"+all");
      $fsdbDumpvars(0,`MONITOR_TOP,"+all");
      wait(border_vend);
      wait(~border_vend);
      wait(border_vend);
      wait(~border_vend);
      #1000
      $display("\n\n test finish");
      $finish;
end

//--------------------------------------------------------------------------------
//  register initial procedure
//--------------------------------------------------------------------------------
reg_ini
reg_ini();

//--------------------------------------------------------------------------------

endmodule       
