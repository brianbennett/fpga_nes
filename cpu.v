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
localparam [7:0] AND_ABS  = 8'h2D,
                 AND_ABSX = 8'h3D,
                 AND_ABSY = 8'h39,
                 AND_IMM  = 8'h29,
                 AND_INDX = 8'h21,
                 AND_INDY = 8'h31,
                 AND_ZP   = 8'h25,
                 AND_ZPX  = 8'h35,
                 BRK      = 8'h00,
                 LDA_ABS  = 8'hAD,
                 LDA_ABSX = 8'hBD,
                 LDA_ABSY = 8'hB9,
                 LDA_IMM  = 8'hA9,
                 LDA_INDX = 8'hA1,
                 LDA_INDY = 8'hB1,
                 LDA_ZP   = 8'hA5,
                 LDA_ZPX  = 8'hB5,
                 LDX_ABS  = 8'hAE,
                 LDX_ABSY = 8'hBE,
                 LDX_IMM  = 8'hA2,
                 LDX_ZP   = 8'hA6,
                 LDX_ZPY  = 8'hB6,
                 LDY_ABS  = 8'hAC,
                 LDY_ABSX = 8'hBC,
                 LDY_IMM  = 8'hA0,
                 LDY_ZP   = 8'hA4,
                 LDY_ZPX  = 8'hB4,
                 NOP      = 8'hEA,
                 ORA_ABS  = 8'h0D,
                 ORA_ABSX = 8'h1D,
                 ORA_ABSY = 8'h19,
                 ORA_IMM  = 8'h09,
                 ORA_INDX = 8'h01,
                 ORA_INDY = 8'h11,
                 ORA_ZP   = 8'h05,
                 ORA_ZPX  = 8'h15,
                 STA_ABS  = 8'h8D,
                 STA_ABSX = 8'h9D,
                 STA_ABSY = 8'h99,
                 STA_INDX = 8'h81,
                 STA_INDY = 8'h91,
                 STA_ZP   = 8'h85,
                 STA_ZPX  = 8'h95,
                 STX_ABS  = 8'h8E,
                 STX_ZP   = 8'h86,
                 STX_ZPY  = 8'h96,
                 STY_ABS  = 8'h8C,
                 STY_ZP   = 8'h84,
                 STY_ZPX  = 8'h94,
                 TAX      = 8'hAA,
                 TAY      = 8'hA8,
                 TSX      = 8'hBA,
                 TXA      = 8'h8A,
                 TXS      = 8'h9A,
                 TYA      = 8'h98;

// dbgreg_sel defines.
`define REGSEL_PCL 0
`define REGSEL_PCH 1
`define REGSEL_AC  2
`define REGSEL_X   3
`define REGSEL_Y   4
`define REGSEL_P   5
`define REGSEL_S   6

// Timing generation cycle states.
localparam [3:0] T0  = 3'h0,
                 T1  = 3'h1,
                 T2  = 3'h2,
                 T3  = 3'h3,
                 T4  = 3'h4,
                 T5  = 3'h5,
                 T6  = 3'h6,
                 T7  = 3'h7;

// User registers.
reg  [7:0] q_ac;     // accumulator register
wire [7:0] d_ac;
reg  [7:0] q_x;      // x index register
wire [7:0] d_x;
reg  [7:0] q_y;      // y index register
wire [7:0] d_y;

// Processor status register.
wire [7:0] p;        // full processor status reg, grouped from the following FFs
reg        q_n;      // negative flag
wire       d_n;
reg        q_z;      // zero flag
wire       d_z;

// Internal registers.
reg  [7:0] q_abh;    // address bus high register
wire [7:0] d_abh;
reg  [7:0] q_abl;    // address bus low register
wire [7:0] d_abl;
reg        q_acr;    // internal carry latch
reg  [7:0] q_add;    // adder hold register
reg  [7:0] d_add;
reg  [7:0] q_ai;     // alu input register a
wire [7:0] d_ai;
reg  [7:0] q_bi;     // alu input register b
wire [7:0] d_bi;
reg  [7:0] q_dl;     // input data latch
wire [7:0] d_dl;
reg  [7:0] q_dor;    // data output register
wire [7:0] d_dor;
reg  [7:0] q_ir;     // instruction register
reg  [7:0] d_ir;
reg  [7:0] q_pch;    // program counter high register
wire [7:0] d_pch;
reg  [7:0] q_pcl;    // program counter low register
wire [7:0] d_pcl;
reg  [7:0] q_pd;     // pre-decode register
wire [7:0] d_pd;
reg  [7:0] q_s;      // stack pointer register
wire [7:0] d_s;
reg  [2:0] q_t;      // timing cycle register
reg  [2:0] d_t;

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
wire       s_adl;    // output s reg to adl bus

// ADH bus drive enables.
wire       dl_adh;   // output dl reg to adh bus
wire       pch_adh;  // output pch reg to adh bus

// DB bus drive enables.
wire       ac_db;    // output a reg to db bus
wire       dl_db;    // output dl reg to db bus

// SB bus drive enables.
wire       ac_sb;    // output ac reg to sb bus
wire       add_sb;   // output add reg to sb bus
wire       x_sb;     // output x reg to sb bus
wire       y_sb;     // output y reg to sb bus
wire       s_sb;     // output s reg to sb bus

// Pass MOSFET controls.
wire       sb_adh;   // controls sb/adh pass mosfet
wire       sb_db;    // controls sb/db pass mosfet

// Register LOAD controls.
wire       sb_ac;    // latch sb bus value in ac reg
wire       sb_x;     // latch sb bus value in x reg
wire       sb_y;     // latch sb bus value in y reg
wire       adh_abh;  // latch adh bus value in abh reg
wire       adl_abl;  // latch adl bus value in abl reg
wire       sb_add;   // latch sb bus value in ai reg
wire       zero_add; // latch 0 into ai reg
wire       db_add;   // latch db bus value in bi reg
wire       sb_s;     // latch sb bus value in s reg

// Misc. controls.
wire       i_pc;     // increment pc
wire       db7_n;    // latch db[7] into n status reg
wire       dbz_z;    // latch ~|db into z status reg

// ALU controls, signals.
wire       ands;     // perform bitwise and on alu
wire       ors;      // perform bitwise or on alu
wire       sums;     // perform addition on alu
reg        addc;     // carry in
reg        acr;      // carry out

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
        q_n    <= 1'b0;
        q_z    <= 1'b0;
        q_abh  <= 8'h80;
        q_abl  <= 8'h00;
        q_ai   <= 8'h00;
        q_bi   <= 8'h00;
        q_dor  <= 8'h00;
        q_ir   <= BRK;
        q_s    <= 8'hFF;
        q_t    <= T1;
      end
    else if (rdy && (q_clk_phase == 2'b00))
      begin
        q_ac   <= d_ac;
        q_x    <= d_x;
        q_y    <= d_y;
        q_n    <= d_n;
        q_z    <= d_z;
        q_abh  <= d_abh;
        q_abl  <= d_abl;
        q_ai   <= d_ai;
        q_bi   <= d_bi;
        q_dor  <= d_dor;
        q_ir   <= d_ir;
        q_s    <= d_s;
        q_t    <= d_t;
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
        q_acr <= 1'b0;
      end
    else if (rdy && (q_clk_phase == 2'b10))
      begin
        q_pcl <= d_pcl;
        q_pch <= d_pch;
        q_dl  <= d_dl;
        q_pd  <= d_pd;
        q_add <= d_add;
        q_acr <= acr;
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
      T1:
        begin
          // These instructions are able to prefetch the next opcode during their final cycle.
          if ((q_ir == BRK) || (q_ir == NOP) || (q_ir == TAX) || (q_ir == TAY) || (q_ir == TSX) ||
              (q_ir == TXA) || (q_ir == TXS) || (q_ir == TYA))
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
          // These instructions are able to prefetch the next opcode during their final cycle.
          if ((q_ir == AND_IMM) || (q_ir == ORA_IMM))
            d_t = T1;

          // These instructions are in their last cycle, but are using the data bus during the last
          // cycle (e.g., load/store) such that they can't prefetch.
          else if ((q_ir == STA_ZP) || (q_ir == STX_ZP) || (q_ir == STY_ZP) ||
                   (q_ir == LDA_ZP) || (q_ir == LDX_ZP) || (q_ir == LDY_ZP))
            d_t = T0;

          // For loads using relative absolute addressing modes, we can skip stage 3 if the result
          // doesn't cross a page boundary (i.e., don't need to add 1 to the high byte).
          else if (!acr && ((q_ir == AND_ABSX) || (q_ir == AND_ABSY) || (q_ir == LDA_ABSX) ||
                            (q_ir == LDA_ABSY) || (q_ir == ORA_ABSX) || (q_ir == ORA_ABSY)))
            d_t = T4;

          else
            d_t = T3;
        end
      T3:
        begin
          // These instructions are able to prefetch the next opcode during their final cycle.
          if ((q_ir == AND_ZP) || (q_ir == ORA_ZP))
            d_t = T1;

          // These instructions are in their last cycle, but are using the data bus during the last
          // cycle (e.g., load/store) such that they can't prefetch.
          else if ((q_ir == STA_ABS) || (q_ir == STX_ABS) || (q_ir == STY_ABS) ||
                   (q_ir == STA_ZPX) || (q_ir == STX_ZPY) || (q_ir == STY_ZPX) ||
                   (q_ir == LDA_ABS) || (q_ir == LDX_ABS) || (q_ir == LDY_ABS) ||
                   (q_ir == LDA_ZPX) || (q_ir == LDX_ZPY) || (q_ir == LDY_ZPX))
            d_t = T0;

          // For loads using (indirect),Y addressing modes, we can skip stage 4 if the result
          // doesn't cross a page boundary (i.e., don't need to add 1 to the high byte).
          else if (!acr && ((q_ir == AND_INDY) || (q_ir == LDA_INDY) || (q_ir == ORA_INDY)))
            d_t = T5;

          else
            d_t = T4;
        end
      T4:
        begin
          // These instructions are able to prefetch the next opcode during their final cycle.
          if ((q_ir == AND_ABS) || (q_ir == AND_ZPX) || (q_ir == ORA_ABS) || (q_ir == ORA_ZPX))
            d_t = T1;

          // These instructions are in their last cycle, but are using the data bus during the last
          // cycle (e.g., load/store) such that they can't prefetch.
          else if ((q_ir == LDA_ABSX) || (q_ir == LDA_ABSY) || (q_ir == LDX_ABSY) ||
                   (q_ir == LDY_ABSX) || (q_ir == STA_ABSX) || (q_ir == STA_ABSY))
            d_t = T0;

          else
            d_t = T5;
        end
      T5:
        begin
          // These instructions are able to prefetch the next opcode during their final cycle.
          if ((q_ir == AND_ABSX) || (q_ir == AND_ABSY) || (q_ir == ORA_ABSX) || (q_ir == ORA_ABSY))
            d_t = T1;
          
          // These instructions are in their last cycle, but are using the data bus during the last
          // cycle (e.g., load/store) such that they can't prefetch.
          else if ((q_ir == LDA_INDX) || (q_ir == LDA_INDY) ||
                   (q_ir == STA_INDX) || (q_ir == STA_INDY))
            d_t = T0;

          else
            d_t = T6;
        end
      T6:
        begin
          // These instructions are able to prefetch the next opcode during their final cycle.
          if ((q_ir == AND_INDX) || (q_ir == AND_INDY) || (q_ir == ORA_INDX) || (q_ir == ORA_INDY))
            d_t = T1;

          else
            d_t = T7;
        end
      T7:
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
reg load_prg_byte;       // put PC on addr bus, increment PC, and latch returned data
reg lda_last_cycle;      // final cycle of an lda inst
reg ldx_last_cycle;      // final cycle of an ldx inst
reg ldy_last_cycle;      // final cycle of an ldy inst
reg and_last_cycle;      // final cycle of an and inst
reg ora_last_cycle;      // final cycle of an ora inst
reg ac_to_dor;           // load current ac value into dor
reg x_to_dor;            // load current x value into dor
reg y_to_dor;            // load current y value into dor
reg zp_addr_to_ab;       // load ab with zero-page address specified in dl
reg zpidx_loaddr_to_ab;  // load abl with lo address for zp index ops, abh set to 0
reg xidx_comps_to_alu;   // load alu inputs ai/bi with vals for x indexed addr calc
reg yidx_comps_to_alu;   // load alu inputs ai/bi with vals for y indexed addr calc
reg dl_and_zero_to_alu;  // load bi with dl and ai with 0
reg dl_and_ac_to_alu;    // load bi with dl and ai with ac
reg abs_addr_to_ab;      // load an absolute address into the ab regs (dl to abh, add to abl)
reg idx_hiaddr_to_ab;    // load abh with indexed addressing result
reg tax;                 // transfer ac to x
reg tay;                 // transfer ac to y
reg tsx;                 // transfer s to x
reg txa;                 // transfer x to z
reg txs;                 // transfer x to s
reg tya;                 // transfer y to a

always @*
  begin
    // Default all control signals to 0.
    load_prg_byte       = 1'b0;
    lda_last_cycle      = 1'b0;
    ldx_last_cycle      = 1'b0;
    ldy_last_cycle      = 1'b0;
    and_last_cycle      = 1'b0;
    ora_last_cycle      = 1'b0;
    ac_to_dor           = 1'b0;
    x_to_dor            = 1'b0;
    y_to_dor            = 1'b0;
    zp_addr_to_ab       = 1'b0;
    zpidx_loaddr_to_ab  = 1'b0;
    xidx_comps_to_alu   = 1'b0;
    yidx_comps_to_alu   = 1'b0;
    dl_and_zero_to_alu  = 1'b0;
    dl_and_ac_to_alu    = 1'b0;
    abs_addr_to_ab      = 1'b0;
    idx_hiaddr_to_ab    = 1'b0;
    addc                = 1'b0;
    tax                 = 1'b0;
    tay                 = 1'b0;
    tsx                 = 1'b0;
    txa                 = 1'b0;
    txs                 = 1'b0;
    tya                 = 1'b0;

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
          AND_ABS, LDA_ABS, LDX_ABS, LDY_ABS, ORA_ABS, STA_ABS, STX_ABS, STY_ABS:
            begin
              load_prg_byte       = 1'b1;
              dl_and_zero_to_alu  = 1'b1;
            end
          AND_ABSX, LDA_ABSX, LDY_ABSX, ORA_ABSX, STA_ABSX:
            begin
              load_prg_byte     = 1'b1;
              xidx_comps_to_alu = 1'b1;
            end
          AND_ABSY, LDA_ABSY, LDX_ABSY, ORA_ABSY, STA_ABSY:
            begin
              load_prg_byte     = 1'b1;
              yidx_comps_to_alu = 1'b1;
            end
          AND_IMM, ORA_IMM:
            begin
              load_prg_byte    = 1'b1;
              dl_and_ac_to_alu = 1'b1;
            end
          AND_INDX, AND_ZPX, LDA_INDX, LDA_ZPX, LDY_ZPX, ORA_INDX, ORA_ZPX, STA_INDX, STA_ZPX,
          STY_ZPX:
            xidx_comps_to_alu = 1'b1;
          AND_INDY, LDA_INDY, ORA_INDY, STA_INDY:
            begin
              dl_and_zero_to_alu = 1'b1;
              zp_addr_to_ab      = 1'b1;
            end
          AND_ZP, LDA_ZP, LDX_ZP, LDY_ZP, ORA_ZP:
            zp_addr_to_ab = 1'b1;
          BRK:
            begin
              load_prg_byte = 1'b1;
              brk = (q_clk_phase == 2'b01) && rdy;
            end
          LDA_IMM:
            begin
              load_prg_byte  = 1'b1;
              lda_last_cycle = 1'b1;
            end
          LDX_IMM:
            begin
              load_prg_byte  = 1'b1;
              ldx_last_cycle = 1'b1;
            end
          LDX_ZPY, STX_ZPY:
            yidx_comps_to_alu = 1'b1;
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
          TAX:
            begin
              load_prg_byte = 1'b1;
              tax           = 1'b1;
            end
          TAY:
            begin
              load_prg_byte = 1'b1;
              tay           = 1'b1;
            end
          TSX:
            begin
              load_prg_byte = 1'b1;
              tsx           = 1'b1;
            end
          TXA:
            begin
              load_prg_byte = 1'b1;
              txa           = 1'b1;
            end
          TXS:
            begin
              load_prg_byte = 1'b1;
              txs           = 1'b1;
            end
          TYA:
            begin
              load_prg_byte = 1'b1;
              tya           = 1'b1;
            end
        endcase
      end
    else if (q_t == T2)
      begin
        case (q_ir)
          AND_ABS, LDA_ABS, LDX_ABS, LDY_ABS, ORA_ABS:
            abs_addr_to_ab = 1'b1;
          AND_ABSX, AND_ABSY, LDA_ABSX, LDA_ABSY, LDX_ABSY, LDY_ABSX, ORA_ABSX, ORA_ABSY,
          STA_ABSX, STA_ABSY:
            begin
              abs_addr_to_ab     = 1'b1;
              dl_and_zero_to_alu = 1'b1;
            end
          AND_IMM:
            begin
              load_prg_byte  = 1'b1;
              and_last_cycle = 1'b1;
            end
          AND_INDX, AND_ZPX, LDA_INDX, LDA_ZPX, LDX_ZPY, LDY_ZPX, ORA_INDX, ORA_ZPX, STA_INDX:
            zpidx_loaddr_to_ab = 1'b1;
          AND_INDY, LDA_INDY, ORA_INDY, STA_INDY:
            begin
              addc                = 1'b1;
              zpidx_loaddr_to_ab  = 1'b1;
              yidx_comps_to_alu   = 1'b1;
            end
          AND_ZP, ORA_ZP:
            begin
              load_prg_byte    = 1'b1;
              dl_and_ac_to_alu = 1'b1;
            end
          LDA_ZP:
            begin
              load_prg_byte  = 1'b1;
              lda_last_cycle = 1'b1;
            end
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
          ORA_IMM:
            begin
              load_prg_byte  = 1'b1;
              ora_last_cycle = 1'b1;
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
              zpidx_loaddr_to_ab = 1'b1;
              ac_to_dor        = 1'b1;
            end
          STX_ABS:
            begin
              abs_addr_to_ab = 1'b1;
              x_to_dor       = 1'b1;
            end
          STX_ZPY:
            begin
              zpidx_loaddr_to_ab = 1'b1;
              x_to_dor         = 1'b1;
            end
          STY_ABS:
            begin
              abs_addr_to_ab = 1'b1;
              y_to_dor       = 1'b1;
            end
          STY_ZPX:
            begin
              zpidx_loaddr_to_ab = 1'b1;
              y_to_dor         = 1'b1;
            end
        endcase
      end
    else if (q_t == T3)
      begin
        case (q_ir)
          AND_ABS, AND_ZPX, ORA_ABS, ORA_ZPX:
            begin
              load_prg_byte    = 1'b1;
              dl_and_ac_to_alu = 1'b1;
            end            
          AND_ABSX, AND_ABSY, LDA_ABSX, LDA_ABSY, LDX_ABSY, LDY_ABSX, ORA_ABSX, ORA_ABSY:
            begin
              addc             = q_acr;
              idx_hiaddr_to_ab = 1'b1;
            end
          AND_INDX, LDA_INDX, ORA_INDX, STA_INDX:
            begin
              addc               = 1'b1;
              zpidx_loaddr_to_ab = 1'b1;
              dl_and_zero_to_alu = 1'b1;
            end
          AND_INDY, LDA_INDY, ORA_INDY, STA_INDY:
            begin
              abs_addr_to_ab     = 1'b1;
              dl_and_zero_to_alu = 1'b1;
            end
          AND_ZP:
            begin
              load_prg_byte  = 1'b1;
              and_last_cycle = 1'b1;
            end
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
          ORA_ZP:
            begin
              load_prg_byte  = 1'b1;
              ora_last_cycle = 1'b1;
            end
          STA_ABS, STA_ZPX, STX_ABS, STX_ZPY, STY_ABS, STY_ZPX:
            begin
              load_prg_byte = 1'b1;
              r_nw          = 1'b0;
            end
          STA_ABSX, STA_ABSY:
            begin
              addc             = q_acr;
              idx_hiaddr_to_ab = 1'b1;
              ac_to_dor        = 1'b1;
            end
        endcase
      end
    else if (q_t == T4)
      begin
        case (q_ir)
          AND_ABS, AND_ZPX:
            begin
              load_prg_byte  = 1'b1;
              and_last_cycle = 1'b1;
            end
          AND_ABSX, AND_ABSY, ORA_ABSX, ORA_ABSY:
            begin
              load_prg_byte    = 1'b1;
              dl_and_ac_to_alu = 1'b1;
            end            
          AND_INDX, LDA_INDX, ORA_INDX:
            abs_addr_to_ab = 1'b1;
          AND_INDY, LDA_INDY, ORA_INDY:
            begin
              addc             = q_acr;
              idx_hiaddr_to_ab = 1'b1;
            end
          LDA_ABSX, LDA_ABSY:
            begin
              load_prg_byte  = 1'b1;
              lda_last_cycle = 1'b1;
            end
          LDX_ABSY:
            begin
              load_prg_byte  = 1'b1;
              ldx_last_cycle = 1'b1;
            end
          LDY_ABSX:
            begin
              load_prg_byte  = 1'b1;
              ldy_last_cycle = 1'b1;
            end
          ORA_ABS, ORA_ZPX:
            begin
              load_prg_byte  = 1'b1;
              ora_last_cycle = 1'b1;
            end
          STA_ABSX, STA_ABSY:
            begin
              load_prg_byte = 1'b1;
              r_nw          = 1'b0;
            end
          STA_INDX:
            begin
              abs_addr_to_ab = 1'b1;
              ac_to_dor      = 1'b1;
            end
          STA_INDY:
            begin
              addc             = q_acr;
              idx_hiaddr_to_ab = 1'b1;
              ac_to_dor        = 1'b1;
            end
        endcase
      end
    else if (q_t == T5)
      begin
        case (q_ir)
          AND_ABSX, AND_ABSY:
            begin
              load_prg_byte  = 1'b1;
              and_last_cycle = 1'b1;
            end
          AND_INDX, AND_INDY, ORA_INDX, ORA_INDY:
            begin
              load_prg_byte    = 1'b1;
              dl_and_ac_to_alu = 1'b1;
            end            
          LDA_INDX, LDA_INDY:
            begin
              load_prg_byte  = 1'b1;
              lda_last_cycle = 1'b1;
            end
          ORA_ABSX, ORA_ABSY:
            begin
              load_prg_byte  = 1'b1;
              ora_last_cycle = 1'b1;
            end
          STA_INDX, STA_INDY:
            begin
              load_prg_byte  = 1'b1;
              r_nw           = 1'b0;
            end
        endcase
      end
    else if (q_t == T6)
      begin
        case (q_ir)
          AND_INDX, AND_INDY:
            begin
              load_prg_byte  = 1'b1;
              and_last_cycle = 1'b1;
            end
          ORA_INDX, ORA_INDY:
            begin
              load_prg_byte  = 1'b1;
              ora_last_cycle = 1'b1;
            end
        endcase
      end
  end

//
// ALU
//
always @*
  begin
    acr = 1'b0;

    if (ands)
      d_add = q_ai & q_bi;
    else if (ors)
      d_add = q_ai | q_bi;
    else if (sums)
      { acr, d_add } = q_ai + q_bi + addc;
    else
      d_add = q_add;
  end

//
// Random Control Logic
//
assign add_adl  = zpidx_loaddr_to_ab  | abs_addr_to_ab;
assign dl_adl   = zp_addr_to_ab;
assign pcl_adl  = load_prg_byte;
assign s_adl    = 1'b0;
assign dl_adh   = abs_addr_to_ab;
assign pch_adh  = load_prg_byte;
assign ac_db    = ac_to_dor;
assign dl_db    = lda_last_cycle      | ldx_last_cycle      | ldy_last_cycle      |
                  xidx_comps_to_alu   | yidx_comps_to_alu   | dl_and_zero_to_alu  |
                  dl_and_ac_to_alu;
assign ac_sb    = dl_and_ac_to_alu    | tax                 | tay;
assign add_sb   = idx_hiaddr_to_ab    | and_last_cycle      | ora_last_cycle;
assign x_sb     = xidx_comps_to_alu   | x_to_dor            | txs                 |
                  txa;
assign y_sb     = yidx_comps_to_alu   | y_to_dor            | tya;
assign s_sb     = tsx;
assign sb_adh   = idx_hiaddr_to_ab;
assign sb_db    = lda_last_cycle      | ldx_last_cycle      | ldy_last_cycle      |
                  x_to_dor            | y_to_dor            | tax                 |
                  tay                 | tsx                 | txa                 |
                  tya                 | and_last_cycle      | ora_last_cycle;
assign adh_abh  = load_prg_byte       | zp_addr_to_ab       | zpidx_loaddr_to_ab  |
                  abs_addr_to_ab      | idx_hiaddr_to_ab;
assign adl_abl  = load_prg_byte       | zp_addr_to_ab       | zpidx_loaddr_to_ab  |
                  abs_addr_to_ab;
assign db_add   = xidx_comps_to_alu   | yidx_comps_to_alu   | dl_and_zero_to_alu  |
                  dl_and_ac_to_alu;
assign sb_s     = txs;
assign zero_add = dl_and_zero_to_alu;
assign sb_ac    = lda_last_cycle      | txa                 | tya                 |
                  and_last_cycle      | ora_last_cycle;
assign sb_add   = xidx_comps_to_alu   | yidx_comps_to_alu   | dl_and_ac_to_alu;
assign sb_x     = ldx_last_cycle      | tax                 | tsx;
assign sb_y     = ldy_last_cycle      | tay;
assign i_pc     = load_prg_byte;
assign db7_n    = lda_last_cycle      | ldx_last_cycle      | ldy_last_cycle      |
                  tax                 | tay                 | tsx                 |
                  txa                 | tya                 | and_last_cycle      |
                  ora_last_cycle;
assign dbz_z    = lda_last_cycle      | ldx_last_cycle      | ldy_last_cycle      |
                  tax                 | tay                 | tsx                 |
                  txa                 | tya                 | and_last_cycle      |
                  ora_last_cycle;
assign sums     = zpidx_loaddr_to_ab  | abs_addr_to_ab      | idx_hiaddr_to_ab;
assign ands     = and_last_cycle;
assign ors      = ora_last_cycle;

//
// Update internal buses.  Use of in/out to replicate pass mosfets and avoid using internal
// tristate buffers.
//
assign adh_in  = (dl_adh)  ? q_dl  :
                 (pch_adh) ? q_pch : 8'h00;
assign adl     = (add_adl) ? q_add :
                 (dl_adl)  ? q_dl  :
                 (pcl_adl) ? q_pcl :
                 (s_adl)   ? q_s   : 8'h00;
assign db_in   = (ac_db)   ? q_ac  :
                 (dl_db)   ? q_dl  : 8'h00;
assign sb_in   = (ac_sb)   ? q_ac  :
                 (add_sb)  ? q_add :
                 (x_sb)    ? q_x   :
                 (y_sb)    ? q_y   :
                 (s_sb)    ? q_s   : 8'h00;

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
assign d_ac             = (sb_ac)    ? sb_out                      : q_ac;
assign d_x              = (sb_x)     ? sb_out                      : q_x;
assign d_y              = (sb_y)     ? sb_out                      : q_y;
assign d_n              = (db7_n)    ? db_out[7]                   : q_n;
assign d_z              = (dbz_z)    ? ~|db_out                    : q_z;
assign d_abh            = (adh_abh)  ? adh_out                     : q_abh;
assign d_abl            = (adl_abl)  ? adl                         : q_abl;
assign d_ai             = (sb_add)   ? sb_out                      :
                          (zero_add) ? 8'h0                        : q_ai;
assign d_bi             = (db_add)   ? db_out                      : q_bi;
assign d_dl             = din;
assign d_dor            = db_out;
assign { d_pch, d_pcl } = (i_pc)     ? { q_pch, q_pcl } + 16'h0001 : { q_pch, q_pcl };
assign d_pd             = din;
assign d_s              = (sb_s)     ? sb_out                      : q_s;

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
      `REGSEL_AC:   dbgreg_out = q_ac;
      `REGSEL_X:    dbgreg_out = q_x;
      `REGSEL_Y:    dbgreg_out = q_y;
      `REGSEL_P:    dbgreg_out = p;
      `REGSEL_PCH:  dbgreg_out = q_pch;
      `REGSEL_PCL:  dbgreg_out = q_pcl;
      `REGSEL_S:    dbgreg_out = q_s;
      default:      dbgreg_out = 8'hBD;
    endcase
  end

endmodule

