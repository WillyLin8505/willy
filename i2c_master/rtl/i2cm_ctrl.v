// +FHDR -----------------------------------------------------------------------
// Copyright (c) Silicon Optronics. Inc. 2014
//
// File Name:           i2c_m_ctrl_trl.v
// Author:              Willy Lin
// Version:             $Revision$
// Last Modified On:    2021/11/5
// Last Modified By:    $Author$
//
// File Description:    i2c master control block 
//                      
// Clock Domain:        input:384k,1536k,2048k,3072k
//                      output(SCL):96k,384k,512k,768k
//                      output(CLK):384k,1536k,2048k,3072k
// interrupt:           i_int_flag is means that the current transmit will be interrupt and i2c master will start a new transmit.
//                      arbiter receive trg_0 when trg_1 is working , then i_int_flag will be setted to 1. after i2c master status comes to 
//                      I2C_IDLE then i_int_flag will go down to 0. trg_0 transmit will start after interrupt go to 0 and trg_1 will resume 
//                      after trg_0 finish transmitting.
// -FHDR -----------------------------------------------------------------------
module i2cm_ctrl

   #( 
      parameter  NUM_WID     = 5
     )
(
//----------------------------------------------//
// Output declaration                           //
//----------------------------------------------//

output   reg                  o_sda_en,                     //use enable to control io_sda
output   reg                  o_scl_en,                     //use enable to control io_scl
output   reg                  o_wr_data_wen, 
output       [7:0]            o_data_addr, 
output                        o_trans_finish_pulse,
output                        o_wdata_nack,
output   reg [7:0]            o_addr_cnt,
output   reg [NUM_WID-1:0]    o_num_cnt,
output                        o_i2c_clr_smo,
output                        o_addr_done,
output   reg                  o_type_flag,
output                        o_num_cnt_inc,
output   reg [1:0]            o_scl_cnt,
output                        o_i2c_stop_smo,

output                        o_i2c_p2s_smo,                      
output                        o_i2c_data_0_smo, 
output                        o_i2c_data_1_smo, 
output                        o_i2c_write_addr_smo,   
output   reg                  o_dev_id_dir,                 //change dirction of the transmit       
output                        o_p2s_dp_en,
output                        o_s2p_dp_en,   
        

//----------------------------------------------//
// Input declaration                            //
//----------------------------------------------//

input                         i2c_clk,
input                         i2c_rst_n,
input                         i_i2cm_type,                  //8a8d , 16a8d
input                         i_i2cm_nack,
input                         i_i2cm_stb,                   //open start byte or not
input                         i_i2cm_seq,                   //ramdom mode , sequencial mode 
input                         i_dev_id_msb,                 //be used to know the data direction 
input                         i_sda,                        //input sda
input                         i_scl,                        //input scl
input                         i_i2cm_trg,                   //trigger signal 
input                         i_s_data,                     //the internal signal from p2s . this signal will go to control the sda enable

input [NUM_WID-1:0]           i_i2cm_num,
input [7:0]                   i_i2cm_addr,
input                         i_int_flag                    //arbiter receive trg_0 when trg_1 is working 
                                                            //then i2c master will receive i_int_flag  
);

//----------------------------------------------//
// Local Parameter                              //
//----------------------------------------------//

localparam [10:0]  I2C_IDLE           = 11'b000_0000_0010,  //wait the trigger signal and clear all flag
                   I2C_START          = 11'b100_0000_0000,  //make the start signal for sda 
                   I2C_STB            = 11'b010_0000_0000,  //let sda send start signal 
                   I2C_STB_ACK        = 11'b000_0000_0100,  //wait start byte ack 
                   I2C_ID             = 11'b010_0000_1000,  //send device id with sda 
                   I2C_ID_ACK         = 11'b000_0100_1000,  //wait the id ack
                   I2C_STOP           = 11'b000_0010_0000,  //send the stop signal with sda 
                   I2C_WADDR          = 11'b010_0001_0001,  //write address to slave i2c 
                   I2C_WADDR_ACK      = 11'b000_0101_0000,  //wait for the waddr ack 
                   I2C_WR_DATA        = 11'b010_0001_0000,  //write data to i2c slave 
                   I2C_NUM_ACK        = 11'b001_0100_0000,  //only this status will go to stop or start status
                   I2C_RD_DATA        = 11'b000_1000_0000,  //read data from i2c slave 
                   I2C_RD_ACK         = 11'b001_0000_0000;  //send ack or nonack signal 



//----------------------------------------------//
// Register & Wire declaration                  //
//----------------------------------------------//

//---------------------------------------------fsm condition & flag
reg   [10:0]           i2c_m_cs;
reg   [10:0]           i2c_m_ns;      
wire                   i2c_stb_smo;                      
wire                   i2c_s2p_smo;           
wire                   i2c_nack_smo; 
wire                   i2c_num_smo; 
wire                   i2c_start_smo; 
reg                    stb_flag;
wire                   stb_flag_nxt;
reg                    nack_flag;
wire                   nack_flag_nxt;
reg                    nack_flag2;
wire                   nack_flag2_nxt;
wire                   o_type_flag_nxt;
wire                   trg_flag;
wire                   trans_8th;
reg                    trans_finish;
wire                   trans_finish_nxt;
wire                   o_dev_id_dir_nxt;
//---------------------------------------------output 
wire                   o_scl_en_nxt;
wire                   o_sda_en_nxt;
wire                   o_wr_data_wen_nxt;
//---------------------------------------------others 
wire                   num_done;
reg                    o_i2c_clr_smo_q;
reg                    o_i2c_stop_smo_q;
wire  [7:0]            addr_cnt_basic_nxt;
reg   [7:0]            addr_cnt_basic;
wire  [NUM_WID-1:0]    num_basic_nxt;
reg   [NUM_WID-1:0]    num_basic;
reg   [NUM_WID-1:0]    trans_num;
wire  [NUM_WID-1:0]    trans_num_nxt;
//---------------------------------------------counter 
wire  [NUM_WID-1:0]    o_num_cnt_nxt;
wire                   num_cnt_clr;
wire                   num_cnt_set;
wire  [NUM_WID-1:0]    num_cnt_set_val;
wire  [7:0]            o_addr_cnt_nxt;
wire                   addr_cnt_inc;
wire                   addr_cnt_set;
wire  [7:0]            addr_cnt_set_val;
wire  [1:0]            o_scl_cnt_nxt;
wire                   scl_cnt_inc;
wire                   scl_cnt_clr;
reg   [2:0]            sda_cnt;
wire  [2:0]            sda_cnt_nxt;
wire                   sda_cnt_inc;
wire                   sda_cnt_clr;

//----------------------------------------------//
// Code Descriptions                            //
//----------------------------------------------//

//---------------fsm condition & flag

assign trg_flag            = i_i2cm_trg;
assign stb_flag_nxt        = (stb_flag | i2c_stb_smo) & ~(o_i2c_clr_smo);  
assign nack_flag_nxt       = (nack_flag | (o_wdata_nack & o_scl_cnt==2'h3)) & ~(o_i2c_clr_smo);    // nack flag wave 
assign nack_flag2_nxt      = ((nack_flag & o_wdata_nack) | nack_flag2) & ~(o_i2c_clr_smo);         // nack flag wave (the second times nack)
assign o_type_flag_nxt     = (o_type_flag | (trans_8th & o_i2c_write_addr_smo)) &      // set to 1 in waddr (16a8d)
                             ~(i2c_start_smo | o_i2c_clr_smo |                         // clear in start status or idle status 
                             (o_type_flag & trans_8th & o_i2c_write_addr_smo));        // clear flag in waddr when the flag already set to 1 
assign trans_8th           = (o_scl_cnt==2'h3) & (sda_cnt==3'h7) &   // when transmit to the eighth bit , this signal will set to one 
                             (o_i2c_p2s_smo | i2c_s2p_smo);          // will enable when the status is I2C_STB or I2C_ID or I2C_WADDR or    
                                                                     // I2C_WR_DATA or I2C_RD_DATA
assign o_wdata_nack        = i2c_nack_smo & i_sda & 
                             (o_scl_cnt==2'h2 | o_scl_cnt==2'h3);    // scl_cnt==2 for arbiter fsm ,scl_cnt==3 for i2cm
assign trans_finish_nxt    = (trans_finish | num_done |                     // when num equal to i_i2cm_num , set to 1
                             (nack_flag  & i_i2cm_nack==1'b0) |             // the first time receive nack
                             (nack_flag2 & i_i2cm_nack)) &                  // the second time receive nack
                             ~(o_i2c_clr_smo);
assign o_trans_finish_pulse= trans_finish &
                             o_i2c_stop_smo & o_scl_cnt==2'h3;              // in order to make the pulse 
assign o_dev_id_dir_nxt    = (o_dev_id_dir |
                             (i2c_nack_smo & i2c_num_smo & i_dev_id_msb & o_scl_cnt==2'h3)) & //NUM_ACK status (read address only)
                             ~(o_wdata_nack |                                                 //cannot swift when master receive a nack 
                             (i2c_num_smo & i2c_nack_smo==1'h0 & i_i2cm_seq==1'h0) |    // set to zero in RD_ACK status (random mode only)
                             o_i2c_clr_smo);                                            // set to zero in IDLE status (random mode only)
//----------------output

assign o_scl_en_nxt        = ~(o_scl_cnt==2'h0 | o_scl_cnt==2'h3 ) |                               // scl_en control by o_scl_cnt
                             (i2c_start_smo & (sda_cnt==3'h3 | sda_cnt==3'h4)) |                   // make start pulse
                             o_i2c_stop_smo_q | o_i2c_clr_smo_q;                                   // idle status,stop status
                                                                                                   // scl will keep to 1  
assign o_sda_en_nxt        = (i2c_start_smo & (sda_cnt < 3'h5)) |                                  // start signal 
                             ( o_i2c_p2s_smo & i_s_data) |                                         // according to p2s data 
                             i2c_s2p_smo |                                                         // in read data status 
                             (i2c_num_smo & i2c_nack_smo==1'h0 & (num_done | i_i2cm_seq==1'b0)) |  // in I2C_RD_ACK status
                             (i2c_num_smo & i2c_nack_smo==1'h0 & i_int_flag) |                     // in I2C_RD_ACK status , interrupt
                             i2c_nack_smo |                                                        // status in ack , need to keep 1
                             (o_i2c_stop_smo & sda_cnt==3'h3)|                                     // in stop status
                             o_i2c_clr_smo ;                                                       // in idle status 

assign o_wr_data_wen_nxt   = i2c_s2p_smo & trans_8th;                          // enable when the eighth data is parallel from serial

//----------------others
assign trans_num_nxt       = (o_addr_done) ? i_i2cm_num : trans_num;           // I2C_NUM_ACK , I2C_WADDR_ACK
assign num_done            = i2c_num_smo & (o_num_cnt_nxt == trans_num_nxt);   //have to wait for trans_num_nxt
                                                                               // in I2C_RD_ACK ,I2C_NUM_ACK . trans all data 
assign o_p2s_dp_en         = (o_scl_cnt==2'h3) & o_i2c_p2s_smo;           // active p2s when status is in I2C_ID , I2C_WADDR , I2C_WR_DATA
assign o_s2p_dp_en         = (o_scl_cnt==2'h3) & i2c_s2p_smo;             // active s2p when status is in I2C_RD_DATA status 
assign o_data_addr         = o_addr_cnt;
assign addr_cnt_basic_nxt  = ((o_i2c_write_addr_smo & o_type_flag_nxt==1'b0 & sda_cnt==3'h0) | o_i2c_clr_smo)? 
                                                                          //I2C_WADDR,store addr before nack
                             o_addr_cnt_nxt : addr_cnt_basic;
assign num_basic_nxt       = ((i2c_num_smo | i2c_nack_smo) & o_scl_cnt==2'h0) ? o_num_cnt : num_basic; //all ACK status 
assign o_addr_done         = (i_dev_id_msb ? (i2c_num_smo) :                                           //read address done , I2C_NUM_ACK
                             o_i2c_data_0_smo & (o_type_flag != i_i2cm_type)) & 
                             i2c_nack_smo ;                                                            //write address done , I2C_WADDR_ACK
//----------------counter 

assign o_num_cnt_nxt       = (num_cnt_set ? num_cnt_set_val : (o_num_cnt_inc ? o_num_cnt + 1'h1 : o_num_cnt)) & {(NUM_WID){~num_cnt_clr}};
assign o_num_cnt_inc       = ((i_dev_id_msb==1'h0 & o_scl_cnt==2'h2 & !o_wdata_nack) |  // I2C_NUM_ACK (only in write data)
                             (~i2c_nack_smo & o_scl_cnt==2'h0)) &                       // I2C_RD_ACK (only in read data)
                             i2c_num_smo ;                                              // status in I2C_NUM_ACK,I2C_RD_ACK
assign num_cnt_clr         = o_trans_finish_pulse; 
assign num_cnt_set         = o_wdata_nack | o_i2c_clr_smo;                              //in nack or resume transmit low authority transmit
assign num_cnt_set_val     = o_wdata_nack ? num_basic_nxt : i_i2cm_num;

assign o_addr_cnt_nxt      = addr_cnt_set ? addr_cnt_set_val : (addr_cnt_inc ? o_addr_cnt + 1'h1 : o_addr_cnt); 
assign addr_cnt_inc        = ((!i2c_num_smo & i2c_nack_smo & o_i2c_data_0_smo)  |   //in I2C_WADDR_ACK address count 1
                             (i2c_num_smo)) &                                       //NUM_ACK and RD_ACK
                             o_scl_cnt==2'h0;                                       //make a pulse 
assign addr_cnt_set        = o_wdata_nack |                                         //when the system receive a nack feedback , addr need get
                             o_i2c_clr_smo |                                        //get the keep address or i_i2cm_addr
                             (i_i2cm_seq & o_addr_done & o_scl_cnt==2'h1);
assign addr_cnt_set_val    = o_wdata_nack ? addr_cnt_basic : i_i2cm_addr;

assign o_scl_cnt_nxt       = (scl_cnt_inc ? o_scl_cnt+1'h1 : o_scl_cnt) & {2{~scl_cnt_clr}};
assign scl_cnt_inc         = ~o_i2c_clr_smo; 
assign scl_cnt_clr         = o_i2c_clr_smo;

assign sda_cnt_nxt         = (sda_cnt_inc ? sda_cnt+1'h1 : sda_cnt) & {3{~sda_cnt_clr}};
assign sda_cnt_inc         = i2c_start_smo |                 // when status is in I2C_START , sda_cnt will start 
                             o_p2s_dp_en |                   // in I2C_WR_DATA or I2C_WADDR or I2C_ID or I2C_STB , sda_cnt will start 
                             o_s2p_dp_en |                   // when status is in I2C_RD_DATA , sda_cnt will start 
                             o_i2c_stop_smo;                 // stop status 
assign sda_cnt_clr         = trans_8th |                     // set to 0 when data already transmit 8 bit data      
                             o_i2c_clr_smo;          

// ---------- State Machine --------------------//
assign  i2c_start_smo           = i2c_m_cs[10];
assign  o_i2c_p2s_smo           = i2c_m_cs[9];
assign  i2c_num_smo             = i2c_m_cs[8];
assign  i2c_s2p_smo             = i2c_m_cs[7];
assign  i2c_nack_smo            = i2c_m_cs[6];
assign  o_i2c_stop_smo          = i2c_m_cs[5];
assign  o_i2c_data_0_smo        = i2c_m_cs[4];
assign  o_i2c_data_1_smo        = i2c_m_cs[3];
assign  i2c_stb_smo             = i2c_m_cs[2];
assign  o_i2c_clr_smo           = i2c_m_cs[1];
assign  o_i2c_write_addr_smo    = i2c_m_cs[0];          

always @* begin : I2C_M_FSM
  i2c_m_ns = i2c_m_cs; 


  case (i2c_m_cs)
    I2C_IDLE: 

             if(trg_flag) 
               i2c_m_ns = I2C_START;
               
    I2C_START:

             begin 
               if (sda_cnt==3'h7) begin
                  if(i_i2cm_stb==1'h1 & stb_flag==1'h0)
                    i2c_m_ns = I2C_STB;
                  else
                    i2c_m_ns = I2C_ID;
               end
             end

    I2C_STB:

             if (trans_8th) 
               i2c_m_ns = I2C_STB_ACK;

    I2C_STB_ACK:

             if (o_scl_cnt==2'h3) 
                i2c_m_ns = I2C_START;

    I2C_ID:
             if (trans_8th) 
                i2c_m_ns = I2C_ID_ACK;

    I2C_ID_ACK:

             begin 
               if (o_scl_cnt==2'h3) begin
                 if (o_wdata_nack)
                   i2c_m_ns = I2C_STOP;
                 else begin
                   if(o_dev_id_dir)
                     i2c_m_ns = I2C_RD_DATA;         
                   else
                     i2c_m_ns = I2C_WADDR; 
                 end
               end
             end

    I2C_STOP:

             begin 
               if (o_scl_cnt==2'h3) begin
                 if(trans_finish_nxt | i_int_flag)
                   i2c_m_ns =I2C_IDLE;
                 else
                   i2c_m_ns =I2C_START;
               end
             end

    I2C_WADDR:

             begin 
               if (trans_8th) begin
                 if(i_dev_id_msb & (o_type_flag == i_i2cm_type))
                   i2c_m_ns = I2C_NUM_ACK;
                 else 
                   i2c_m_ns = I2C_WADDR_ACK;
               end
             end

    I2C_WADDR_ACK:

             begin 
               if (o_scl_cnt==2'h3) begin
                 if(o_wdata_nack)
                   i2c_m_ns = I2C_STOP;
                 else begin
                   if (o_type_flag != i_i2cm_type)
                     i2c_m_ns = I2C_WR_DATA;
                   else
                     i2c_m_ns = I2C_WADDR; 
                 end
               end
             end

    I2C_WR_DATA:

             begin 
               if (trans_8th) 
                 i2c_m_ns = I2C_NUM_ACK;
             end

    I2C_NUM_ACK:

             begin 
               if (o_scl_cnt==2'h3) begin
                 if(trans_finish_nxt | o_wdata_nack | (i_int_flag & i_dev_id_msb==1'h0))
                   i2c_m_ns = I2C_STOP;
                 else
                   if(i_dev_id_msb==1'h0 & i_i2cm_seq)
                     i2c_m_ns = I2C_WR_DATA;
                   else
                     i2c_m_ns = I2C_START;
               end
             end

    I2C_RD_DATA:

             begin 
               if (trans_8th) 
                 i2c_m_ns = I2C_RD_ACK;
             end

    I2C_RD_ACK:

             begin 
               if (o_scl_cnt==2'h3) begin
                 if(trans_finish_nxt | i_int_flag)
                   i2c_m_ns = I2C_STOP;
                 else begin
                   if(i_i2cm_seq)
                     i2c_m_ns = I2C_RD_DATA;
                   else
                     i2c_m_ns = I2C_START;
                 end
               end
             end

  endcase 

end


always @(posedge i2c_clk or negedge i2c_rst_n) begin
   if (~i2c_rst_n) 
    i2c_m_cs          <= 11'b000_0000_0010;
   else
    i2c_m_cs          <= i2c_m_ns; 
end


always @(posedge i2c_clk or negedge i2c_rst_n) begin
   if (~i2c_rst_n) begin

//---------------------------------------------fsm condition & flag
    stb_flag          <= 1'h0;
    nack_flag         <= 1'h0;
    nack_flag2        <= 1'h0;
    o_type_flag       <= 1'h0;
    o_dev_id_dir      <= 1'h0;
    o_i2c_clr_smo_q   <= 1'h1;
    o_i2c_stop_smo_q  <= 1'h0;
    trans_finish      <= 1'h0;
//---------------------------------------------output
    o_sda_en          <= 1'h0;
    o_scl_en          <= 1'h0;
    o_wr_data_wen     <= 1'h0;
//---------------------------------------------counter 
    o_num_cnt         <= {(NUM_WID){1'h0}};
    o_scl_cnt         <= 2'h0;
    sda_cnt           <= 3'h0;
    o_addr_cnt        <= 8'h0;
    addr_cnt_basic    <= 8'h0;
//---------------------------------------------others
    num_basic         <= 8'h0;
    trans_num         <= 8'h0;
   end
   else begin

//---------------------------------------------fsm condition & flag
    stb_flag          <= stb_flag_nxt;
    nack_flag         <= nack_flag_nxt;
    nack_flag2        <= nack_flag2_nxt;
    o_type_flag       <= o_type_flag_nxt;
    o_dev_id_dir      <= o_dev_id_dir_nxt;
    o_i2c_clr_smo_q   <= o_i2c_clr_smo;
    o_i2c_stop_smo_q  <= o_i2c_stop_smo;
    trans_finish      <= trans_finish_nxt;
//---------------------------------------------output 
    o_sda_en          <= o_sda_en_nxt;
    o_scl_en          <= o_scl_en_nxt;
    o_wr_data_wen     <= o_wr_data_wen_nxt; 
//---------------------------------------------counter 
    o_num_cnt         <= o_num_cnt_nxt;
    o_scl_cnt         <= o_scl_cnt_nxt;
    sda_cnt           <= sda_cnt_nxt;
    o_addr_cnt        <= o_addr_cnt_nxt;
    addr_cnt_basic    <= addr_cnt_basic_nxt;
//---------------------------------------------others
    num_basic         <= num_basic_nxt;
    trans_num         <= trans_num_nxt;
   end
end

endmodule 
