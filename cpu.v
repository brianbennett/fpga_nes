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
localparam [7:0] BRK     = 8'h00,
                 LDA_IMM = 8'hA9,
                 LDX_IMM = 8'hA2,
                 LDY_IMM = 8'hA0,
                 NOP     = 8'hEA;

// dbgreg_sel defines.
`define REGSEL_PCL 0
`define REGSEL_PCH 1
`define REGSEL_AC  2
`define REGSEL_X   3
`define REGSEL_Y   4
`define REGSEL_P   5

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
reg  [7:0] q_ac;     // accumulator register
wire [7:0] d_ac;
reg  [7:0] q_x;      // x index register
wire [7:0] d_x;
reg  [7:0] q_y;      // y index register
wire [7:0] d_y;

// Processor status register.
wire [7:0] p;        // full processor status reg, grouped from the following FFs
/*
reg        q_c;      // carry flag
wire       d_c;
*/
reg        q_z;      // zero flag
wire       d_z;
/*
reg        q_i;      // interrupt disable
wire       d_i;
reg        q_d;      // decimal mode flag
wire       d_d;
reg        q_b;      // break command
wire       d_b;
reg        q_v;      // overflow flag
wire       d_v;
*/
reg        q_n;      // negative flag
wire       d_n;

// Internal registers.
reg  [7:0] q_pcl;    // program counter low register
wire [7:0] d_pcl;
reg  [7:0] q_pch;    // program counter high register
wire [7:0] d_pch;
reg  [7:0] q_abl;    // address bus low register
wire [7:0] d_abh;
reg  [7:0] q_abh;    // address bus high register
wire [7:0] d_abl;
reg  [7:0] q_dl;     // input data latch
wire [7:0] d_dl;
reg  [7:0] q_pd;     // pre-decode register
wire [7:0] d_pd;
reg  [7:0] q_ir;     // instruction register
reg  [7:0] d_ir;
/*
reg  [7:0] q_dor;    // data output register
wire [7:0] d_dor;
*/
reg  [2:0] q_t;      // timing cycle register
reg  [2:0] d_t;
reg  [7:0] q_add;    // adder hold register
reg  [7:0] d_add;

// Internal buses.
wire [7:0] adl;
wire [7:0] adh_in, adh_out;
wire [7:0] db_in,  db_out;
wire [7:0] sb_in,  sb_out;

// Internal control signals.
reg        pch_adh;  // output pch reg to adh bus
reg        pcl_adl;  // output pcl reg to adl bus
reg        adh_abh;  // latch adh bus value in abh reg
reg        adl_abl;  // latch adl bus value in abl reg
reg        i_pc;     // increment pc
reg        sb_ac;    // latch sb bus value in ac reg
reg        sb_x;     // latch sb bus value in x reg
reg        sb_y;     // latch sb bus value in y reg
reg        add_sb;   // output add reg to sb bus
reg        dl_db;    // output dl reg to dl bus
reg        sb_db;    // controls sb/db pass mosfet
reg        sb_adh;   // controls sb/adh pass mosfet
reg        dbz_z;    // latch ~|db into z status reg
reg        db7_n;    // latch db[7] into n status reg

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
        q_ac   <= 8'h00;
        q_x    <= 8'h00;
        q_y    <= 8'h00;
        /*
        q_c    <= 1'b0;
        */
        q_z    <= 1'b0;
        /*
        q_i    <= 1'b0;
        q_d    <= 1'b0;
        q_b    <= 1'b0;
        q_v    <= 1'b0;
        */
        q_n    <= 1'b0;
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
        q_ac   <= d_ac;
        q_x    <= d_x;
        q_y    <= d_y;
        /*
        q_c    <= d_c;
        */
        q_z    <= d_z;
        /*
        q_i    <= d_i;
        q_d    <= d_d;
        q_b    <= d_b;
        q_v    <= d_v;
        */
        q_n    <= d_n;
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
        q_dl  <= 8'h00;
        q_pd  <= 8'h00;
        q_add <= 8'h00;
      end
    else if (rdy && (q_clk_phase == 2'b10))
      begin
        q_pcl <= d_pcl;
        q_pch <= d_pch;
        q_dl  <= d_dl;
        q_pd  <= d_pd;
        q_add <= d_add;
      end
  end

//
// Timing Generation Logic
//
always @*
  begin
    case (q_t)
      T0:
        d_t = T1;
      T1, T1X:
        begin
          // These instructions are able to prefetch the next opcode during their final cycle.
          if ((q_ir == BRK) || (q_ir == NOP))
            d_t = T1;

          // These instructions are in their last cycle, but are using the data bus during the last
          // cycle (e.g., load/store) such that they can't prefetch.
          else if ((q_ir == LDA_IMM) || (q_ir == LDX_IMM) || (q_ir == LDY_IMM))
            d_t = T0;

          else
            d_t = T2;
        end
      T2:
        d_t = T3;
      T3:
        d_t = T4;
      T4:
        d_t = T5;
      T5:
        d_t = T6;
      T6:
        d_t = T0;
    endcase

    // Update IR register on cycle 1, otherwise retain current IR.
    if (d_t == T1)
      d_ir = q_pd;
    else
      d_ir = q_ir;
  end

//
// Decode ROM and Random Control Logic
//
reg load_prg_byte;  // put PC on addr bus, increment PC, and latch returned data

always @*
  begin
    // Default all control signals to 0.
    pcl_adl = 1'b0;
    pch_adh = 1'b0;
    adl_abl = 1'b0;
    adh_abh = 1'b0;
    i_pc    = 1'b0;
    brk     = 1'b0;
    sb_ac   = 1'b0;
    sb_x    = 1'b0;
    sb_y    = 1'b0;
    add_sb  = 1'b0;
    dl_db   = 1'b0;
    sb_db   = 1'b0;
    sb_adh  = 1'b0;
    dbz_z   = 1'b0;
    db7_n   = 1'b0;

    // Default to memory read operation.
    r_nw = 1'b1;

    load_prg_byte = 1'b1;
    if (load_prg_byte)
      begin
        i_pc    = 1'b1;
        pcl_adl = 1'b1;
        pch_adh = 1'b1;
        adl_abl = 1'b1;
        adh_abh = 1'b1;        
      end

    if (q_t == T1)
      begin
        case (q_ir)
          BRK:
            begin
              brk = (q_clk_phase == 2'b01) && rdy;
            end
          LDA_IMM:
            begin
              sb_ac = 1'b1;
              sb_db = 1'b1;
              dl_db = 1'b1;
              dbz_z = 1'b1;
              db7_n = 1'b1;
            end
          LDX_IMM:
            begin
              sb_x  = 1'b1;
              sb_db = 1'b1;
              dl_db = 1'b1;
              dbz_z = 1'b1;
              db7_n = 1'b1;
            end
          LDY_IMM:
            begin
              sb_y  = 1'b1;
              sb_db = 1'b1;
              dl_db = 1'b1;
              dbz_z = 1'b1;
              db7_n = 1'b1;
            end
        endcase
      end
  end

//
// ALU
//
reg [7:0] ai;  // a input register
reg [7:0] bi;  // b input register

always @*
  begin
    // assume 0_add
    ai = 8'h0;
    // assume db_add
    bi = db_out;

    // assume sums
    d_add = ai + bi;
  end

//
// Assign next FF states.
//
assign d_abl            = (adl_abl) ? adl                         : q_abl;
assign d_abh            = (adh_abh) ? adh_out                     : q_abh;
assign d_ac             = (sb_ac)   ? sb_out                      : q_ac;
assign d_x              = (sb_x)    ? sb_out                      : q_x;
assign d_y              = (sb_y)    ? sb_out                      : q_y;
assign d_pd             = din;
assign d_dl             = din;
assign { d_pch, d_pcl } = (i_pc)    ? { q_pch, q_pcl } + 16'h0001 : { q_pch, q_pcl };
assign d_z              = (dbz_z)   ? ~|db_out                    : q_z;
assign d_n              = (db7_n)   ? db_out[7]                   : q_n;

//
// Update internal buses.  Use of in/out to replicate pass mosfets and avoid using internal
// tristate buffers.
//
assign adl     = (pcl_adl) ? q_pcl : 8'h00;
assign adh_in  = (pch_adh) ? q_pch : 8'h00;
assign db_in   = (dl_db)   ? q_dl  : 8'h00;
assign sb_in   = (add_sb)  ? q_add : 8'h00;

assign adh_out = (sb_adh & sb_db) ? (adh_in | sb_in | db_in) :
                 (sb_adh)         ? (adh_in | sb_in)         :
                                    (adh_in);
assign db_out  = (sb_db & sb_adh) ? (db_in | sb_in | adh_in) :
                 (sb_db)          ? (db_in | sb_in)          :
                                    (db_in);
assign sb_out  = (sb_adh & sb_db) ? (sb_in | db_in | adh_in) :
                 (sb_db)          ? (sb_in | db_in)          :
                 (sb_adh)         ? (sb_in | adh_in)         :
                                    (sb_in);

// Combine full processor status register.
assign p = { q_n, 5'b00000, q_z, 1'b0 };

//
// Assign output signals.
//
assign dout = 8'hCC;
assign a    = { q_abh, q_abl };

always @*
  begin
    case (dbgreg_sel)
      `REGSEL_PCL:  dbgreg_out = q_pcl;
      `REGSEL_PCH:  dbgreg_out = q_pch;
      `REGSEL_AC:   dbgreg_out = q_ac;
      `REGSEL_X:    dbgreg_out = q_x;
      `REGSEL_Y:    dbgreg_out = q_y;
      `REGSEL_P:    dbgreg_out = p;
      default:      dbgreg_out = 8'hBD;
    endcase
  end

endmodule

