///////////////////////////////////////////////////////////////////////////////////////////////////
// Module Name: cpu
//
// Author:      Brian Bennett (brian.k.bennett@gmail.com)
// Create Date: 08/29/2010
//
// Description:
//
// CPU block for a fpga-based NES emulator.
//
///////////////////////////////////////////////////////////////////////////////////////////////////
module cpu
(
  input  wire        clk,         // 50MHz system clock
  input  wire        rst,         // reset signal
  input  wire        ready,       // ready signal
  input  wire [ 3:0] dbgreg_sel,  // dbg reg read/write select
  input  wire [ 7:0] din,         // data input bus
  output wire [ 7:0] dout,        // data output bus
  output wire [15:0] a,           // address bus
  output reg         r_nw,        // R/!W signal
  output reg         brk,         // debug break signal
  output reg  [ 7:0] dbgreg_out   // dbg reg read output
);

// Opcodes.
localparam [7:0] BRK = 8'h00,
                 NOP = 8'hEA;

// dbgreg_sel defines.
`define REGSEL_PCL 0
`define REGSEL_PCH 1

// Timing generation cycle states.
localparam [3:0] T0  = 3'h0,
                 T1  = 3'h1,
                 T1X = 3'h2,
                 T2  = 3'h3,
                 T3  = 3'h4,
                 T4  = 3'h5,
                 T5  = 3'h6,
                 T6  = 3'h7;

// User registers.
/*
reg [7:0] q_ac,   d_ac;   // accumulator
reg [7:0] q_x,    d_x;    // x index register
reg [7:0] q_y,    d_y;    // y index register
*/

// Processor status register.
/*
reg       q_c,    d_c;    // carry flag
reg       q_z,    d_z;    // zero flag
reg       q_i,    d_i;    // interrupt disable
reg       q_d,    d_d;    // decimal mode flag
reg       q_b,    d_b;    // break command
reg       q_v,    d_v;    // overflow flag
reg       q_n,    d_n;    // negative flag
*/

// Internal registers.
reg  [7:0] q_pcl;   // program counter low register
wire [7:0] d_pcl;
reg  [7:0] q_pch;   // program counter high register
wire [7:0] d_pch;
reg  [7:0] q_abl;   // address bus low register
wire [7:0] d_abh;
reg  [7:0] q_abh;   // address bus high register
wire [7:0] d_abl;
/*
reg  [7:0] q_dl;    // input data latch
wire [7:0] d_dl;
*/
reg  [7:0] q_pd;    // pre-decode register
wire [7:0] d_pd;
reg  [7:0] q_ir;    // instruction register
reg  [7:0] d_ir;
/*
reg  [7:0] q_dor;   // data output register
wire [7:0] d_dor;
*/
reg  [2:0] q_t;     // timing cycle register
reg  [2:0] d_t;

// Internal buses.
wire [7:0] adl;
wire [7:0] adh;

// Internal control signals.
reg  pch_adh;  // output pch reg to adh bus
reg  pcl_adl;  // output pcl reg to adl bus
reg  adh_abh;  // latch adh bus value in abh reg
reg  adl_abl;  // latch adl bus value in abl reg
reg  i_pc;     // increment pc

//
// Ready Control.
//
wire rdy;     // internal, modified ready signal.
reg  q_ready; // latch external ready signal to delay 1 clk so top-level addr muxing can complete

always @(posedge clk)
  begin
    if (rst)
      q_ready <= 1;
    else
      q_ready <= ready;
  end

assign rdy = ready && q_ready;

//
// Clock phase generation logic.
//
reg  [1:0] q_clk_phase;
wire [1:0] d_clk_phase;

always @(posedge clk)
  begin
    if (rst)
      q_clk_phase <= 2'b01;
    else if (rdy)
      q_clk_phase <= d_clk_phase;
  end

assign d_clk_phase = q_clk_phase + 1;

//
// Update phase-1 clocked registers.
//
always @(posedge clk)
  begin
    if (rst)
      begin
        /*
        q_ac   <= 8'h00;
        q_x    <= 8'h00;
        q_y    <= 8'h00;
        q_c    <= 1'b0;
        q_z    <= 1'b0;
        q_i    <= 1'b0;
        q_d    <= 1'b0;
        q_b    <= 1'b0;
        q_v    <= 1'b0;
        q_n    <= 1'b0;
        */
        q_abl  <= 8'h00;
        q_abh  <= 8'h80;
        q_ir   <= BRK;
        /*
        q_dor  <= 8'h00;
        */
        q_t    <= T1;
      end
    else if (rdy && (q_clk_phase == 2'b00))
      begin
        /*
        q_ac   <= d_ac;
        q_x    <= d_x;
        q_y    <= d_y;
        q_c    <= d_c;
        q_z    <= d_z;
        q_i    <= d_i;
        q_d    <= d_d;
        q_b    <= d_b;
        q_v    <= d_v;
        q_n    <= d_n;
        */
        q_abl  <= d_abl;
        q_abh  <= d_abh;
        q_ir   <= d_ir;
        /*
        q_dor  <= d_dor;
        */
        q_t    <= d_t;
      end
  end

//
// Update phase-2 clocked registers.
//
always @(posedge clk)
  begin
    if (rst)
      begin
        q_pcl <= 8'h00;
        q_pch <= 8'h80;
        /*
        q_dl  <= 8'h00;
        */
        q_pd  <= 8'h00;
      end
    else if (rdy && (q_clk_phase == 2'b10))
      begin
        q_pcl <= d_pcl;
        q_pch <= d_pch;
        /*
        q_dl  <= d_dl;
        */
        q_pd  <= d_pd;
      end
  end

//
// Timing Generation Logic, Decode ROM, and Random Control Logic.
//
always @*
  begin
    // Default all control signals to 0.
    pcl_adl = 1'b0;
    pch_adh = 1'b0;
    adl_abl = 1'b0;
    adh_abh = 1'b0;
    i_pc    = 1'b0;
    brk     = 1'b0;

    // Default to memory read operation.
    r_nw = 1'b1;

    // Default FFs to same state.
    d_t  = q_t;
    d_ir = q_ir;

    if (q_t == T0)
      begin
        i_pc = 1'b1;
        d_t  = T1;
      end
    else if (q_t == T1)
      begin
        d_t = T0;

        if (q_ir == BRK)
          brk = (q_clk_phase == 2'b01) && rdy;
      end

    if (d_t == T0)
      begin
        pcl_adl = 1'b1;
        pch_adh = 1'b1;
        adl_abl = 1'b1;
        adh_abh = 1'b1;
      end
    else if (d_t == T1)
      begin
        d_ir = q_pd;
      end
  end

//
// Internal signal plumbing.
//
assign d_abl = (adl_abl)   ? adl : q_abl;
assign d_abh = (adh_abh)   ? adh : q_abh;

assign adl   = (pcl_adl)   ? q_pcl : 8'h00;
assign adh   = (pch_adh)   ? q_pch : 8'h00;

assign d_pd  = din;
/*
assign d_dl  = din;
*/

assign { d_pch, d_pcl } = (i_pc) ? { q_pch, q_pcl } + 16'h0001 : { q_pch, q_pcl };

//
// Assign output signals.
//
assign dout = 8'hCC;
assign a    = { q_abh, q_abl };

always @(dbgreg_sel)
  begin
    case (dbgreg_sel)
      `REGSEL_PCL:  dbgreg_out = q_pcl;
      `REGSEL_PCH:  dbgreg_out = q_pch;
      default:      dbgreg_out = 8'hBD;
    endcase
  end

endmodule

