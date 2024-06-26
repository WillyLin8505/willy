// +FHDR -----------------------------------------------------------------------
// Copyright (c) Silicon Optronics. Inc. 2021
//
// File Name:           p2s_dp.v
// Author:              Willy Lin
// Version:             $i_shift_envision$
// Last Modified On:    8/26
// Last Modified By:    $Author$
//
// File Description:   parallel to serial
//                      
// Clock Domain: clk
// -FHDR -----------------------------------------------------------------------

module i2cm_p2s_dp
(

//----------------------------------------------//
// Output declaration                           //
//----------------------------------------------//

output              o_data_ser,

//----------------------------------------------//
// Input declaration                            //
//----------------------------------------------//

input               clk,
input               rst_n,
input               i_shift_en, 
input               i_store_en,
input [7:0]         i_data_par

);

//----------------------------------------------//
// register declaration                         //
//----------------------------------------------//

reg   [7:0]         shift_reg;
wire  [7:0]         shift_reg_nxt;

//----------------------------------------------//
// Code Descriptions                            //
//----------------------------------------------//

assign shift_reg_nxt  = i_shift_en ? shift_reg << 1 :           //data will shift when shift_en enable 
                        (i_store_en ? shift_reg : i_data_par);  //if i_store_en is 1 , p2s will load the external data . 
assign o_data_ser     = shift_reg_nxt[7];

always@(posedge clk or negedge rst_n) begin
  if(~rst_n) 
    shift_reg         <= 8'h00;
  else 
    shift_reg         <= shift_reg_nxt;
end

endmodule 
