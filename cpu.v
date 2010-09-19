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
  input  wire [ 3:0] dbgreg_sel,  // dbg reg select
  input  wire [ 7:0] dbgreg_in,   // dbg reg write input
  input  wire        dbgreg_wr,   // dbg reg rd/wr select
  input  wire [ 7:0] din,         // data input bus
  output wire [ 7:0] dout,        // data output bus
  output wire [15:0] a,           // address bus
  output reg         r_nw,        // R/!W signal
  output reg         brk,         // debug break signal
  output reg  [ 7:0] dbgreg_out   // dbg reg read output
);

// Opcodes.
localparam [7:0] BRK     = 8'h00,
                 LDA_ABS = 8'hAD,
                 LDA_IMM = 8'hA9,
                 LDA_ZP  = 8'hA5,
                 LDA_ZPX = 8'hB5,
                 LDX_ABS = 8'hAE,
                 LDX_IMM = 8'hA2,
                 LDX_ZP  = 8'hA6,
                 LDX_ZPY = 8'hB6,
                 LDY_ABS = 8'hAC,
                 LDY_IMM = 8'hA0,
                 LDY_ZP  = 8'hA4,
                 LDY_ZPX = 8'hB4,
                 NOP     = 8'hEA,
                 STA_ABS = 8'h8D,
                 STA_ZP  = 8'h85,
                 STA_ZPX = 8'h95,
                 STX_ABS = 8'h8E,
                 STX_ZP  = 8'h86,
                 STX_ZPY = 8'h96,
                 STY_ABS = 8'h8C,
                 STY_ZP  = 8'h84,
                 STY_ZPX = 8'h94;

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
reg        q_z;      // zero flag
wire       d_z;
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
reg  [7:0] q_dor;    // data output register
wire [7:0] d_dor;
reg  [2:0] q_t;      // timing cycle register
reg  [2:0] d_t;
reg  [7:0] q_add;    // adder hold register
reg  [7:0] d_add;
reg  [7:0] q_ai;     // alu input register a
wire [7:0] d_ai;
reg  [7:0] q_bi;     // alu input register b
wire [7:0] d_bi;

// Internal buses.
wire [7:0] adl;      // ADL bus
wire [7:0] adh_in,   // ADH bus
           adh_out;
wire [7:0] db_in,    // DB bus
           db_out;
wire [7:0] sb_in,    // SB bus
           sb_out;

//
// Internal control signals.
//

// ADL bus drive enables.
wire       add_adl;  // output adder hold register to adl bus
wire       dl_adl;   // output dl reg to adl bus
wire       pcl_adl;  // output pcl reg to adl bus

// ADH bus drive enables.
wire       dl_adh;   // output dl reg to adh bus
wire       pch_adh;  // output pch reg to adh bus

// DB bus drive enables.
wire       ac_db;    // output a reg to db bus
wire       dl_db;    // output dl reg to db bus

// SB bus drive enables.
wire       x_sb;     // output x reg to sb bus
wire       y_sb;     // output y reg to sb bus

// Pass MOSFET controls.
wire       sb_adh;   // controls sb/adh pass mosfet
wire       sb_db;    // controls sb/db pass mosfet

// Register LOAD controls.
wire       sb_ac;    // latch sb bus value in ac reg
wire       sb_x;     // latch sb bus value in x reg
wire       sb_y;     // latch sb bus value in y reg
wire       adh_abh;  // latch adh bus value in abh reg
wire       adl_abl;  // latch adl bus value in abl reg
wire       db_add;   // latch db bus value in bi reg
wire       sb_add;   // latch sb bus value in ai reg
wire       zero_add; // latch 0 into ai reg

// Misc. controls.
wire       i_pc;     // increment pc
wire       db7_n;    // latch db[7] into n status reg
wire       dbz_z;    // latch ~|db into z status reg

// ALU op controls.
wire       sums;     // perform addition on alu

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
        q_z    <= 1'b0;
        q_n    <= 1'b0;
        q_abl  <= 8'h00;
        q_abh  <= 8'h80;
        q_ir   <= BRK;
        q_dor  <= 8'h00;
        q_t    <= T1;
        q_ai   <= 8'h00;
        q_bi   <= 8'h00;
      end
    else if (rdy && (q_clk_phase == 2'b00))
      begin
        q_ac   <= d_ac;
        q_x    <= d_x;
        q_y    <= d_y;
        q_z    <= d_z;
        q_n    <= d_n;
        q_abl  <= d_abl;
        q_abh  <= d_abh;
        q_ir   <= d_ir;
        q_dor  <= d_dor;
        q_t    <= d_t;
        q_ai   <= d_ai;
        q_bi   <= d_bi;
      end
    else if (!rdy)
      begin
        // Continue to update the address bus registers during a debug break. This allows correct
        // function when the debugger updates the PC.
        q_abl  <= d_abl;
        q_abh  <= d_abh;

        // Update registers based on debug register write packets.
        if (dbgreg_wr)
          begin
            q_ac <= (dbgreg_sel == `REGSEL_AC) ? dbgreg_in    : q_ac;
            q_x  <= (dbgreg_sel == `REGSEL_X)  ? dbgreg_in    : q_x;
            q_y  <= (dbgreg_sel == `REGSEL_Y)  ? dbgreg_in    : q_y;
            q_z  <= (dbgreg_sel == `REGSEL_P)  ? dbgreg_in[1] : q_z;
            q_n  <= (dbgreg_sel == `REGSEL_P)  ? dbgreg_in[7] : q_n;
          end
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
    else if (!rdy && dbgreg_wr)
      begin
        // Update registers based on debug register write packets.
        q_pcl <= (dbgreg_sel == `REGSEL_PCL) ? dbgreg_in : q_pcl;
        q_pch <= (dbgreg_sel == `REGSEL_PCH) ? dbgreg_in : q_pch;
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
          // cycle (e.g., load) such that they can't prefetch.
          else if ((q_ir == LDA_IMM) || (q_ir == LDX_IMM) || (q_ir == LDY_IMM))
            d_t = T0;

          else
            d_t = T2;
        end
      T2:
        begin
          // These instructions are in their last cycle, but are using the data bus during the last
          // cycle (e.g., load/store) such that they can't prefetch.
          if ((q_ir == STA_ZP) || (q_ir == STX_ZP) || (q_ir == STY_ZP) ||
              (q_ir == LDA_ZP) || (q_ir == LDX_ZP) || (q_ir == LDY_ZP))
            d_t = T0;

          else
            d_t = T3;
        end
      T3:
        begin
          // These instructions are in their last cycle, but are using the data bus during the last
          // cycle (e.g., load/store) such that they can't prefetch.
          if ((q_ir == STA_ABS) || (q_ir == STX_ABS) || (q_ir == STY_ABS) ||
              (q_ir == STA_ZPX) || (q_ir == STX_ZPY) || (q_ir == STY_ZPX) ||
              (q_ir == LDA_ABS) || (q_ir == LDX_ABS) || (q_ir == LDY_ABS) ||
              (q_ir == LDA_ZPX) || (q_ir == LDX_ZPY) || (q_ir == LDY_ZPX))
            d_t = T0;

          else
            d_t = T4;
        end
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
// Decode ROM
//
reg load_prg_byte;     // put PC on addr bus, increment PC, and latch returned data
reg lda_last_cycle;    // final cycle of an lda inst
reg ldx_last_cycle;    // final cycle of an ldx inst
reg ldy_last_cycle;    // final cycle of an ldy inst
reg ac_to_dor;         // load current ac value into dor
reg x_to_dor;          // load current x value into dor
reg y_to_dor;          // load current y value into dor
reg zp_addr_to_ab;     // load ab with zero-page address specified in dl
reg zpidx_addr_to_ab;  // load ab with zero-page address computes for zpx/zpy instructions
reg zpx_comps_to_alu;  // load alu inputs ai/bi with vals for zpx addr calc
reg zpy_comps_to_alu;  // load alu inputs ai/bi with vals for zpy addr calc
reg dl_to_add;         // load value from data bus into the add reg
reg abs_addr_to_ab;    // load an absolute address into the ab regs (dl to abl, add to abh)

always @*
  begin
    // Default all control signals to 0.
    load_prg_byte    = 1'b0;
    lda_last_cycle   = 1'b0;
    ldx_last_cycle   = 1'b0;
    ldy_last_cycle   = 1'b0;
    ac_to_dor        = 1'b0;
    x_to_dor         = 1'b0;
    y_to_dor         = 1'b0;
    zp_addr_to_ab    = 1'b0;
    zpidx_addr_to_ab = 1'b0;
    zpx_comps_to_alu = 1'b0;
    zpy_comps_to_alu = 1'b0;
    dl_to_add        = 1'b0;
    abs_addr_to_ab   = 1'b0;

    // Defaults for output signals.
    r_nw = 1'b1;
    brk  = 1'b0;

    if (q_t == T0)
      begin
        load_prg_byte = 1'b1;
      end
    else if (q_t == T1)
      begin
        case (q_ir)
          BRK:
            begin
              load_prg_byte = 1'b1;
              brk = (q_clk_phase == 2'b01) && rdy;
            end
          LDA_ABS, LDX_ABS, LDY_ABS, STA_ABS, STX_ABS, STY_ABS:
            begin
              load_prg_byte = 1'b1;
              dl_to_add     = 1'b1;
            end
          LDA_IMM:
            begin
              load_prg_byte  = 1'b1;
              lda_last_cycle = 1'b1;
            end
          LDA_ZP, LDX_ZP, LDY_ZP:
            zp_addr_to_ab = 1'b1;
          LDA_ZPX, LDY_ZPX, STA_ZPX, STY_ZPX:
            zpx_comps_to_alu = 1'b1;
          LDX_IMM:
            begin
              load_prg_byte  = 1'b1;
              ldx_last_cycle = 1'b1;
            end
          LDX_ZPY, STX_ZPY:
            zpy_comps_to_alu = 1'b1;
          LDY_IMM:
            begin
              load_prg_byte  = 1'b1;
              ldy_last_cycle = 1'b1;
            end
          NOP:
            load_prg_byte = 1'b1;
          STA_ZP:
            begin
              zp_addr_to_ab = 1'b1;
              ac_to_dor     = 1'b1;
            end
          STX_ZP:
            begin
              zp_addr_to_ab = 1'b1;
              x_to_dor      = 1'b1;
            end
          STY_ZP:
            begin
              zp_addr_to_ab = 1'b1;
              y_to_dor      = 1'b1;
            end
        endcase
      end
    else if (q_t == T2)
      begin
        case (q_ir)
          LDA_ABS, LDX_ABS, LDY_ABS:
            abs_addr_to_ab = 1'b1;
          LDA_ZP:
            begin
              load_prg_byte  = 1'b1;
              lda_last_cycle = 1'b1;
            end
          LDA_ZPX, LDX_ZPY, LDY_ZPX:
            zpidx_addr_to_ab = 1'b1;
          LDX_ZP:
            begin
              load_prg_byte  = 1'b1;
              ldx_last_cycle = 1'b1;
            end
          LDY_ZP:
            begin
              load_prg_byte  = 1'b1;
              ldy_last_cycle = 1'b1;
            end
          STA_ABS:
            begin
              abs_addr_to_ab = 1'b1;
              ac_to_dor      = 1'b1;
            end            
          STA_ZP, STX_ZP, STY_ZP:
            begin
              load_prg_byte = 1'b1;
              r_nw          = 1'b0;
            end
          STA_ZPX:
            begin
              zpidx_addr_to_ab = 1'b1;
              ac_to_dor        = 1'b1;
            end
          STX_ABS:
            begin
              abs_addr_to_ab = 1'b1;
              x_to_dor       = 1'b1;
            end            
          STX_ZPY:
            begin
              zpidx_addr_to_ab = 1'b1;
              x_to_dor         = 1'b1;
            end
          STY_ABS:
            begin
              abs_addr_to_ab = 1'b1;
              y_to_dor       = 1'b1;
            end            
          STY_ZPX:
            begin
              zpidx_addr_to_ab = 1'b1;
              y_to_dor         = 1'b1;
            end
        endcase
      end
    else if (q_t == T3)
      begin
        case (q_ir)
          LDA_ABS, LDA_ZPX:
            begin
              load_prg_byte  = 1'b1;
              lda_last_cycle = 1'b1;
            end
          LDX_ABS, LDX_ZPY:
            begin
              load_prg_byte  = 1'b1;
              ldx_last_cycle = 1'b1;
            end
          LDY_ABS, LDY_ZPX:
            begin
              load_prg_byte  = 1'b1;
              ldy_last_cycle = 1'b1;
            end
          STA_ABS, STA_ZPX, STX_ABS, STX_ZPY, STY_ABS, STY_ZPX:
            begin
              load_prg_byte = 1'b1;
              r_nw          = 1'b0;
            end
        endcase
      end
  end

//
// ALU
//
always @*
  begin
    if (sums)
      d_add = q_ai + q_bi;
    else
      d_add = q_add;
  end

//
// Random Control Logic
//
assign add_adl  = zpidx_addr_to_ab | abs_addr_to_ab;
assign dl_adl   = zp_addr_to_ab;
assign pcl_adl  = load_prg_byte;
assign dl_adh   = abs_addr_to_ab;
assign pch_adh  = load_prg_byte;
assign ac_db    = ac_to_dor;
assign dl_db    = lda_last_cycle   | ldx_last_cycle   | ldy_last_cycle   |
                  zpx_comps_to_alu | zpy_comps_to_alu | dl_to_add;
assign x_sb     = zpx_comps_to_alu | x_to_dor;
assign y_sb     = zpy_comps_to_alu | y_to_dor;
assign sb_adh   = 1'b0;
assign sb_db    = lda_last_cycle   | ldx_last_cycle   | ldy_last_cycle   |
                  x_to_dor         | y_to_dor;
assign adh_abh  = load_prg_byte    | zp_addr_to_ab    | zpidx_addr_to_ab |
                  abs_addr_to_ab;
assign adl_abl  = load_prg_byte    | zp_addr_to_ab    | zpidx_addr_to_ab |
                  abs_addr_to_ab;
assign db_add   = zpx_comps_to_alu | zpy_comps_to_alu | dl_to_add;
assign zero_add = dl_to_add;
assign sb_ac    = lda_last_cycle;
assign sb_add   = zpx_comps_to_alu | zpy_comps_to_alu;
assign sb_x     = ldx_last_cycle;
assign sb_y     = ldy_last_cycle;
assign i_pc     = load_prg_byte;
assign db7_n    = lda_last_cycle   | ldx_last_cycle   | ldy_last_cycle;
assign dbz_z    = lda_last_cycle   | ldx_last_cycle   | ldy_last_cycle;
assign sums     = zpidx_addr_to_ab | abs_addr_to_ab;

//
// Update internal buses.  Use of in/out to replicate pass mosfets and avoid using internal
// tristate buffers.
//
assign adl     = (pcl_adl) ? q_pcl :
                 (dl_adl)  ? q_dl  :
                 (add_adl) ? q_add : 8'h00;
assign adh_in  = (dl_adh)  ? q_dl  : 
                 (pch_adh) ? q_pch : 8'h00;
assign db_in   = (dl_db)   ? q_dl  :
                 (ac_db)   ? q_ac  : 8'h00;
assign sb_in   = (x_sb)    ? q_x   :
                 (y_sb)    ? q_y   : 8'h00;

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

//
// Assign next FF states.
//
assign d_abl            = (adl_abl)  ? adl                         : q_abl;
assign d_abh            = (adh_abh)  ? adh_out                     : q_abh;
assign d_ac             = (sb_ac)    ? sb_out                      : q_ac;
assign d_x              = (sb_x)     ? sb_out                      : q_x;
assign d_y              = (sb_y)     ? sb_out                      : q_y;
assign d_pd             = din;
assign d_dl             = din;
assign d_dor            = db_out;
assign { d_pch, d_pcl } = (i_pc)     ? { q_pch, q_pcl } + 16'h0001 : { q_pch, q_pcl };
assign d_z              = (dbz_z)    ? ~|db_out                    : q_z;
assign d_n              = (db7_n)    ? db_out[7]                   : q_n;
assign d_ai             = (sb_add)   ? sb_out                      :
                          (zero_add) ? 8'h0                        : q_ai;
assign d_bi             = (db_add)   ? db_out                      : q_bi;

// Combine full processor status register.
assign p = { q_n, 5'b00000, q_z, 1'b0 };

//
// Assign output signals.
//
assign dout = q_dor;
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

