///////////////////////////////////////////////////////////////////////////////////////////////////
// Module Name: cpu
//
// Author:      Brian Bennett (brian.k.bennett@gmail.com)
// Create Date: 08/29/2010
//
// Description:
//
// Cycle acurate 6502 CPU implementation, designed for use in an fpga-based NES emulator.
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
localparam [7:0] ADC_ABS  = 8'h6D, ADC_ABSX = 8'h7D, ADC_ABSY = 8'h79, ADC_IMM  = 8'h69,
                                   ADC_INDX = 8'h61, ADC_INDY = 8'h71, ADC_ZP   = 8'h65,
                                   ADC_ZPX  = 8'h75,
                 AND_ABS  = 8'h2D, AND_ABSX = 8'h3D, AND_ABSY = 8'h39, AND_IMM  = 8'h29,
                                   AND_INDX = 8'h21, AND_INDY = 8'h31, AND_ZP   = 8'h25,
                                   AND_ZPX  = 8'h35,
                 ASL_ABS  = 8'h0E, ASL_ABSX = 8'h1E, ASL_ACC  = 8'h0A, ASL_ZP   = 8'h06,
                                   ASL_ZPX  = 8'h16,
                 BIT_ABS  = 8'h2C, BIT_ZP   = 8'h24,
                 BRK      = 8'h00,
                 CLC      = 8'h18,
                 CLD      = 8'hD8,
                 CLI      = 8'h58,
                 CLV      = 8'hB8,
                 CMP_ABS  = 8'hCD, CMP_ABSX = 8'hDD, CMP_ABSY = 8'hD9, CMP_IMM  = 8'hC9,
                                   CMP_INDX = 8'hC1, CMP_INDY = 8'hD1, CMP_ZP   = 8'hC5,
                                   CMP_ZPX  = 8'hD5,
                 CPX_ABS  = 8'hEC, CPX_IMM  = 8'hE0, CPX_ZP   = 8'hE4,
                 CPY_ABS  = 8'hCC, CPY_IMM  = 8'hC0, CPY_ZP   = 8'hC4,
                 DEC_ABS  = 8'hCE, DEC_ABSX = 8'hDE, DEC_ZP   = 8'hC6, DEC_ZPX  = 8'hD6,
                 DEX      = 8'hCA,
                 DEY      = 8'h88,
                 EOR_ABS  = 8'h4D, EOR_ABSX = 8'h5D, EOR_ABSY = 8'h59, EOR_IMM  = 8'h49,
                                   EOR_INDX = 8'h41, EOR_INDY = 8'h51, EOR_ZP   = 8'h45,
                                   EOR_ZPX  = 8'h55,
                 INC_ABS  = 8'hEE, INC_ABSX = 8'hFE, INC_ZP   = 8'hE6, INC_ZPX  = 8'hF6,
                 INX      = 8'hE8,
                 INY      = 8'hC8,
                 LDA_ABS  = 8'hAD, LDA_ABSX = 8'hBD, LDA_ABSY = 8'hB9, LDA_IMM  = 8'hA9,
                                   LDA_INDX = 8'hA1, LDA_INDY = 8'hB1, LDA_ZP   = 8'hA5,
                                   LDA_ZPX  = 8'hB5,
                 LDX_ABS  = 8'hAE, LDX_ABSY = 8'hBE, LDX_IMM  = 8'hA2, LDX_ZP   = 8'hA6,
                                   LDX_ZPY  = 8'hB6,
                 LDY_ABS  = 8'hAC, LDY_ABSX = 8'hBC, LDY_IMM  = 8'hA0, LDY_ZP   = 8'hA4,
                                   LDY_ZPX  = 8'hB4,
                 LSR_ABS  = 8'h4E, LSR_ABSX = 8'h5E, LSR_ACC  = 8'h4A, LSR_ZP   = 8'h46,
                                   LSR_ZPX  = 8'h56,
                 NOP      = 8'hEA,
                 ORA_ABS  = 8'h0D, ORA_ABSX = 8'h1D, ORA_ABSY = 8'h19, ORA_IMM  = 8'h09,
                                   ORA_INDX = 8'h01, ORA_INDY = 8'h11, ORA_ZP   = 8'h05,
                                   ORA_ZPX  = 8'h15,
                 ROL_ABS  = 8'h2E, ROL_ABSX = 8'h3E, ROL_ACC  = 8'h2A, ROL_ZP   = 8'h26,
                                   ROL_ZPX  = 8'h36,
                 ROR_ABS  = 8'h6E, ROR_ABSX = 8'h7E, ROR_ACC  = 8'h6A, ROR_ZP   = 8'h66,
                                   ROR_ZPX  = 8'h76,
                 SBC_ABS  = 8'hED, SBC_ABSX = 8'hFD, SBC_ABSY = 8'hF9, SBC_IMM  = 8'hE9,
                                   SBC_INDX = 8'hE1, SBC_INDY = 8'hF1, SBC_ZP   = 8'hE5,
                                   SBC_ZPX  = 8'hF5,
                 SEC      = 8'h38,
                 SED      = 8'hF8,
                 SEI      = 8'h78,
                 STA_ABS  = 8'h8D, STA_ABSX = 8'h9D, STA_ABSY = 8'h99, STA_INDX = 8'h81,
                                   STA_INDY = 8'h91, STA_ZP   = 8'h85, STA_ZPX  = 8'h95,
                 STX_ABS  = 8'h8E, STX_ZP   = 8'h86, STX_ZPY  = 8'h96,
                 STY_ABS  = 8'h8C, STY_ZP   = 8'h84, STY_ZPX  = 8'h94,
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
                 T6  = 3'h6;

// User registers.
reg  [7:0] q_ac;     // accumulator register
wire [7:0] d_ac;
reg  [7:0] q_x;      // x index register
wire [7:0] d_x;
reg  [7:0] q_y;      // y index register
wire [7:0] d_y;

// Processor status register.
wire [7:0] p;        // full processor status reg, grouped from the following FFs
reg        q_c;      // carry flag
wire       d_c;
reg        q_d;      // decimal mode flag
wire       d_d;
reg        q_i;      // interrupt disable flag
wire       d_i;
reg        q_n;      // negative flag
wire       d_n;
reg        q_v;      // overflow flag
wire       d_v;
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
wire       add_adl;     // output adder hold register to adl bus
wire       dl_adl;      // output dl reg to adl bus
wire       pcl_adl;     // output pcl reg to adl bus
wire       s_adl;       // output s reg to adl bus

// ADH bus drive enables.
wire       dl_adh;      // output dl reg to adh bus
wire       pch_adh;     // output pch reg to adh bus
wire       zero_adh0;   // output 0 to bit 0 of adh bus
wire       zero_adh17;  // output 0 to bits 1-7 of adh bus

// DB bus drive enables.
wire       ac_db;       // output a reg to db bus
wire       dl_db;       // output dl reg to db bus

// SB bus drive enables.
wire       ac_sb;       // output ac reg to sb bus
wire       add_sb;      // output add reg to sb bus
wire       x_sb;        // output x reg to sb bus
wire       y_sb;        // output y reg to sb bus
wire       s_sb;        // output s reg to sb bus

// Pass MOSFET controls.
wire       sb_adh;      // controls sb/adh pass mosfet
wire       sb_db;       // controls sb/db pass mosfet

// Register LOAD controls.
wire       sb_ac;       // latch sb bus value in ac reg
wire       sb_x;        // latch sb bus value in x reg
wire       sb_y;        // latch sb bus value in y reg
wire       adh_abh;     // latch adh bus value in abh reg
wire       adl_abl;     // latch adl bus value in abl reg
wire       sb_add;      // latch sb bus value in ai reg
wire       zero_add;    // latch 0 into ai reg
wire       db_add;      // latch db bus value in bi reg
wire       invdb_add;   // latch ~db value in bi reg
wire       sb_s;        // latch sb bus value in s reg

// Processor status controls.
wire       acr_c;       // latch acr into c status reg
wire       ir5_c;       // latch IR[5] into c status reg
wire       ir5_d;       // latch IR[5] into d status reg
wire       ir5_i;       // latch IR[5] into i status reg
wire       db7_n;       // latch db[7] into n status reg
wire       avr_v;       // latch avr into v status reg
wire       db6_v;       // latch db[6] into v status reg
wire       zero_v;      // latch 0 into v status reg
wire       dbz_z;       // latch ~|db into z status reg

// Misc. controls.
wire       i_pc;        // increment pc

// ALU controls, signals.
wire       ands;        // perform bitwise and on alu
wire       eors;        // perform bitwise xor on alu
wire       ors;         // perform bitwise or on alu
wire       sums;        // perform addition on alu
wire       srs;         // perform right bitshift
wire       addc;        // carry in
reg        acr;         // carry out
reg        avr;         // overflow out

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
        q_c    <= 1'b0;
        q_d    <= 1'b0;
        q_i    <= 1'b0;
        q_n    <= 1'b0;
        q_v    <= 1'b0;
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
        q_c    <= d_c;
        q_d    <= d_d;
        q_i    <= d_i;
        q_n    <= d_n;
        q_v    <= d_v;
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
        // Update registers based on debug register write packets.
        if (dbgreg_wr)
          begin
            q_ac <= (dbgreg_sel == `REGSEL_AC) ? dbgreg_in    : q_ac;
            q_x  <= (dbgreg_sel == `REGSEL_X)  ? dbgreg_in    : q_x;
            q_y  <= (dbgreg_sel == `REGSEL_Y)  ? dbgreg_in    : q_y;
            q_c  <= (dbgreg_sel == `REGSEL_P)  ? dbgreg_in[0] : q_c;
            q_d  <= (dbgreg_sel == `REGSEL_P)  ? dbgreg_in[3] : q_d;
            q_i  <= (dbgreg_sel == `REGSEL_P)  ? dbgreg_in[2] : q_i;
            q_n  <= (dbgreg_sel == `REGSEL_P)  ? dbgreg_in[7] : q_n;
            q_v  <= (dbgreg_sel == `REGSEL_P)  ? dbgreg_in[6] : q_v;
            q_z  <= (dbgreg_sel == `REGSEL_P)  ? dbgreg_in[1] : q_z;

            // This handles a problem found when updating the PC during a BRK instruction.  Force
            // AB reg to update to the new PC value immediately so T0 of the next instruction
            // will fetch the correct op.
            q_abl <= ((d_t == T0) && (dbgreg_sel == `REGSEL_PCL)) ? dbgreg_in : q_abl;
            q_abh <= ((d_t == T0) && (dbgreg_sel == `REGSEL_PCH)) ? dbgreg_in : q_abh;
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
          // These instructions are in their last cycle but do not prefetch.
          if ((q_ir == BRK) || (q_ir == CLC)     || (q_ir == CLD)     || (q_ir == CLI)     ||
              (q_ir == CLV) || (q_ir == LDA_IMM) || (q_ir == LDX_IMM) || (q_ir == LDY_IMM) ||
              (q_ir == NOP) || (q_ir == SEC)     || (q_ir == SED)     || (q_ir == SEI)     ||
              (q_ir == TAX) || (q_ir == TAY)     || (q_ir == TSX)     || (q_ir == TXA)     ||
              (q_ir == TXS) || (q_ir == TYA))
            d_t = T0;

          else
            d_t = T2;
        end
      T2:
        begin
          // These instructions prefetch the next opcode during their final cycle.
          if ((q_ir == ADC_IMM) || (q_ir == AND_IMM) || (q_ir == ASL_ACC) || (q_ir == CMP_IMM) ||
              (q_ir == CPX_IMM) || (q_ir == CPY_IMM) || (q_ir == DEX)     || (q_ir == DEY)     ||
              (q_ir == EOR_IMM) || (q_ir == INX)     || (q_ir == INY)     || (q_ir == LSR_ACC) ||
              (q_ir == ORA_IMM) || (q_ir == ROL_ACC) || (q_ir == ROR_ACC) || (q_ir == SBC_IMM))
            d_t = T1;

          // These instructions are in their last cycle but do not prefetch.
          else if ((q_ir == LDA_ZP) || (q_ir == LDX_ZP) || (q_ir == LDY_ZP) ||
                   (q_ir == STA_ZP) || (q_ir == STX_ZP) || (q_ir == STY_ZP))
            d_t = T0;

          // For loads using relative absolute addressing modes, we can skip stage 3 if the result
          // doesn't cross a page boundary (i.e., don't need to add 1 to the high byte).
          else if (!acr && ((q_ir == ADC_ABSX) || (q_ir == ADC_ABSY) ||
                            (q_ir == AND_ABSX) || (q_ir == AND_ABSY) ||
                            (q_ir == CMP_ABSX) || (q_ir == CMP_ABSY) ||
                            (q_ir == EOR_ABSX) || (q_ir == EOR_ABSY) ||
                            (q_ir == LDA_ABSX) || (q_ir == LDA_ABSY) ||
                            (q_ir == ORA_ABSX) || (q_ir == ORA_ABSY) ||
                            (q_ir == SBC_ABSX) || (q_ir == SBC_ABSY)))
            d_t = T4;

          else
            d_t = T3;
        end
      T3:
        begin
          // These instructions prefetch the next opcode during their final cycle.
          if ((q_ir == ADC_ZP) || (q_ir == AND_ZP) || (q_ir == BIT_ZP) || (q_ir == CMP_ZP) ||
              (q_ir == CPX_ZP) || (q_ir == CPY_ZP) || (q_ir == EOR_ZP) || (q_ir == ORA_ZP) ||
              (q_ir == SBC_ZP))
            d_t = T1;

          // These instructions are in their last cycle but do not prefetch.
          else if ((q_ir == LDA_ABS) || (q_ir == LDA_ZPX) || (q_ir == LDX_ABS) ||
                   (q_ir == LDX_ZPY) || (q_ir == LDY_ABS) || (q_ir == LDY_ZPX) ||
                   (q_ir == STA_ABS) || (q_ir == STA_ZPX) || (q_ir == STX_ABS) ||
                   (q_ir == STX_ZPY) || (q_ir == STY_ABS) || (q_ir == STY_ZPX))
            d_t = T0;

          // For loads using (indirect),Y addressing modes, we can skip stage 4 if the result
          // doesn't cross a page boundary (i.e., don't need to add 1 to the high byte).
          else if (!acr && ((q_ir == ADC_INDY) || (q_ir == AND_INDY) || (q_ir == CMP_INDY) ||
                            (q_ir == EOR_INDY) || (q_ir == LDA_INDY) || (q_ir == ORA_INDY) ||
                            (q_ir == SBC_INDY)))
            d_t = T5;

          else
            d_t = T4;
        end
      T4:
        begin
          // These instructions prefetch the next opcode during their final cycle.
          if ((q_ir == ADC_ABS) || (q_ir == ADC_ZPX) || (q_ir == AND_ABS) || (q_ir == AND_ZPX) ||
              (q_ir == BIT_ABS) || (q_ir == CMP_ABS) || (q_ir == CMP_ZPX) || (q_ir == CPX_ABS) ||
              (q_ir == CPY_ABS) || (q_ir == EOR_ABS) || (q_ir == EOR_ZPX) || (q_ir == ORA_ABS) ||
              (q_ir == ORA_ZPX) || (q_ir == SBC_ABS) || (q_ir == SBC_ZPX))
            d_t = T1;

          // These instructions are in their last cycle but do not prefetch.
          else if ((q_ir == ASL_ZP)   || (q_ir == DEC_ZP)   || (q_ir == INC_ZP)   ||
                   (q_ir == LDA_ABSX) || (q_ir == LDA_ABSY) || (q_ir == LDX_ABSY) ||
                   (q_ir == LDY_ABSX) || (q_ir == LSR_ZP)   || (q_ir == ROL_ZP)   ||
                   (q_ir == ROR_ZP)   || (q_ir == STA_ABSX) || (q_ir == STA_ABSY))
            d_t = T0;

          else
            d_t = T5;
        end
      T5:
        begin
          // These instructions prefetch the next opcode during their final cycle.
          if ((q_ir == ADC_ABSX) || (q_ir == ADC_ABSY) || (q_ir == AND_ABSX) ||
              (q_ir == AND_ABSY) || (q_ir == CMP_ABSX) || (q_ir == CMP_ABSY) ||
              (q_ir == EOR_ABSX) || (q_ir == EOR_ABSY) || (q_ir == ORA_ABSX) ||
              (q_ir == ORA_ABSY) || (q_ir == SBC_ABSX) || (q_ir == SBC_ABSY))
            d_t = T1;

          // These instructions are in their last cycle but do not prefetch.
          else if ((q_ir == ASL_ABS)  || (q_ir == ASL_ZPX)  || (q_ir == DEC_ABS)  ||
                   (q_ir == DEC_ZPX)  || (q_ir == INC_ABS)  || (q_ir == INC_ZPX)  ||
                   (q_ir == LDA_INDX) || (q_ir == LDA_INDY) || (q_ir == LSR_ABS)  ||
                   (q_ir == LSR_ZPX)  || (q_ir == ROL_ABS)  || (q_ir == ROL_ZPX)  ||
                   (q_ir == ROR_ABS)  || (q_ir == ROR_ZPX)  || (q_ir == STA_INDX) ||
                   (q_ir == STA_INDY))
            d_t = T0;

          else
            d_t = T6;
        end
      T6:
        begin
          // These instructions prefetch the next opcode during their final cycle.
          if ((q_ir == ADC_INDX) || (q_ir == ADC_INDY) || (q_ir == AND_INDX) ||
              (q_ir == AND_INDY) || (q_ir == CMP_INDX) || (q_ir == CMP_INDY) ||
              (q_ir == EOR_INDX) || (q_ir == EOR_INDY) || (q_ir == ORA_INDX) ||
              (q_ir == ORA_INDY) || (q_ir == SBC_INDX) || (q_ir == SBC_INDY))
            d_t = T1;

          else
            d_t = T0;
        end
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
reg load_prg_byte;        // put PC on addr bus, increment PC, and latch returned data
reg adc_last_cycle;       // final cycle of an adc inst
reg and_last_cycle;       // final cycle of an and inst
reg cmp_last_cycle;       // final cycle of a cmp inst
reg bit_last_cycle;       // final cycle of a bit inst
reg dex_last_cycle;       // final cycle of a dex inst
reg dey_last_cycle;       // final cycle of a dey inst
reg eor_last_cycle;       // final cycle of an eor inst
reg inx_last_cycle;       // final cycle of an inx inst
reg iny_last_cycle;       // final cycle of an iny inst
reg lda_last_cycle;       // final cycle of an lda inst
reg ldx_last_cycle;       // final cycle of an ldx inst
reg ldy_last_cycle;       // final cycle of an ldy inst
reg ora_last_cycle;       // final cycle of an ora inst
reg ac_to_dor;            // load current ac value into dor
reg x_to_dor;             // load current x value into dor
reg y_to_dor;             // load current y value into dor
reg abs_addr_to_ab;       // load an absolute address into the ab regs (dl to abh, add to abl)
reg idx_hiaddr_to_ab;     // load abh with indexed addressing result
reg ind_loaddr_to_ab;     // load abl with indirect lo address
reg zp_addr_to_ab;        // load ab with zero-page address specified in dl
reg zpidx_loaddr_to_ab;   // load abl with lo address for zp index ops, abh set to 0
reg ac_and_ac_to_alu;     // load ai and bi with ac
reg dl_and_ac_to_alu;     // load bi with dl and ai with ac
reg dl_and_dl_to_alu;     // load ai and bi with dl
reg dl_and_neg1_to_alu;   // load bi with dl and ai with -1
reg dl_and_zero_to_alu;   // load bi with dl and ai with 0
reg invdl_and_ac_to_alu;  // load bi with ~dl and ai with ac
reg invdl_and_x_to_alu;   // load bi with ~dl and ai with x
reg invdl_and_y_to_alu;   // load bi with ~dl and ai with y
reg neg1_and_x_to_alu;    // load bi with all 1s and ai with x
reg neg1_and_y_to_alu;    // load bi with all 1s and ai with y
reg x_and_zero_to_alu;    // load bi with x and ai with 0
reg y_and_zero_to_alu;    // load bi with y and ai with 0
reg xidx_comps_to_alu;    // load alu inputs ai/bi with vals for x indexed addr calc
reg yidx_comps_to_alu;    // load alu inputs ai/bi with vals for y indexed addr calc
reg dl_bits67_to_p;       // latch bits 6 and 7 into P V and N bits.
reg asl_acc;              // perform asl_acc inst
reg asl_mem;              // perform meat of asl inst for memory addressing modes
reg dec_mem;              // perform meat of dec inst
reg inc_mem;              // perform meat of inc inst
reg lsr_acc;              // perform lsr_acc inst
reg lsr_mem;              // perform meat of lsr inst for memory addressing modes
reg rol_acc;              // perform rol_acc inst
reg rol_mem;              // perform meat of rol inst for memory addressing modes
reg ror_acc;              // perform ror_acc inst
reg ror_mem;              // perform meat of ror inst for memory addressing modes
reg clc;                  // clear carry bit
reg cld;                  // clear decimal mode bit
reg cli;                  // clear interrupt disable bit
reg clv;                  // clear overflow bit
reg sec;                  // set carry bit
reg sed;                  // set decimal mode bit
reg sei;                  // set interrupt disable bit
reg tax;                  // transfer ac to x
reg tay;                  // transfer ac to y
reg tsx;                  // transfer s to x
reg txa;                  // transfer x to z
reg txs;                  // transfer x to s
reg tya;                  // transfer y to a

always @*
  begin
    // Default all control signals to 0.
    load_prg_byte       = 1'b0;
    adc_last_cycle      = 1'b0;
    and_last_cycle      = 1'b0;
    bit_last_cycle      = 1'b0;
    cmp_last_cycle      = 1'b0;
    dex_last_cycle      = 1'b0;
    dey_last_cycle      = 1'b0;
    eor_last_cycle      = 1'b0;
    inx_last_cycle      = 1'b0;
    iny_last_cycle      = 1'b0;
    lda_last_cycle      = 1'b0;
    ldx_last_cycle      = 1'b0;
    ldy_last_cycle      = 1'b0;
    ora_last_cycle      = 1'b0;
    ac_to_dor           = 1'b0;
    x_to_dor            = 1'b0;
    y_to_dor            = 1'b0;
    abs_addr_to_ab      = 1'b0;
    idx_hiaddr_to_ab    = 1'b0;
    ind_loaddr_to_ab    = 1'b0;
    zp_addr_to_ab       = 1'b0;
    zpidx_loaddr_to_ab  = 1'b0;
    ac_and_ac_to_alu    = 1'b0;
    dl_and_ac_to_alu    = 1'b0;
    dl_and_dl_to_alu    = 1'b0;
    dl_and_neg1_to_alu  = 1'b0;
    dl_and_zero_to_alu  = 1'b0;
    invdl_and_ac_to_alu = 1'b0;
    invdl_and_x_to_alu  = 1'b0;
    invdl_and_y_to_alu  = 1'b0;
    neg1_and_x_to_alu   = 1'b0;
    neg1_and_y_to_alu   = 1'b0;
    x_and_zero_to_alu   = 1'b0;
    y_and_zero_to_alu   = 1'b0;
    xidx_comps_to_alu   = 1'b0;
    yidx_comps_to_alu   = 1'b0;
    dl_bits67_to_p      = 1'b0;
    asl_acc             = 1'b0;
    asl_mem             = 1'b0;
    inc_mem             = 1'b0;
    dec_mem             = 1'b0;
    lsr_acc             = 1'b0;
    lsr_mem             = 1'b0;
    rol_acc             = 1'b0;
    rol_mem             = 1'b0;
    ror_acc             = 1'b0;
    ror_mem             = 1'b0;
    clc                 = 1'b0;
    cld                 = 1'b0;
    cli                 = 1'b0;
    clv                 = 1'b0;
    sec                 = 1'b0;
    sed                 = 1'b0;
    sei                 = 1'b0;
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
          ADC_ABS, AND_ABS, ASL_ABS, BIT_ABS, CMP_ABS, CPX_ABS, CPY_ABS, DEC_ABS,
                   EOR_ABS, INC_ABS, LDA_ABS, LDX_ABS, LDY_ABS, LSR_ABS, ORA_ABS,
                   ROL_ABS, ROR_ABS, SBC_ABS, STA_ABS, STX_ABS, STY_ABS:
            begin
              load_prg_byte       = 1'b1;
              dl_and_zero_to_alu  = 1'b1;
            end
          ADC_ABSX, AND_ABSX, ASL_ABSX, CMP_ABSX, DEC_ABSX, EOR_ABSX, INC_ABSX, LDA_ABSX,
                    LDY_ABSX, LSR_ABSX, ORA_ABSX, ROL_ABSX, ROR_ABSX, SBC_ABSX, STA_ABSX:
            begin
              load_prg_byte     = 1'b1;
              xidx_comps_to_alu = 1'b1;
            end
          ADC_ABSY, AND_ABSY, CMP_ABSY, EOR_ABSY, LDA_ABSY, LDX_ABSY, ORA_ABSY, SBC_ABSY,
                    STA_ABSY:
            begin
              load_prg_byte     = 1'b1;
              yidx_comps_to_alu = 1'b1;
            end
          ADC_IMM, AND_IMM, EOR_IMM, ORA_IMM:
            begin
              load_prg_byte    = 1'b1;
              dl_and_ac_to_alu = 1'b1;
            end
          ADC_INDX, AND_INDX, CMP_INDX, EOR_INDX, LDA_INDX, ORA_INDX, SBC_INDX, STA_INDX,
          ADC_ZPX,  AND_ZPX,  ASL_ZPX,  CMP_ZPX,  DEC_ZPX,  EOR_ZPX,  INC_ZPX,  LDA_ZPX,
                    LDY_ZPX,  LSR_ZPX,  ORA_ZPX,  ROL_ZPX,  ROR_ZPX,  SBC_ZPX,  STA_ZPX,
                    STY_ZPX:
            xidx_comps_to_alu = 1'b1;
          ADC_INDY, AND_INDY, CMP_INDY, EOR_INDY, LDA_INDY, ORA_INDY, SBC_INDY, STA_INDY:
            begin
              dl_and_zero_to_alu = 1'b1;
              zp_addr_to_ab      = 1'b1;
            end
          ADC_ZP, AND_ZP, ASL_ZP, BIT_ZP, CMP_ZP, CPX_ZP, CPY_ZP, DEC_ZP,
                  EOR_ZP, INC_ZP, LDA_ZP, LDX_ZP, LDY_ZP, LSR_ZP, ORA_ZP,
                  ROL_ZP, ROR_ZP, SBC_ZP:
            zp_addr_to_ab = 1'b1;
          ASL_ACC, LSR_ACC, ROL_ACC, ROR_ACC:
            ac_and_ac_to_alu = 1'b1;
          BRK:
            brk = (q_clk_phase == 2'b01) && rdy;
          CLC:
            clc = 1'b1;
          CLD:
            cld = 1'b1;
          CLI:
            cli = 1'b1;
          CLV:
            clv = 1'b1;
          CMP_IMM, SBC_IMM:
            begin
              load_prg_byte       = 1'b1;
              invdl_and_ac_to_alu = 1'b1;
            end
          CPX_IMM:
            begin
              load_prg_byte      = 1'b1;
              invdl_and_x_to_alu = 1'b1;
            end
          CPY_IMM:
            begin
              load_prg_byte      = 1'b1;
              invdl_and_y_to_alu = 1'b1;
            end
          DEX:
            neg1_and_x_to_alu = 1'b1;
          DEY:
            neg1_and_y_to_alu = 1'b1;
          INX:
            x_and_zero_to_alu = 1'b1;
          INY:
            y_and_zero_to_alu = 1'b1;
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
          SEC:
            sec = 1'b1;
          SED:
            sed = 1'b1;
          SEI:
            sei = 1'b1;
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
            tax = 1'b1;
          TAY:
            tay = 1'b1;
          TSX:
            tsx = 1'b1;
          TXA:
            txa = 1'b1;
          TXS:
            txs = 1'b1;
          TYA:
            tya = 1'b1;
        endcase
      end
    else if (q_t == T2)
      begin
        case (q_ir)
          ADC_ABS, AND_ABS, ASL_ABS, BIT_ABS, CMP_ABS, CPX_ABS, CPY_ABS, DEC_ABS,
                   EOR_ABS, INC_ABS, LDA_ABS, LDX_ABS, LDY_ABS, LSR_ABS, ORA_ABS,
                   ROL_ABS, ROR_ABS, SBC_ABS:
            abs_addr_to_ab = 1'b1;
          ADC_ABSX, AND_ABSX, ASL_ABSX, CMP_ABSX, DEC_ABSX, EOR_ABSX, INC_ABSX, LDA_ABSX,
                    LDY_ABSX, LSR_ABSX, ORA_ABSX, ROL_ABSX, ROR_ABSX, SBC_ABSX, STA_ABSX,
          ADC_ABSY, AND_ABSY, CMP_ABSY, EOR_ABSY, LDA_ABSY, LDX_ABSY, ORA_ABSY, SBC_ABSY,
                    STA_ABSY:
            begin
              abs_addr_to_ab     = 1'b1;
              dl_and_zero_to_alu = 1'b1;
            end
          ADC_IMM, SBC_IMM:
            begin
              load_prg_byte  = 1'b1;
              adc_last_cycle = 1'b1;
            end
          ADC_INDX, AND_INDX, CMP_INDX, EOR_INDX, LDA_INDX, ORA_INDX, SBC_INDX, STA_INDX,
          ADC_ZPX,  AND_ZPX,  ASL_ZPX,  CMP_ZPX,  DEC_ZPX,  EOR_ZPX,  INC_ZPX,  LDA_ZPX,
                    LDY_ZPX,  LSR_ZPX,  ORA_ZPX,  ROL_ZPX,  ROR_ZPX,  SBC_ZPX,
          LDX_ZPY:
            zpidx_loaddr_to_ab = 1'b1;
          ADC_INDY, AND_INDY, CMP_INDY, EOR_INDY, LDA_INDY, ORA_INDY, SBC_INDY, STA_INDY:
            begin
              ind_loaddr_to_ab  = 1'b1;
              yidx_comps_to_alu = 1'b1;
            end
          ADC_ZP, AND_ZP, EOR_ZP, ORA_ZP:
            begin
              load_prg_byte    = 1'b1;
              dl_and_ac_to_alu = 1'b1;
            end
          AND_IMM:
            begin
              load_prg_byte  = 1'b1;
              and_last_cycle = 1'b1;
            end
          ASL_ACC:
            begin
              load_prg_byte = 1'b1;
              asl_acc       = 1'b1;
            end
          ASL_ZP, LSR_ZP, ROL_ZP, ROR_ZP:
            dl_and_dl_to_alu = 1'b1;
          BIT_ZP:
            begin
              load_prg_byte    = 1'b1;
              dl_and_ac_to_alu = 1'b1;
              dl_bits67_to_p   = 1'b1;
            end
          CMP_IMM, CPX_IMM, CPY_IMM:
            begin
              load_prg_byte  = 1'b1;
              cmp_last_cycle = 1'b1;
            end
          CMP_ZP, SBC_ZP:
            begin
              load_prg_byte       = 1'b1;
              invdl_and_ac_to_alu = 1'b1;
            end
          CPX_ZP:
            begin
              load_prg_byte      = 1'b1;
              invdl_and_x_to_alu = 1'b1;
            end
          CPY_ZP:
            begin
              load_prg_byte      = 1'b1;
              invdl_and_y_to_alu = 1'b1;
            end
          EOR_IMM:
            begin
              load_prg_byte  = 1'b1;
              eor_last_cycle = 1'b1;
            end
          DEC_ZP:
            dl_and_neg1_to_alu = 1'b1;
          DEX:
            begin
              load_prg_byte  = 1'b1;
              dex_last_cycle = 1'b1;
            end
          DEY:
            begin
              load_prg_byte  = 1'b1;
              dey_last_cycle = 1'b1;
            end
          INC_ZP:
            dl_and_zero_to_alu = 1'b1;
          INX:
            begin
              load_prg_byte  = 1'b1;
              inx_last_cycle = 1'b1;
            end
          INY:
            begin
              load_prg_byte  = 1'b1;
              iny_last_cycle = 1'b1;
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
          LSR_ACC:
            begin
              load_prg_byte = 1'b1;
              lsr_acc       = 1'b1;
            end
          ORA_IMM:
            begin
              load_prg_byte  = 1'b1;
              ora_last_cycle = 1'b1;
            end
          ROL_ACC:
            begin
              load_prg_byte = 1'b1;
              rol_acc       = 1'b1;
            end
          ROR_ACC:
            begin
              load_prg_byte = 1'b1;
              ror_acc       = 1'b1;
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
          ADC_ABS, AND_ABS, EOR_ABS, ORA_ABS,
          ADC_ZPX, AND_ZPX, EOR_ZPX, ORA_ZPX:
            begin
              load_prg_byte    = 1'b1;
              dl_and_ac_to_alu = 1'b1;
            end
          ADC_ABSX, AND_ABSX, ASL_ABSX, CMP_ABSX, DEC_ABSX, EOR_ABSX, INC_ABSX, LDA_ABSX,
                    LDY_ABSX, LSR_ABSX, ORA_ABSX, ROL_ABSX, ROR_ABSX, SBC_ABSX,
          ADC_ABSY, AND_ABSY, CMP_ABSY, EOR_ABSY, LDA_ABSY, LDX_ABSY, ORA_ABSY, SBC_ABSY:
            idx_hiaddr_to_ab = 1'b1;
          ADC_INDX, AND_INDX, CMP_INDX, EOR_INDX, LDA_INDX, ORA_INDX, STA_INDX, SBC_INDX:
            begin
              ind_loaddr_to_ab   = 1'b1;
              dl_and_zero_to_alu = 1'b1;
            end
          ADC_INDY, AND_INDY, CMP_INDY, EOR_INDY, LDA_INDY, ORA_INDY, SBC_INDY, STA_INDY:
            begin
              abs_addr_to_ab     = 1'b1;
              dl_and_zero_to_alu = 1'b1;
            end
          ADC_ZP, SBC_ZP:
            begin
              load_prg_byte  = 1'b1;
              adc_last_cycle = 1'b1;
            end
          AND_ZP:
            begin
              load_prg_byte  = 1'b1;
              and_last_cycle = 1'b1;
            end
          ASL_ZP:
            asl_mem = 1'b1;
          ASL_ABS, LSR_ABS, ROL_ABS, ROR_ABS,
          ASL_ZPX, LSR_ZPX, ROL_ZPX, ROR_ZPX:
            dl_and_dl_to_alu = 1'b1;
          BIT_ABS:
            begin
              load_prg_byte    = 1'b1;
              dl_and_ac_to_alu = 1'b1;
              dl_bits67_to_p   = 1'b1;
            end
          BIT_ZP:
            begin
              load_prg_byte  = 1'b1;
              bit_last_cycle = 1'b1;
            end
          CMP_ABS, SBC_ABS,
          CMP_ZPX, SBC_ZPX:
            begin
              load_prg_byte       = 1'b1;
              invdl_and_ac_to_alu = 1'b1;
            end
          CMP_ZP, CPX_ZP, CPY_ZP:
            begin
              load_prg_byte  = 1'b1;
              cmp_last_cycle = 1'b1;
            end
          CPX_ABS:
            begin
              load_prg_byte      = 1'b1;
              invdl_and_x_to_alu = 1'b1;
            end
          CPY_ABS:
            begin
              load_prg_byte      = 1'b1;
              invdl_and_y_to_alu = 1'b1;
            end
          DEC_ABS,
          DEC_ZPX:
            dl_and_neg1_to_alu = 1'b1;
          DEC_ZP:
            dec_mem = 1'b1;
          EOR_ZP:
            begin
              load_prg_byte  = 1'b1;
              eor_last_cycle = 1'b1;
            end
          INC_ABS,
          INC_ZPX:
            dl_and_zero_to_alu = 1'b1;
          INC_ZP:
            inc_mem = 1'b1;
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
          LSR_ZP:
            lsr_mem = 1'b1;
          ORA_ZP:
            begin
              load_prg_byte  = 1'b1;
              ora_last_cycle = 1'b1;
            end
          ROL_ZP:
            rol_mem = 1'b1;
          ROR_ZP:
            ror_mem = 1'b1;
          STA_ABS, STX_ABS, STY_ABS,
          STA_ZPX, STY_ZPX,
          STX_ZPY:
            begin
              load_prg_byte = 1'b1;
              r_nw          = 1'b0;
            end
          STA_ABSX,
          STA_ABSY:
            begin
              idx_hiaddr_to_ab = 1'b1;
              ac_to_dor        = 1'b1;
            end
        endcase
      end
    else if (q_t == T4)
      begin
        case (q_ir)
          ADC_ABS, SBC_ABS,
          ADC_ZPX, SBC_ZPX:
            begin
              load_prg_byte  = 1'b1;
              adc_last_cycle = 1'b1;
            end
          ADC_ABSX, AND_ABSX, EOR_ABSX, ORA_ABSX,
          ADC_ABSY, AND_ABSY, EOR_ABSY, ORA_ABSY:
            begin
              load_prg_byte    = 1'b1;
              dl_and_ac_to_alu = 1'b1;
            end
          ADC_INDX, AND_INDX, CMP_INDX, EOR_INDX, LDA_INDX, ORA_INDX, SBC_INDX:
            abs_addr_to_ab = 1'b1;
          ADC_INDY, AND_INDY, CMP_INDY, EOR_INDY, LDA_INDY, ORA_INDY, SBC_INDY:
            idx_hiaddr_to_ab = 1'b1;
          AND_ABS,
          AND_ZPX:
            begin
              load_prg_byte  = 1'b1;
              and_last_cycle = 1'b1;
            end
          ASL_ZP, DEC_ZP, INC_ZP, LSR_ZP, ROL_ZP, ROR_ZP,
          STA_ABSX,
          STA_ABSY:
            begin
              load_prg_byte = 1'b1;
              r_nw          = 1'b0;
            end
          ASL_ABS,
          ASL_ZPX:
            asl_mem = 1'b1;
          ASL_ABSX, LSR_ABSX, ROL_ABSX, ROR_ABSX:
            dl_and_dl_to_alu = 1'b1;
          BIT_ABS:
            begin
              load_prg_byte  = 1'b1;
              bit_last_cycle = 1'b1;
            end
          CMP_ABS, CPX_ABS, CPY_ABS,
          CMP_ZPX:
            begin
              load_prg_byte  = 1'b1;
              cmp_last_cycle = 1'b1;
            end
          CMP_ABSX, SBC_ABSX,
          CMP_ABSY, SBC_ABSY:
            begin
              load_prg_byte       = 1'b1;
              invdl_and_ac_to_alu = 1'b1;
            end
          DEC_ABS,
          DEC_ZPX:
            dec_mem = 1'b1;
          DEC_ABSX:
            dl_and_neg1_to_alu = 1'b1;
          EOR_ABS,
          EOR_ZPX:
            begin
              load_prg_byte  = 1'b1;
              eor_last_cycle = 1'b1;
            end
          INC_ABS,
          INC_ZPX:
            inc_mem = 1'b1;
          INC_ABSX:
            dl_and_zero_to_alu = 1'b1;
          LDA_ABSX,
          LDA_ABSY:
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
          LSR_ABS,
          LSR_ZPX:
            lsr_mem = 1'b1;
          ORA_ABS,
          ORA_ZPX:
            begin
              load_prg_byte  = 1'b1;
              ora_last_cycle = 1'b1;
            end
          ROL_ABS,
          ROL_ZPX:
            rol_mem = 1'b1;
          ROR_ABS,
          ROR_ZPX:
            ror_mem = 1'b1;
          STA_INDX:
            begin
              abs_addr_to_ab = 1'b1;
              ac_to_dor      = 1'b1;
            end
          STA_INDY:
            begin
              idx_hiaddr_to_ab = 1'b1;
              ac_to_dor        = 1'b1;
            end
        endcase
      end
    else if (q_t == T5)
      begin
        case (q_ir)
          ADC_ABSX, SBC_ABSX,
          ADC_ABSY, SBC_ABSY:
            begin
              load_prg_byte  = 1'b1;
              adc_last_cycle = 1'b1;
            end
          ADC_INDX, AND_INDX, EOR_INDX, ORA_INDX,
          ADC_INDY, AND_INDY, EOR_INDY, ORA_INDY:
            begin
              load_prg_byte    = 1'b1;
              dl_and_ac_to_alu = 1'b1;
            end
          AND_ABSX,
          AND_ABSY:
            begin
              load_prg_byte  = 1'b1;
              and_last_cycle = 1'b1;
            end
          ASL_ABS, DEC_ABS, INC_ABS, LSR_ABS, ROL_ABS, ROR_ABS,
          ASL_ZPX, DEC_ZPX, INC_ZPX, LSR_ZPX, ROL_ZPX, ROR_ZPX,
          STA_INDX,
          STA_INDY:
            begin
              load_prg_byte  = 1'b1;
              r_nw           = 1'b0;
            end
          ASL_ABSX:
            asl_mem = 1'b1;
          CMP_ABSX,
          CMP_ABSY:
            begin
              load_prg_byte  = 1'b1;
              cmp_last_cycle = 1'b1;
            end
          CMP_INDX, SBC_INDX,
          CMP_INDY, SBC_INDY:
            begin
              load_prg_byte       = 1'b1;
              invdl_and_ac_to_alu = 1'b1;
            end
          DEC_ABSX:
            dec_mem = 1'b1;
          EOR_ABSX,
          EOR_ABSY:
            begin
              load_prg_byte  = 1'b1;
              eor_last_cycle = 1'b1;
            end
          INC_ABSX:
            inc_mem = 1'b1;
          LDA_INDX,
          LDA_INDY:
            begin
              load_prg_byte  = 1'b1;
              lda_last_cycle = 1'b1;
            end
          LSR_ABSX:
            lsr_mem = 1'b1;
          ORA_ABSX,
          ORA_ABSY:
            begin
              load_prg_byte  = 1'b1;
              ora_last_cycle = 1'b1;
            end
          ROL_ABSX:
            rol_mem = 1'b1;
          ROR_ABSX:
            ror_mem = 1'b1;
        endcase
      end
    else if (q_t == T6)
      begin
        case (q_ir)
          ADC_INDX, SBC_INDX,
          ADC_INDY, SBC_INDY:
            begin
              load_prg_byte  = 1'b1;
              adc_last_cycle = 1'b1;
            end
          AND_INDX,
          AND_INDY:
            begin
              load_prg_byte  = 1'b1;
              and_last_cycle = 1'b1;
            end
          ASL_ABSX, DEC_ABSX, INC_ABSX, LSR_ABSX, ROL_ABSX, ROR_ABSX:
            begin
              load_prg_byte  = 1'b1;
              r_nw           = 1'b0;
            end
          CMP_INDX,
          CMP_INDY:
            begin
              load_prg_byte  = 1'b1;
              cmp_last_cycle = 1'b1;
            end
          EOR_INDX,
          EOR_INDY:
            begin
              load_prg_byte  = 1'b1;
              eor_last_cycle = 1'b1;
            end
          ORA_INDX,
          ORA_INDY:
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
    avr = 1'b0;

    if (ands)
      d_add = q_ai & q_bi;
    else if (eors)
      d_add = q_ai ^ q_bi;
    else if (ors)
      d_add = q_ai | q_bi;
    else if (sums)
      begin
        { acr, d_add } = q_ai + q_bi + addc;
        avr = ((q_ai[7] ^ q_bi[7]) ^ d_add[7]) ^ acr;
      end
    else if (srs)
      { d_add, acr } = { addc, q_bi };
    else
      d_add = q_add;
  end

//
// Random Control Logic
//
assign add_adl    = abs_addr_to_ab      | ind_loaddr_to_ab    | zpidx_loaddr_to_ab;
assign dl_adl     = zp_addr_to_ab;
assign pcl_adl    = load_prg_byte;
assign s_adl      = 1'b0;
assign dl_adh     = abs_addr_to_ab;
assign pch_adh    = load_prg_byte;
assign zero_adh0  = ind_loaddr_to_ab    | zp_addr_to_ab       | zpidx_loaddr_to_ab;
assign zero_adh17 = ind_loaddr_to_ab    | zp_addr_to_ab       | zpidx_loaddr_to_ab;
assign ac_db      = ac_and_ac_to_alu    | ac_to_dor;
assign dl_db      = dl_and_ac_to_alu    | dl_and_dl_to_alu    | dl_and_neg1_to_alu  |
                    dl_and_zero_to_alu  | invdl_and_ac_to_alu | invdl_and_x_to_alu  |
                    invdl_and_y_to_alu  | lda_last_cycle      | ldx_last_cycle      |
                    ldy_last_cycle      | xidx_comps_to_alu   | yidx_comps_to_alu;
assign ac_sb      = ac_and_ac_to_alu    | dl_and_ac_to_alu    | invdl_and_ac_to_alu |
                    tax                 | tay;
assign add_sb     = adc_last_cycle      | and_last_cycle      | asl_acc             |
                    asl_mem             | bit_last_cycle      | cmp_last_cycle      |
                    dec_mem             | dex_last_cycle      | dey_last_cycle      |
                    eor_last_cycle      | idx_hiaddr_to_ab    | inc_mem             |
                    inx_last_cycle      | iny_last_cycle      | lsr_acc             |
                    lsr_mem             | ora_last_cycle      | rol_acc             |
                    rol_mem             | ror_acc             | ror_mem;
assign x_sb       = invdl_and_x_to_alu  | neg1_and_x_to_alu   | txa                 |
                    txs                 | x_and_zero_to_alu   | x_to_dor            |
                    xidx_comps_to_alu;
assign y_sb       = invdl_and_y_to_alu  | neg1_and_y_to_alu   | tya                 |
                    y_and_zero_to_alu   | y_to_dor            | yidx_comps_to_alu;
assign s_sb       = tsx;
assign sb_adh     = idx_hiaddr_to_ab;
assign sb_db      = adc_last_cycle      | and_last_cycle      | asl_acc             |
                    asl_mem             | bit_last_cycle      | cmp_last_cycle      |
                    dec_mem             | dex_last_cycle      | dey_last_cycle      |
                    dl_and_dl_to_alu    | eor_last_cycle      | inc_mem             |
                    inx_last_cycle      | iny_last_cycle      | lda_last_cycle      |
                    ldx_last_cycle      | ldy_last_cycle      | lsr_acc             |
                    lsr_mem             | ora_last_cycle      | rol_acc             |
                    rol_mem             | ror_acc             | ror_mem             |
                    tax                 | tay                 | tsx                 |
                    txa                 | tya                 | x_and_zero_to_alu   |
                    x_to_dor            | y_and_zero_to_alu   | y_to_dor;
assign adh_abh    = abs_addr_to_ab      | idx_hiaddr_to_ab    | ind_loaddr_to_ab    |
                    load_prg_byte       | zp_addr_to_ab       | zpidx_loaddr_to_ab;
assign adl_abl    = abs_addr_to_ab      | ind_loaddr_to_ab    | load_prg_byte       |
                    zp_addr_to_ab       | zpidx_loaddr_to_ab;
assign db_add     = ac_and_ac_to_alu    | dl_and_ac_to_alu    | dl_and_dl_to_alu    |
                    dl_and_neg1_to_alu  | dl_and_zero_to_alu  | neg1_and_x_to_alu   |
                    neg1_and_y_to_alu   | x_and_zero_to_alu   | xidx_comps_to_alu   |
                    y_and_zero_to_alu   | yidx_comps_to_alu;
assign invdb_add  = invdl_and_ac_to_alu | invdl_and_x_to_alu  | invdl_and_y_to_alu;
assign sb_s       = txs;
assign zero_add   = dl_and_zero_to_alu  | x_and_zero_to_alu   | y_and_zero_to_alu;
assign sb_ac      = adc_last_cycle      | and_last_cycle      | asl_acc             |
                    eor_last_cycle      | lda_last_cycle      | lsr_acc             |
                    ora_last_cycle      | rol_acc             | ror_acc             |
                    txa                 | tya;
assign sb_add     = ac_and_ac_to_alu    | dl_and_ac_to_alu    | dl_and_dl_to_alu    |
                    dl_and_neg1_to_alu  | invdl_and_ac_to_alu | invdl_and_x_to_alu  |
                    invdl_and_y_to_alu  | neg1_and_x_to_alu   | neg1_and_y_to_alu   |
                    xidx_comps_to_alu   | yidx_comps_to_alu;
assign sb_x       = dex_last_cycle      | inx_last_cycle      | ldx_last_cycle      |
                    tax                 | tsx;
assign sb_y       = dey_last_cycle      | iny_last_cycle      | ldy_last_cycle      |
                    tay;
assign acr_c      = adc_last_cycle      | asl_acc             | asl_mem             |
                    cmp_last_cycle      | lsr_acc             | lsr_mem             |
                    rol_acc             | rol_mem             | ror_acc             |
                    ror_mem;
assign ir5_c      = clc                 | sec;
assign ir5_d      = cld                 | sed;
assign ir5_i      = cli                 | sei;
assign db7_n      = adc_last_cycle      | and_last_cycle      | asl_acc             |
                    asl_mem             | cmp_last_cycle      | dec_mem             |
                    dex_last_cycle      | dey_last_cycle      | dl_bits67_to_p      |
                    eor_last_cycle      | inc_mem             | inx_last_cycle      |
                    iny_last_cycle      | lda_last_cycle      | ldx_last_cycle      |
                    ldy_last_cycle      | lsr_acc             | lsr_mem             |
                    ora_last_cycle      | rol_acc             | rol_mem             |
                    ror_acc             | ror_mem             | tax                 |
                    tay                 | tsx                 | txa                 |
                    tya;
assign avr_v      = adc_last_cycle;
assign db6_v      = dl_bits67_to_p;
assign zero_v     = clv;
assign dbz_z      = adc_last_cycle      | and_last_cycle      | asl_acc             |
                    asl_mem             | bit_last_cycle      | cmp_last_cycle      |
                    dec_mem             | dex_last_cycle      | dey_last_cycle      |
                    eor_last_cycle      | inc_mem             | inx_last_cycle      |
                    iny_last_cycle      | lda_last_cycle      | ldx_last_cycle      |
                    ldy_last_cycle      | lsr_acc             | lsr_mem             |
                    ora_last_cycle      | rol_acc             | rol_mem             |
                    ror_acc             | ror_mem             | tax                 |
                    tay                 | tsx                 | txa                 |
                    tya;
assign i_pc       = load_prg_byte;
assign ands       = and_last_cycle      | bit_last_cycle;
assign eors       = eor_last_cycle;
assign ors        = ora_last_cycle;
assign sums       = abs_addr_to_ab      | adc_last_cycle      | asl_acc             |
                    asl_mem             | cmp_last_cycle      | dec_mem             |
                    dex_last_cycle      | dey_last_cycle      | idx_hiaddr_to_ab    |
                    inc_mem             | ind_loaddr_to_ab    | inx_last_cycle      |
                    iny_last_cycle      | rol_acc             | rol_mem             |
                    zpidx_loaddr_to_ab;
assign srs        = lsr_acc             | lsr_mem             | ror_acc             |
                    ror_mem;

assign addc       = (adc_last_cycle | rol_acc | rol_mem | ror_acc | ror_mem) ? q_c   :
                    (idx_hiaddr_to_ab)                                       ? q_acr :
                    cmp_last_cycle      | inc_mem             | ind_loaddr_to_ab    |
                    inx_last_cycle      | iny_last_cycle;

//
// Update internal buses.  Use of in/out to replicate pass mosfets and avoid using internal
// tristate buffers.
//
assign adh_in[7:1]  = (dl_adh)     ? q_dl[7:1]  :
                      (pch_adh)    ? q_pch[7:1] :
                      (zero_adh17) ? 7'h00      : 7'h7F;
assign adh_in[0]    = (dl_adh)     ? q_dl[0]    :
                      (pch_adh)    ? q_pch[0]   :
                      (zero_adh0)  ? 1'b0       : 1'b1;

assign adl     = (add_adl) ? q_add :
                 (dl_adl)  ? q_dl  :
                 (pcl_adl) ? q_pcl :
                 (s_adl)   ? q_s   : 8'hFF;
assign db_in   = (ac_db)   ? q_ac  :
                 (dl_db)   ? q_dl  : 8'hFF;
assign sb_in   = (ac_sb)   ? q_ac  :
                 (add_sb)  ? q_add :
                 (x_sb)    ? q_x   :
                 (y_sb)    ? q_y   :
                 (s_sb)    ? q_s   : 8'hFF;

assign adh_out = (sb_adh & sb_db) ? (adh_in & sb_in & db_in) :
                 (sb_adh)         ? (adh_in & sb_in)         :
                                    (adh_in);
assign db_out  = (sb_db & sb_adh) ? (db_in & sb_in & adh_in) :
                 (sb_db)          ? (db_in & sb_in)          :
                                    (db_in);
assign sb_out  = (sb_adh & sb_db) ? (sb_in & db_in & adh_in) :
                 (sb_db)          ? (sb_in & db_in)          :
                 (sb_adh)         ? (sb_in & adh_in)         :
                                    (sb_in);

//
// Assign next FF states.
//
assign d_ac             = (sb_ac)     ? sb_out                      : q_ac;
assign d_x              = (sb_x)      ? sb_out                      : q_x;
assign d_y              = (sb_y)      ? sb_out                      : q_y;
assign d_c              = (acr_c)     ? acr                         :
                          (ir5_c)     ? q_ir[5]                     : q_c;
assign d_d              = (ir5_d)     ? q_ir[5]                     : q_d;
assign d_i              = (ir5_i)     ? q_ir[5]                     : q_i;
assign d_n              = (db7_n)     ? db_out[7]                   : q_n;
assign d_v              = (avr_v)     ? avr                         :
                          (db6_v)     ? db_out[6]                   :
                          (zero_v)    ? 1'b0                        : q_v;
assign d_z              = (dbz_z)     ? ~|db_out                    : q_z;
assign d_abh            = (adh_abh)   ? adh_out                     : q_abh;
assign d_abl            = (adl_abl)   ? adl                         : q_abl;
assign d_ai             = (sb_add)    ? sb_out                      :
                          (zero_add)  ? 8'h0                        : q_ai;
assign d_bi             = (db_add)    ? db_out                      :
                          (invdb_add) ? ~db_out                     : q_bi;
assign d_dl             = din;
assign d_dor            = db_out;
assign { d_pch, d_pcl } = (i_pc)      ? { q_pch, q_pcl } + 16'h0001 : { q_pch, q_pcl };
assign d_pd             = din;
assign d_s              = (sb_s)      ? sb_out                      : q_s;

// Combine full processor status register.
assign p = { q_n, q_v, 2'b00, q_d, q_i, q_z, q_c };

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
      default:      dbgreg_out = 8'hxx;
    endcase
  end

endmodule

