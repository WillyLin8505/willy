// +FHDR -----------------------------------------------------------------------
// Copyright (c) Silicon Optronics. Inc. 2013
//
// File Name:           i2cm_cdc_fifo.v
// Author:              Willylin
// Version:             $Revision$
// Last Modified On:    $Date$
// Last Modified By:    $Author$
//
// File Description:    Async. FIFO
// Abbreviations:
//
// Parameters:          ASYNC_EN = async. FIFO enable
//                      FIFO_DWID = FIFO Data Width
//                      FIFO_DEPTH= FIFO Depth
//                      DO_FFO_EN = F.F. output enable
// Clock Domain:        i2cm_clk: write clock domain
//                      i2cs_clk: read clock domain
// -FHDR -----------------------------------------------------------------------

module i2cm_cdc_fifo

    #(
      parameter     FIFO_DWID   = 16,
      parameter     FIFO_DEPTH  = 4,
      parameter     FIFO_CDC    = "ASYNC",
      parameter     DO_FFO_EN   = "FALSE",
      parameter     MEM_TYPE    = "DFF",
      parameter     FIFO_AWID   = $clog2(FIFO_DEPTH)
     )

(

//----------------------------------------------//
// Output declaration                           //
//----------------------------------------------//
//----------------slave clock domain
output     [7:0]           o_i2cm_wr_addr,
output     [7:0]           o_i2cm_wr_data,
output                     o_i2cm_wr_en,
//----------------master clock domain
output     [7:0]           o_i2cm_rd_addr,

//----------------------------------------------//
// Input declaration                            //
//----------------------------------------------//
//----------------slave clock domain
input                      i2cs_clk,  
input                      i2cs_rst_n,
//----------------master clock domain
input                      i2cm_clk,
input                      i2cm_rst_n,
input      [7:0]           i_i2cm_data,
input      [7:0]           i_i2cm_addr,
input                      i_i2cm_data_wen

);

//----------------------------------------------//
// Register & Wire declaration                  //
//----------------------------------------------//
//---------------------------------------------------FIFO
wire                       fifo_nfull;                              // FIFO near full @i2cm_clk doman
wire                       fifo_full;                               // FIFO full @i2cm_clk doman
wire                       fifo_nempty;                             // FIFO near empty @i2cs_clk doman
wire                       fifo_empty;                              // FIFO empty @i2cs_clk doman
wire       [15:0]          fifo_rdata;                              // FIFO read data @i2cs_clk doman
reg                        fifo_dvld;                               // fifo read data valid
  
wire       [15:0]          fifo_wdata;                              // FIFO write data @i2cm_clk doman
wire                       wflush;                                  // FIFO flush @i2cm_clk doman
wire                       fifo_rd;                                 // FIFO read signal @i2cs_clk doman
wire                       rflush;                                  // FIFO flush @i2cs_clk doman
//---------------------------------------------------other
wire       [7:0]           i2cm_data_sync_nxt;
reg        [7:0]           i2cm_data_sync;
wire       [7:0]           i2cm_addr_sync_nxt;
reg        [7:0]           i2cm_addr_sync;
wire       [7:0]           i2cm_mclk_addr;

reg                        fifo_pop_q1;        
wire      [FIFO_AWID-1:0]  waddr;
wire      [FIFO_AWID-1:0]  raddr;
wire                       fifo_push;              // FIFO push @i2cm_clk domain
wire                       fifo_pop;               // FIFO pop  @i2cs_clk domain
wire                       fifo_dvld_nxt;

//----------------------------------------------//
// Code Descriptions                            //
//----------------------------------------------//

generate
   if (FIFO_CDC == "ASYNC") begin: gen_async_proc

//--------------------------------------------------fifo
     assign fifo_wdata           = {i_i2cm_data,i_i2cm_addr};

// FIFO push/pop

     assign fifo_push            = i_i2cm_data_wen & ~fifo_full;
     assign fifo_dvld_nxt        = DO_FFO_EN ? fifo_pop_q1 : fifo_pop;
     assign fifo_pop             = ~fifo_empty;

//--------------------------------------------------data
     assign {o_i2cm_wr_data,
            o_i2cm_wr_addr}      = (fifo_dvld) ? fifo_rdata  : 16'h00;
     assign o_i2cm_wr_en         = fifo_dvld;

// ---------- Sequential Logic -----------------//

always@(posedge i2cs_clk or negedge i2cs_rst_n) begin
   if(~i2cs_rst_n) begin
      fifo_pop_q1   <= 0;
      fifo_dvld     <= 0;
   end
   else begin
      fifo_pop_q1   <= fifo_pop;
      fifo_dvld     <= fifo_dvld_nxt;
   end
end
end

   else begin
//--------------------------------------------------output
     assign o_i2cm_wr_data       = i_i2cm_data;
     assign o_i2cm_wr_addr       = i_i2cm_addr;
     assign o_i2cm_wr_en         = i_i2cm_data_wen;
   end

endgenerate

assign      o_i2cm_rd_addr       = i_i2cm_addr;

// ----------- Module Instance -----------------//

generate
   if (FIFO_CDC == "ASYNC") begin: gen_gmem

i2cm_fifo_ctrl
            #(  
                .FIFO_DEP   (FIFO_DEPTH),
                .FIFO_CDC   (FIFO_CDC)
             )

i2cm_fifo_ctrl(

                //output
                .waddr      (waddr),
                .raddr      (raddr),
                .ff_nfull   (fifo_nfull),
                .ff_full    (fifo_full),
                .ff_nempty  (fifo_nempty),
                .ff_empty   (fifo_empty),

                //input
                .push       (fifo_push),
                .pop        (fifo_pop),
                .wflush     (1'b0),
                .rflush     (1'b0),
                .wclk       (i2cm_clk),
                .rclk       (i2cs_clk),
                .wrst_n     (i2cm_rst_n),
                .rrst_n     (i2cs_rst_n)
);

ip_gmem
            #(
                .MEM_DEP    (FIFO_DEPTH),
                .MEM_DW     (FIFO_DWID),
                .DO_FFO     (DO_FFO_EN),
                .MEM_TYPE   (MEM_TYPE)
              )

ip_gmem0(

                //output
                .doa        (),
                .dob        (fifo_rdata),
                .doa_vld    (),
                .dob_vld    (),
                .memo       (),
                //input
                .wea        (fifo_push),
                .ena        (1'b1),
                .enb        (fifo_pop),
                .clr        (1'b0),
                .addra      (waddr),
                .addrb      (raddr),
                .dia        (fifo_wdata),
                .mtest      (8'b0),
                .clka       (i2cm_clk),
                .clkb       (i2cs_clk),
                .arst_n     (i2cm_rst_n),
                .brst_n     (i2cs_rst_n)
);

end
endgenerate

endmodule
