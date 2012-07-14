/***************************************************************************************************
** fpga_nes/hw/src/cpu/cpu.v
*
*  Copyright (c) 2012, Brian Bennett
*  All rights reserved.
*
*  Redistribution and use in source and binary forms, with or without modification, are permitted
*  provided that the following conditions are met:
*
*  1. Redistributions of source code must retain the above copyright notice, this list of conditions
*     and the following disclaimer.
*  2. Redistributions in binary form must reproduce the above copyright notice, this list of
*     conditions and the following disclaimer in the documentation and/or other materials provided
*     with the distribution.
*
*  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
*  IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
*  FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
*  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
*  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
*  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
*  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
*  WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*
*  6502 core implementation.
***************************************************************************************************/

module cpu
(
  input  wire        clk_in,         // 100MHz system clock
  input  wire        rst_in,         // reset signal
  input  wire        ready_in,       // ready signal

  // Interrupt lines.
  input  wire        nnmi_in,        // /nmi interrupt signal (active low)
  input  wire        nres_in,        // /res interrupt signal (console reset, active low)
  input  wire        nirq_in,        // /irq intterupt signal (active low)

  // Memory bus.
  input  wire [ 7:0] d_in,           // data input bus
  output wire [ 7:0] d_out,          // data output bus
  output wire [15:0] a_out,          // address bus
  output reg         r_nw_out,       // R/!W signal

  // Debug support.
  input  wire [ 3:0] dbgreg_sel_in,  // dbg reg select
  input  wire [ 7:0] dbgreg_in,      // dbg reg write input
  input  wire        dbgreg_wr_in,   // dbg reg rd/wr select
  output reg  [ 7:0] dbgreg_out,     // dbg reg read output
  output reg         brk_out         // debug break signal
);

// dbgreg_sel defines. Selects register for read/write through the debugger block.
`define REGSEL_PCL 0
`define REGSEL_PCH 1
`define REGSEL_AC  2
`define REGSEL_X   3
`define REGSEL_Y   4
`define REGSEL_P   5
`define REGSEL_S   6

// Opcodes.
localparam [7:0] ADC_ABS   = 8'h6D, ADC_ABSX  = 8'h7D, ADC_ABSY  = 8'h79, ADC_IMM   = 8'h69,
                                    ADC_INDX  = 8'h61, ADC_INDY  = 8'h71, ADC_ZP    = 8'h65,
                                    ADC_ZPX   = 8'h75,
                 AND_ABS   = 8'h2D, AND_ABSX  = 8'h3D, AND_ABSY  = 8'h39, AND_IMM   = 8'h29,
                                    AND_INDX  = 8'h21, AND_INDY  = 8'h31, AND_ZP    = 8'h25,
                                    AND_ZPX   = 8'h35,
                 ASL_ABS   = 8'h0E, ASL_ABSX  = 8'h1E, ASL_ACC   = 8'h0A, ASL_ZP    = 8'h06,
                                    ASL_ZPX   = 8'h16,
                 BCC       = 8'h90,
                 BCS       = 8'hB0,
                 BEQ       = 8'hF0,
                 BIT_ABS   = 8'h2C, BIT_ZP    = 8'h24,
                 BMI       = 8'h30,
                 BNE       = 8'hD0,
                 BPL       = 8'h10,
                 BRK       = 8'h00,
                 BVC       = 8'h50,
                 BVS       = 8'h70,
                 CLC       = 8'h18,
                 CLD       = 8'hD8,
                 CLI       = 8'h58,
                 CLV       = 8'hB8,
                 CMP_ABS   = 8'hCD, CMP_ABSX  = 8'hDD, CMP_ABSY  = 8'hD9, CMP_IMM   = 8'hC9,
                                    CMP_INDX  = 8'hC1, CMP_INDY  = 8'hD1, CMP_ZP    = 8'hC5,
                                    CMP_ZPX   = 8'hD5,
                 CPX_ABS   = 8'hEC, CPX_IMM   = 8'hE0, CPX_ZP    = 8'hE4,
                 CPY_ABS   = 8'hCC, CPY_IMM   = 8'hC0, CPY_ZP    = 8'hC4,
                 DEC_ABS   = 8'hCE, DEC_ABSX  = 8'hDE, DEC_ZP    = 8'hC6, DEC_ZPX   = 8'hD6,
                 DEX       = 8'hCA,
                 DEY       = 8'h88,
                 EOR_ABS   = 8'h4D, EOR_ABSX  = 8'h5D, EOR_ABSY  = 8'h59, EOR_IMM   = 8'h49,
                                    EOR_INDX  = 8'h41, EOR_INDY  = 8'h51, EOR_ZP    = 8'h45,
                                    EOR_ZPX   = 8'h55,
                 HLT       = 8'h02,
                 INC_ABS   = 8'hEE, INC_ABSX  = 8'hFE, INC_ZP    = 8'hE6, INC_ZPX   = 8'hF6,
                 INX       = 8'hE8,
                 INY       = 8'hC8,
                 JMP_ABS   = 8'h4C, JMP_IND   = 8'h6C,
                 JSR       = 8'h20,
                 LDA_ABS   = 8'hAD, LDA_ABSX  = 8'hBD, LDA_ABSY  = 8'hB9, LDA_IMM   = 8'hA9,
                                    LDA_INDX  = 8'hA1, LDA_INDY  = 8'hB1, LDA_ZP    = 8'hA5,
                                    LDA_ZPX   = 8'hB5,
                 LDX_ABS   = 8'hAE, LDX_ABSY  = 8'hBE, LDX_IMM   = 8'hA2, LDX_ZP    = 8'hA6,
                                    LDX_ZPY   = 8'hB6,
                 LDY_ABS   = 8'hAC, LDY_ABSX  = 8'hBC, LDY_IMM   = 8'hA0, LDY_ZP    = 8'hA4,
                                    LDY_ZPX   = 8'hB4,
                 LSR_ABS   = 8'h4E, LSR_ABSX  = 8'h5E, LSR_ACC   = 8'h4A, LSR_ZP    = 8'h46,
                                    LSR_ZPX   = 8'h56,
                 NOP       = 8'hEA,
                 ORA_ABS   = 8'h0D, ORA_ABSX  = 8'h1D, ORA_ABSY  = 8'h19, ORA_IMM   = 8'h09,
                                    ORA_INDX  = 8'h01, ORA_INDY  = 8'h11, ORA_ZP    = 8'h05,
                                    ORA_ZPX   = 8'h15,
                 PHA       = 8'h48,
                 PHP       = 8'h08,
                 PLA       = 8'h68,
                 PLP       = 8'h28,
                 ROL_ABS   = 8'h2E, ROL_ABSX  = 8'h3E, ROL_ACC   = 8'h2A, ROL_ZP    = 8'h26,
                                    ROL_ZPX   = 8'h36,
                 ROR_ABS   = 8'h6E, ROR_ABSX  = 8'h7E, ROR_ACC   = 8'h6A, ROR_ZP    = 8'h66,
                                    ROR_ZPX   = 8'h76,
                 RTI       = 8'h40,
                 RTS       = 8'h60,
                 SAX_ABS   = 8'h8F, SAX_INDX  = 8'h83, SAX_ZP    = 8'h87, SAX_ZPY   = 8'h97,
                 SBC_ABS   = 8'hED, SBC_ABSX  = 8'hFD, SBC_ABSY  = 8'hF9, SBC_IMM   = 8'hE9,
                                    SBC_INDX  = 8'hE1, SBC_INDY  = 8'hF1, SBC_ZP    = 8'hE5,
                                    SBC_ZPX   = 8'hF5,
                 SEC       = 8'h38,
                 SED       = 8'hF8,
                 SEI       = 8'h78,
                 STA_ABS   = 8'h8D, STA_ABSX  = 8'h9D, STA_ABSY  = 8'h99, STA_INDX  = 8'h81,
                                    STA_INDY  = 8'h91, STA_ZP    = 8'h85, STA_ZPX   = 8'h95,
                 STX_ABS   = 8'h8E, STX_ZP    = 8'h86, STX_ZPY   = 8'h96,
                 STY_ABS   = 8'h8C, STY_ZP    = 8'h84, STY_ZPX   = 8'h94,
                 TAX       = 8'hAA,
                 TAY       = 8'hA8,
                 TSX       = 8'hBA,
                 TXA       = 8'h8A,
                 TXS       = 8'h9A,
                 TYA       = 8'h98;

// Macro to check if a value is a valid opcode.
`define IS_VALID_OPCODE(op) \
    (((op) == ADC_ABS ) || ((op) == ADC_ABSX) || ((op) == ADC_ABSY) || ((op) == ADC_IMM ) || \
     ((op) == ADC_INDX) || ((op) == ADC_INDY) || ((op) == ADC_ZP  ) || ((op) == ADC_ZPX ) || \
     ((op) == AND_ABS ) || ((op) == AND_ABSX) || ((op) == AND_ABSY) || ((op) == AND_IMM ) || \
     ((op) == AND_INDX) || ((op) == AND_INDY) || ((op) == AND_ZP  ) || ((op) == AND_ZPX ) || \
     ((op) == ASL_ABS ) || ((op) == ASL_ABSX) || ((op) == ASL_ACC ) || ((op) == ASL_ZP  ) || \
     ((op) == ASL_ZPX ) || ((op) == BCC     ) || ((op) == BCS     ) || ((op) == BEQ     ) || \
     ((op) == BIT_ABS ) || ((op) == BIT_ZP  ) || ((op) == BMI     ) || ((op) == BNE     ) || \
     ((op) == BPL     ) || ((op) == BRK     ) || ((op) == BVC     ) || ((op) == BVS     ) || \
     ((op) == CLC     ) || ((op) == CLD     ) || ((op) == CLI     ) || ((op) == CLV     ) || \
     ((op) == CMP_ABS ) || ((op) == CMP_ABSX) || ((op) == CMP_ABSY) || ((op) == CMP_IMM ) || \
     ((op) == CMP_INDX) || ((op) == CMP_INDY) || ((op) == CMP_ZP  ) || ((op) == CMP_ZPX ) || \
     ((op) == CPX_ABS ) || ((op) == CPX_IMM ) || ((op) == CPX_ZP  ) || ((op) == CPY_ABS ) || \
     ((op) == CPY_IMM ) || ((op) == CPY_ZP  ) || ((op) == DEC_ABS ) || ((op) == DEC_ABSX) || \
     ((op) == DEC_ZP  ) || ((op) == DEC_ZPX ) || ((op) == DEX     ) || ((op) == DEY     ) || \
     ((op) == EOR_ABS ) || ((op) == EOR_ABSX) || ((op) == EOR_ABSY) || ((op) == EOR_IMM ) || \
     ((op) == EOR_INDX) || ((op) == EOR_INDY) || ((op) == EOR_ZP  ) || ((op) == EOR_ZPX ) || \
     ((op) == HLT     ) || ((op) == INC_ABS ) || ((op) == INC_ABSX) || ((op) == INC_ZP  ) || \
     ((op) == INC_ZPX ) || ((op) == INX     ) || ((op) == INY     ) || ((op) == JMP_ABS ) || \
     ((op) == JMP_IND ) || ((op) == JSR     ) || ((op) == LDA_ABS ) || ((op) == LDA_ABSX) || \
     ((op) == LDA_ABSY) || ((op) == LDA_IMM ) || ((op) == LDA_INDX) || ((op) == LDA_INDY) || \
     ((op) == LDA_ZP  ) || ((op) == LDA_ZPX ) || ((op) == LDX_ABS ) || ((op) == LDX_ABSY) || \
     ((op) == LDX_IMM ) || ((op) == LDX_ZP  ) || ((op) == LDX_ZPY ) || ((op) == LDY_ABS ) || \
     ((op) == LDY_ABSX) || ((op) == LDY_IMM ) || ((op) == LDY_ZP  ) || ((op) == LDY_ZPX ) || \
     ((op) == LSR_ABS ) || ((op) == LSR_ABSX) || ((op) == LSR_ACC ) || ((op) == LSR_ZP  ) || \
     ((op) == LSR_ZPX ) || ((op) == NOP     ) || ((op) == ORA_ABS ) || ((op) == ORA_ABSX) || \
     ((op) == ORA_ABSY) || ((op) == ORA_IMM ) || ((op) == ORA_INDX) || ((op) == ORA_INDY) || \
     ((op) == ORA_ZP  ) || ((op) == ORA_ZPX ) || ((op) == PHA     ) || ((op) == PHP     ) || \
     ((op) == PLA     ) || ((op) == PLP     ) || ((op) == ROL_ABS ) || ((op) == ROL_ABSX) || \
     ((op) == ROL_ACC ) || ((op) == ROL_ZP  ) || ((op) == ROL_ZPX ) || ((op) == ROR_ABS ) || \
     ((op) == ROR_ABSX) || ((op) == ROR_ACC ) || ((op) == ROR_ZP  ) || ((op) == ROR_ZPX ) || \
     ((op) == RTI     ) || ((op) == RTS     ) || ((op) == SAX_ABS ) || ((op) == SAX_INDX) || \
     ((op) == SAX_ZP  ) || ((op) == SAX_ZPY ) || ((op) == SBC_ABS ) || ((op) == SBC_ABSX) || \
     ((op) == SBC_ABSY) || ((op) == SBC_IMM ) || ((op) == SBC_INDX) || ((op) == SBC_INDY) || \
     ((op) == SBC_ZP  ) || ((op) == SBC_ZPX ) || ((op) == SEC     ) || ((op) == SED     ) || \
     ((op) == SEI     ) || ((op) == STA_ABS ) || ((op) == STA_ABSX) || ((op) == STA_ABSY) || \
     ((op) == STA_INDX) || ((op) == STA_INDY) || ((op) == STA_ZP  ) || ((op) == STA_ZPX ) || \
     ((op) == STX_ABS ) || ((op) == STX_ZP  ) || ((op) == STX_ZPY ) || ((op) == STY_ABS ) || \
     ((op) == STY_ZP  ) || ((op) == STY_ZPX ) || ((op) == TAX     ) || ((op) == TAY     ) || \
     ((op) == TSX     ) || ((op) == TXA     ) || ((op) == TXS     ) || ((op) == TYA     ))

// Timing generation cycle states.
localparam [2:0] T0 = 3'h0,
                 T1 = 3'h1,
                 T2 = 3'h2,
                 T3 = 3'h3,
                 T4 = 3'h4,
                 T5 = 3'h5,
                 T6 = 3'h6;

// Interrupt types.
localparam [1:0] INTERRUPT_RST = 2'h0,
                 INTERRUPT_NMI = 2'h1,
                 INTERRUPT_IRQ = 2'h2,
                 INTERRUPT_BRK = 2'h3;

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
reg  [7:0] q_pchs;   // program counter high select register
wire [7:0] d_pchs;
reg  [7:0] q_pcls;   // program counter low select register
wire [7:0] d_pcls;
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
// Internal control signals.  These names are all taken directly from the original 6502 block
// diagram.
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
wire       ac_db;       // output ac reg to db bus
wire       dl_db;       // output dl reg to db bus
wire       p_db;        // output p reg to db bus
wire       pch_db;      // output pch reg to db bus
wire       pcl_db;      // output pcl reg to db bus

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
wire       adh_abh;     // latch adh bus value in abh reg
wire       adl_abl;     // latch adl bus value in abl reg
wire       sb_ac;       // latch sb bus value in ac reg
wire       adl_add;     // latch adl bus value in bi reg
wire       db_add;      // latch db bus value in bi reg
wire       invdb_add;   // latch ~db value in bi reg
wire       sb_add;      // latch sb bus value in ai reg
wire       zero_add;    // latch 0 into ai reg
wire       adh_pch;     // latch adh bus value in pch reg
wire       adl_pcl;     // latch adl bus value in pcl reg
wire       sb_s;        // latch sb bus value in s reg
wire       sb_x;        // latch sb bus value in x reg
wire       sb_y;        // latch sb bus value in y reg

// Processor status controls.
wire       acr_c;       // latch acr into c status reg
wire       db0_c;       // latch db[0] into c status reg
wire       ir5_c;       // latch ir[5] into c status reg
wire       db3_d;       // latch db[3] into d status reg
wire       ir5_d;       // latch ir[5] into d status reg
wire       db2_i;       // latch db[2] into i status reg
wire       ir5_i;       // latch ir[5] into i status reg
wire       db7_n;       // latch db[7] into n status reg
wire       avr_v;       // latch avr into v status reg
wire       db6_v;       // latch db[6] into v status reg
wire       zero_v;      // latch 0 into v status reg
wire       db1_z;       // latch db[1] into z status reg
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

always @(posedge clk_in)
  begin
    if (rst_in)
      q_ready <= 1'b0;
    else
      q_ready <= ready_in;
  end

assign rdy = ready_in && q_ready;

//
// Clock phase generation logic.
//
reg  [5:0] q_clk_phase;
wire [5:0] d_clk_phase;

always @(posedge clk_in)
  begin
    if (rst_in)
      q_clk_phase <= 6'h01;
    else if (rdy)
      q_clk_phase <= d_clk_phase;

    // If the debugger writes a PC register, this is a partial reset: the cycle is set to
    // T0, and the clock phase should be set to the beginning of the 4 clock cycle.
    else if (dbgreg_wr_in && ((dbgreg_sel_in == `REGSEL_PCH) || (dbgreg_sel_in == `REGSEL_PCL)))
      q_clk_phase <= 6'h01;
  end

assign d_clk_phase = (q_clk_phase == 6'h37) ? 6'h00 : q_clk_phase + 6'h01;

//
// Interrupt and Reset Control.
//
reg [1:0] q_irq_sel, d_irq_sel;  // interrupt selected for service

reg       q_rst;                 // rst interrupt needs to be serviced
wire      d_rst;
reg       q_nres;                // latch last nres input signal for falling edge detection
reg       q_nmi;                 // nmi interrupt needs to be serviced
wire      d_nmi;
reg       q_nnmi;                // latch last nnmi input signal for falling edge detection

reg       clear_rst;             // clear rst interrupt
reg       clear_nmi;             // clear nmi interrupt
reg       force_noinc_pc;        // override stage-0 PC increment

always @(posedge clk_in)
  begin
    if (rst_in)
      begin
        q_irq_sel <= INTERRUPT_RST;
        q_rst     <= 1'b0;
        q_nres    <= 1'b1;
        q_nmi     <= 1'b0;
        q_nnmi    <= 1'b1;
      end
    else if (q_clk_phase == 6'h00)
      begin
        q_irq_sel <= d_irq_sel;
        q_rst     <= d_rst;
        q_nres    <= nres_in;
        q_nmi     <= d_nmi;
        q_nnmi    <= nnmi_in;
      end
  end

assign d_rst = (clear_rst)          ? 1'b0 :
               (!nres_in && q_nres) ? 1'b1 :
               q_rst;
assign d_nmi = (clear_nmi)          ? 1'b0 :
               (!nnmi_in && q_nnmi) ? 1'b1 :
               q_nmi;

//
// Update phase-1 clocked registers.
//
always @(posedge clk_in)
  begin
    if (rst_in)
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
        q_acr  <= 1'b0;
        q_ai   <= 8'h00;
        q_bi   <= 8'h00;
        q_dor  <= 8'h00;
        q_ir   <= NOP;
        q_pchs <= 8'h80;
        q_pcls <= 8'h00;
        q_s    <= 8'hFF;
        q_t    <= T1;
      end
    else if (rdy && (q_clk_phase == 6'h00))
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
        q_acr  <= acr;
        q_ai   <= d_ai;
        q_bi   <= d_bi;
        q_dor  <= d_dor;
        q_ir   <= d_ir;
        q_pchs <= d_pchs;
        q_pcls <= d_pcls;
        q_s    <= d_s;
        q_t    <= d_t;
      end
    else if (!rdy)
      begin
        // Update registers based on debug register write packets.
        if (dbgreg_wr_in)
          begin
            q_ac   <= (dbgreg_sel_in == `REGSEL_AC)  ? dbgreg_in    : q_ac;
            q_x    <= (dbgreg_sel_in == `REGSEL_X)   ? dbgreg_in    : q_x;
            q_y    <= (dbgreg_sel_in == `REGSEL_Y)   ? dbgreg_in    : q_y;
            q_c    <= (dbgreg_sel_in == `REGSEL_P)   ? dbgreg_in[0] : q_c;
            q_d    <= (dbgreg_sel_in == `REGSEL_P)   ? dbgreg_in[3] : q_d;
            q_i    <= (dbgreg_sel_in == `REGSEL_P)   ? dbgreg_in[2] : q_i;
            q_n    <= (dbgreg_sel_in == `REGSEL_P)   ? dbgreg_in[7] : q_n;
            q_v    <= (dbgreg_sel_in == `REGSEL_P)   ? dbgreg_in[6] : q_v;
            q_z    <= (dbgreg_sel_in == `REGSEL_P)   ? dbgreg_in[1] : q_z;

            // Treat the debugger writing PC registers as a partial reset.  Set the cycle to T0,
            // and setup the address bus so the first opcode fill be fetched as soon as rdy is
            // asserted again.
            q_pchs <= (dbgreg_sel_in == `REGSEL_PCH) ? dbgreg_in : q_pchs;
            q_pcls <= (dbgreg_sel_in == `REGSEL_PCL) ? dbgreg_in : q_pcls;
            q_abh  <= (dbgreg_sel_in == `REGSEL_PCH) ? dbgreg_in : q_abh;
            q_abl  <= (dbgreg_sel_in == `REGSEL_PCL) ? dbgreg_in : q_abl;
            q_t    <= ((dbgreg_sel_in == `REGSEL_PCH) || (dbgreg_sel_in == `REGSEL_PCL)) ? T0 : q_t;
          end
      end
  end

//
// Update phase-2 clocked registers.
//
always @(posedge clk_in)
  begin
    if (rst_in)
      begin
        q_pcl <= 8'h00;
        q_pch <= 8'h80;
        q_dl  <= 8'h00;
        q_pd  <= 8'h00;
        q_add <= 8'h00;
      end
    else if (rdy && (q_clk_phase == 6'h1C))
      begin
        q_pcl <= d_pcl;
        q_pch <= d_pch;
        q_dl  <= d_dl;
        q_pd  <= d_pd;
        q_add <= d_add;
      end
    else if (!rdy && dbgreg_wr_in)
      begin
        // Update registers based on debug register write packets.
        q_pcl <= (dbgreg_sel_in == `REGSEL_PCL) ? dbgreg_in : q_pcl;
        q_pch <= (dbgreg_sel_in == `REGSEL_PCH) ? dbgreg_in : q_pch;
      end
  end

//
// Timing Generation Logic
//
always @*
  begin
    d_t            = T0;
    d_irq_sel      = q_irq_sel;
    force_noinc_pc = 1'b0;

    case (q_t)
      T0:
        d_t = T1;
      T1:
        begin
          // These instructions are in their last cycle but do not prefetch.
          if ((q_ir == CLC) || (q_ir == CLD)     || (q_ir == CLI)     || (q_ir == CLV)     ||
              (q_ir == HLT) || (q_ir == LDA_IMM) || (q_ir == LDX_IMM) || (q_ir == LDY_IMM) ||
              (q_ir == NOP) || (q_ir == SEC)     || (q_ir == SED)     || (q_ir == SEI)     ||
              (q_ir == TAX) || (q_ir == TAY)     || (q_ir == TSX)     || (q_ir == TXA)     ||
              (q_ir == TXS) || (q_ir == TYA))
            begin
              d_t = T0;
            end

          // Check for not-taken branches.  These instructions must setup the not-taken PC during
          // T1, and we can move to T0 of the next instruction.
          else if (((q_ir == BCC) && q_c) || ((q_ir == BCS) && !q_c) ||
                   ((q_ir == BPL) && q_n) || ((q_ir == BMI) && !q_n) ||
                   ((q_ir == BVC) && q_v) || ((q_ir == BVS) && !q_v) ||
                   ((q_ir == BNE) && q_z) || ((q_ir == BEQ) && !q_z))
            begin
              d_t = T0;
            end

          else
            begin
              d_t = T2;
            end
        end
      T2:
        begin
          // These instructions prefetch the next opcode during their final cycle.
          if ((q_ir == ADC_IMM) || (q_ir == AND_IMM) || (q_ir == ASL_ACC) || (q_ir == CMP_IMM) ||
              (q_ir == CPX_IMM) || (q_ir == CPY_IMM) || (q_ir == DEX)     || (q_ir == DEY)     ||
              (q_ir == EOR_IMM) || (q_ir == INX)     || (q_ir == INY)     || (q_ir == LSR_ACC) ||
              (q_ir == ORA_IMM) || (q_ir == ROL_ACC) || (q_ir == ROR_ACC) || (q_ir == SBC_IMM))
            begin
              d_t = T1;
            end

          // These instructions are in their last cycle but do not prefetch.
          else if ((q_ir == JMP_ABS) || (q_ir == LDA_ZP) || (q_ir == LDX_ZP) || (q_ir == LDY_ZP) ||
                   (q_ir == SAX_ZP)  || (q_ir == STA_ZP) || (q_ir == STX_ZP) || (q_ir == STY_ZP))
            begin
              d_t = T0;
            end

          // For ops using relative absolute addressing modes, we can skip stage 3 if the result
          // doesn't cross a page boundary (i.e., don't need to add 1 to the high byte).
          else if (!acr && ((q_ir == ADC_ABSX) || (q_ir == ADC_ABSY) || (q_ir == AND_ABSX) ||
                            (q_ir == AND_ABSY) || (q_ir == CMP_ABSX) || (q_ir == CMP_ABSY) ||
                            (q_ir == EOR_ABSX) || (q_ir == EOR_ABSY) || (q_ir == LDA_ABSX) ||
                            (q_ir == LDA_ABSY) || (q_ir == ORA_ABSX) || (q_ir == ORA_ABSY) ||
                            (q_ir == SBC_ABSX) || (q_ir == SBC_ABSY)))
            begin
              d_t = T4;
            end

          // For relative addressing ops (branches), we can skip stage 3 if the new PC doesn't
          // cross a page boundary (forward or backward).
          else if ((acr == q_ai[7]) && ((q_ir == BCC) || (q_ir == BCS) || (q_ir == BEQ) ||
                                        (q_ir == BMI) || (q_ir == BNE) || (q_ir == BPL) ||
                                        (q_ir == BVC) || (q_ir == BVS)))
            begin
              d_t = T0;
            end

          else
            begin
              d_t = T3;
            end
        end
      T3:
        begin
          // These instructions prefetch the next opcode during their final cycle.
          if ((q_ir == ADC_ZP) || (q_ir == AND_ZP) || (q_ir == BIT_ZP) || (q_ir == CMP_ZP) ||
              (q_ir == CPX_ZP) || (q_ir == CPY_ZP) || (q_ir == EOR_ZP) || (q_ir == ORA_ZP) ||
              (q_ir == PHA)    || (q_ir == PHP)    || (q_ir == SBC_ZP))
            begin
              d_t = T1;
            end

          // These instructions are in their last cycle but do not prefetch.
          else if ((q_ir == BCC)     || (q_ir == BCS)     || (q_ir == BEQ)     ||
                   (q_ir == BMI)     || (q_ir == BNE)     || (q_ir == BPL)     ||
                   (q_ir == BVC)     || (q_ir == BVS)     || (q_ir == LDA_ABS) ||
                   (q_ir == LDA_ZPX) || (q_ir == LDX_ABS) || (q_ir == LDX_ZPY) ||
                   (q_ir == LDY_ABS) || (q_ir == LDY_ZPX) || (q_ir == PLA)     ||
                   (q_ir == PLP)     || (q_ir == SAX_ABS) || (q_ir == SAX_ZPY) ||
                   (q_ir == STA_ABS) || (q_ir == STA_ZPX) || (q_ir == STX_ABS) ||
                   (q_ir == STX_ZPY) || (q_ir == STY_ABS) || (q_ir == STY_ZPX))
            begin
              d_t = T0;
            end

          // For loads using (indirect),Y addressing modes, we can skip stage 4 if the result
          // doesn't cross a page boundary (i.e., don't need to add 1 to the high byte).
          else if (!acr && ((q_ir == ADC_INDY) || (q_ir == AND_INDY) || (q_ir == CMP_INDY) ||
                            (q_ir == EOR_INDY) || (q_ir == LDA_INDY) ||
                            (q_ir == ORA_INDY) || (q_ir == SBC_INDY)))
            begin
              d_t = T5;
            end

          else
            begin
              d_t = T4;
            end
        end
      T4:
        begin
          // These instructions prefetch the next opcode during their final cycle.
          if ((q_ir == ADC_ABS) || (q_ir == ADC_ZPX) || (q_ir == AND_ABS) || (q_ir == AND_ZPX) ||
              (q_ir == BIT_ABS) || (q_ir == CMP_ABS) || (q_ir == CMP_ZPX) || (q_ir == CPX_ABS) ||
              (q_ir == CPY_ABS) || (q_ir == EOR_ABS) || (q_ir == EOR_ZPX) || (q_ir == ORA_ABS) ||
              (q_ir == ORA_ZPX) || (q_ir == SBC_ABS) || (q_ir == SBC_ZPX))
            begin
              d_t = T1;
            end

          // These instructions are in their last cycle but do not prefetch.
          else if ((q_ir == ASL_ZP)   || (q_ir == DEC_ZP)   || (q_ir == INC_ZP)   ||
                   (q_ir == JMP_IND)  || (q_ir == LDA_ABSX) || (q_ir == LDA_ABSY) ||
                   (q_ir == LDX_ABSY) || (q_ir == LDY_ABSX) || (q_ir == LSR_ZP)   ||
                   (q_ir == ROL_ZP)   || (q_ir == ROR_ZP)   || (q_ir == STA_ABSX) ||
                   (q_ir == STA_ABSY))
            begin
              d_t = T0;
            end

          else
            begin
              d_t = T5;
            end
        end
      T5:
        begin
          // These instructions prefetch the next opcode during their final cycle.
          if ((q_ir == ADC_ABSX) || (q_ir == ADC_ABSY) || (q_ir == AND_ABSX) ||
              (q_ir == AND_ABSY) || (q_ir == CMP_ABSX) || (q_ir == CMP_ABSY) ||
              (q_ir == EOR_ABSX) || (q_ir == EOR_ABSY) || (q_ir == ORA_ABSX) ||
              (q_ir == ORA_ABSY) || (q_ir == SBC_ABSX) || (q_ir == SBC_ABSY))
            begin
              d_t = T1;
            end

          // These instructions are in their last cycle but do not prefetch.
          else if ((q_ir == ASL_ABS)  || (q_ir == ASL_ZPX)  || (q_ir == DEC_ABS)  ||
                   (q_ir == DEC_ZPX)  || (q_ir == INC_ABS)  || (q_ir == INC_ZPX)  ||
                   (q_ir == JSR)      || (q_ir == LDA_INDX) || (q_ir == LDA_INDY) ||
                   (q_ir == LSR_ABS)  || (q_ir == LSR_ZPX)  || (q_ir == ROL_ABS)  ||
                   (q_ir == ROL_ZPX)  || (q_ir == ROR_ABS)  || (q_ir == ROR_ZPX)  ||
                   (q_ir == RTI)      || (q_ir == RTS)      || (q_ir == SAX_INDX) ||
                   (q_ir == STA_INDX) || (q_ir == STA_INDY))
            begin
              d_t = T0;
            end

          else
            begin
              d_t = T6;
            end
        end
      T6:
        begin
          // These instructions prefetch the next opcode during their final cycle.
          if ((q_ir == ADC_INDX) || (q_ir == ADC_INDY) || (q_ir == AND_INDX) ||
              (q_ir == AND_INDY) || (q_ir == CMP_INDX) || (q_ir == CMP_INDY) ||
              (q_ir == EOR_INDX) || (q_ir == EOR_INDY) || (q_ir == ORA_INDX) ||
              (q_ir == ORA_INDY) || (q_ir == SBC_INDX) || (q_ir == SBC_INDY))
            begin
              d_t = T1;
            end

          else
            begin
              d_t = T0;
            end
        end
    endcase

    // Update IR register on cycle 1, otherwise retain current IR.
    if (d_t == T1)
      begin
        if (q_rst || q_nmi || !nirq_in)
          begin
            d_ir           = BRK;
            force_noinc_pc = 1'b1;

            if (q_rst)
              d_irq_sel = INTERRUPT_RST;
            else if (q_nmi)
              d_irq_sel = INTERRUPT_NMI;
            else
              d_irq_sel = INTERRUPT_IRQ;
          end
        else
          begin
            d_ir      = q_pd;
            d_irq_sel = INTERRUPT_BRK;
          end
      end
    else
      begin
        d_ir = q_ir;
      end
  end

//
// Decode ROM output signals.  Corresponds to 130 bit bus coming out of the Decode ROM in the
// block diagram, although the details of implementation will differ.
//

// PC and program stream controls.
reg load_prg_byte;         // put PC on addr bus and increment PC (adh, adl)
reg load_prg_byte_noinc;   // put PC on addr bus only (adh, adl)
reg incpc_noload;          // increment PC only (-)
reg alusum_to_pch;         // load pch with ai+bi (adh, sb)
reg dl_to_pch;             // load pch with current data latch register (adh)
reg alusum_to_pcl;         // load pcl with ai+bi (adl)
reg s_to_pcl;              // load pcl with s (adl)

// Instruction-specific controls.  Typically triggers the meat of a particular operation that
// occurs regardless of addressing mode.
reg adc_op;                // final cycle of an adc inst (db, sb)
reg and_op;                // final cycle of an and inst (db, sb)
reg asl_acc_op;            // perform asl_acc inst (db, sb)
reg asl_mem_op;            // perform meat of asl inst for memory addressing modes (db, sb)
reg bit_op;                // final cycle of a bit inst (db, sb)
reg cmp_op;                // final cycle of a cmp inst (db, sb)
reg clc_op;                // clear carry bit (-)
reg cld_op;                // clear decimal mode bit (-)
reg cli_op;                // clear interrupt disable bit (-)
reg clv_op;                // clear overflow bit (-)
reg dec_op;                // perform meat of dec inst (db, sb)
reg dex_op;                // final cycle of a dex inst (db, sb)
reg dey_op;                // final cycle of a dey inst (db, sb)
reg eor_op;                // final cycle of an eor inst (db, sb)
reg inc_op;                // perform meat of inc inst (db, sb)
reg inx_op;                // final cycle of an inx inst (db, sb)
reg iny_op;                // final cycle of an iny inst (db, sb)
reg lda_op;                // final cycle of an lda inst (db, sb)
reg ldx_op;                // final cycle of an ldx inst (db, sb)
reg ldy_op;                // final cycle of an ldy inst (db, sb)
reg lsr_acc_op;            // perform lsr_acc inst (db, sb)
reg lsr_mem_op;            // perform meat of lsr inst for memory addressing modes (db, sb)
reg ora_op;                // final cycle of an ora inst (db, sb)
reg rol_acc_op;            // perform rol_acc inst (db, sb)
reg rol_mem_op;            // perform meat of rol inst for memory addressing modes (db, sb)
reg ror_acc_op;            // perform ror_acc inst (db, sb)
reg ror_mem_op;            // perform meat of ror inst for memory addressing modes (db, sb)
reg sec_op;                // set carry bit (-)
reg sed_op;                // set decimal mode bit (-)
reg sei_op;                // set interrupt disable bit (-)
reg tax_op;                // transfer ac to x (db, sb)
reg tay_op;                // transfer ac to y (db, sb)
reg tsx_op;                // transfer s to x (db, sb)
reg txa_op;                // transfer x to z (db, sb)
reg txs_op;                // transfer x to s (db, sb)
reg tya_op;                // transfer y to a (db, sb)

// DOR (data output register) load controls.
reg ac_to_dor;             // load current ac value into dor (db)
reg p_to_dor;              // load current p value into dor (db)
reg pch_to_dor;            // load current pch value into dor (db)
reg pcl_to_dor;            // load current pcl value into dor (db)
reg x_to_dor;              // load current x value into dor (db, sb)
reg y_to_dor;              // load current y value into dor (db, sb)

// AB (address bus hold registers) load controls.
reg aluinc_to_abh;         // load abh with ai+bi+1 (adh, sb)
reg alusum_to_abh;         // load abh with ai+bi (adh, sb)
reg dl_to_abh;             // load abh with dl (adh)
reg ff_to_abh;             // load abh with 8'hff (adh)
reg one_to_abh;            // load abh with 8'h01 (adh)
reg zero_to_abh;           // load abh with 8'h00 (adh)
reg aluinc_to_abl;         // load abl with ai+bi+1 (adl)
reg alusum_to_abl;         // load abl with ai+bi (adl)
reg dl_to_abl;             // load abl with dl (adl)
reg fa_to_abl;             // load abl with 8'hfa (adl)
reg fb_to_abl;             // load abl with 8'hfb (adl)
reg fc_to_abl;             // load abl with 8'hfc (adl)
reg fd_to_abl;             // load abl with 8'hfd (adl)
reg fe_to_abl;             // load abl with 8'hfe (adl)
reg ff_to_abl;             // load abl with 8'hff (adl)
reg s_to_abl;              // load abl with s (adl)

// AI/BI (ALU input registers) load controls.
reg ac_to_ai;              // load ai with ac (sb)
reg dl_to_ai;              // load ai with dl (db, sb)
reg one_to_ai;             // load ai with 1 (adh, sb)
reg neg1_to_ai;            // load ai with -1 (sb)
reg s_to_ai;               // load ai with s (sb)
reg x_to_ai;               // load ai with x (sb)
reg y_to_ai;               // load ai with y (sb)
reg zero_to_ai;            // load ai with 0 (sb)
reg ac_to_bi;              // load bi with ac (db)
reg aluinc_to_bi;          // load bi with ai+bi+1 (adl)
reg alusum_to_bi;          // load bi with ai+bi (adl)
reg dl_to_bi;              // load bi with dl (db)
reg invdl_to_bi;           // load bi with ~dl (db)
reg neg1_to_bi;            // load bi with -1 (db)
reg pch_to_bi;             // load bi with pch (db)
reg pcl_to_bi;             // load bi with pcl (adl)
reg s_to_bi;               // load bi with s (adl)
reg x_to_bi;               // load bi with x (db, sb)
reg y_to_bi;               // load bi with y (db, sb)

// Stack related controls.
reg aluinc_to_s;           // load ai+bi+1 into s (sb)
reg alusum_to_s;           // load ai+bi into s (sb)
reg dl_to_s;               // load s with current data latch register (db, sb)

// Process status register controls.
reg dl_bits67_to_p;        // latch bits 6 and 7 into P V and N bits (db)
reg dl_to_p;               // load dl into p (db)
reg one_to_i;              // used to supress irqs while processing an interrupt

// Sets all decode ROM output signals to the specified value (0 for init, X for con't care states.
`define SET_ALL_CONTROL_SIGNALS(val) \
    load_prg_byte        = (val);    \
    load_prg_byte_noinc  = (val);    \
    incpc_noload         = (val);    \
    alusum_to_pch        = (val);    \
    dl_to_pch            = (val);    \
    alusum_to_pcl        = (val);    \
    s_to_pcl             = (val);    \
                                     \
    adc_op               = (val);    \
    and_op               = (val);    \
    asl_acc_op           = (val);    \
    asl_mem_op           = (val);    \
    bit_op               = (val);    \
    cmp_op               = (val);    \
    clc_op               = (val);    \
    cld_op               = (val);    \
    cli_op               = (val);    \
    clv_op               = (val);    \
    dec_op               = (val);    \
    dex_op               = (val);    \
    dey_op               = (val);    \
    eor_op               = (val);    \
    inc_op               = (val);    \
    inx_op               = (val);    \
    iny_op               = (val);    \
    lda_op               = (val);    \
    ldx_op               = (val);    \
    ldy_op               = (val);    \
    lsr_acc_op           = (val);    \
    lsr_mem_op           = (val);    \
    ora_op               = (val);    \
    rol_acc_op           = (val);    \
    rol_mem_op           = (val);    \
    ror_acc_op           = (val);    \
    ror_mem_op           = (val);    \
    sec_op               = (val);    \
    sed_op               = (val);    \
    sei_op               = (val);    \
    tax_op               = (val);    \
    tay_op               = (val);    \
    tsx_op               = (val);    \
    txa_op               = (val);    \
    txs_op               = (val);    \
    tya_op               = (val);    \
                                     \
    ac_to_dor            = (val);    \
    p_to_dor             = (val);    \
    pch_to_dor           = (val);    \
    pcl_to_dor           = (val);    \
    x_to_dor             = (val);    \
    y_to_dor             = (val);    \
                                     \
    aluinc_to_abh        = (val);    \
    alusum_to_abh        = (val);    \
    dl_to_abh            = (val);    \
    ff_to_abh            = (val);    \
    one_to_abh           = (val);    \
    zero_to_abh          = (val);    \
    aluinc_to_abl        = (val);    \
    alusum_to_abl        = (val);    \
    dl_to_abl            = (val);    \
    fa_to_abl            = (val);    \
    fb_to_abl            = (val);    \
    fc_to_abl            = (val);    \
    fd_to_abl            = (val);    \
    fe_to_abl            = (val);    \
    ff_to_abl            = (val);    \
    s_to_abl             = (val);    \
                                     \
    ac_to_ai             = (val);    \
    dl_to_ai             = (val);    \
    one_to_ai            = (val);    \
    neg1_to_ai           = (val);    \
    s_to_ai              = (val);    \
    x_to_ai              = (val);    \
    y_to_ai              = (val);    \
    zero_to_ai           = (val);    \
    ac_to_bi             = (val);    \
    aluinc_to_bi         = (val);    \
    alusum_to_bi         = (val);    \
    dl_to_bi             = (val);    \
    invdl_to_bi          = (val);    \
    neg1_to_bi           = (val);    \
    pch_to_bi            = (val);    \
    pcl_to_bi            = (val);    \
    s_to_bi              = (val);    \
    x_to_bi              = (val);    \
    y_to_bi              = (val);    \
                                     \
    aluinc_to_s          = (val);    \
    alusum_to_s          = (val);    \
    dl_to_s              = (val);    \
                                     \
    dl_to_p              = (val);    \
    dl_bits67_to_p       = (val);    \
    one_to_i             = (val);

//
// Decode ROM logic.
//
always @*
  begin
    // Default all control signals to 0.
    `SET_ALL_CONTROL_SIGNALS(1'b0)

    // Defaults for output signals.
    r_nw_out  = 1'b1;
    brk_out   = 1'b0;
    clear_rst = 1'b0;
    clear_nmi = 1'b0;

    if (q_t == T0)
      begin
        load_prg_byte = 1'b1;
      end
    else if (q_t == T1)
      begin
        case (q_ir)
          ADC_ABS, AND_ABS, ASL_ABS, BIT_ABS, CMP_ABS, CPX_ABS, CPY_ABS, DEC_ABS, EOR_ABS,
                   INC_ABS, JMP_ABS, JMP_IND, LDA_ABS, LDX_ABS, LDY_ABS, LSR_ABS,
                   ORA_ABS, ROL_ABS, ROR_ABS, SAX_ABS, SBC_ABS, 
                   STA_ABS, STX_ABS, STY_ABS:
            begin
              load_prg_byte = 1'b1;
              zero_to_ai    = 1'b1;
              dl_to_bi      = 1'b1;
            end
          ADC_ABSX, AND_ABSX, ASL_ABSX,  CMP_ABSX,  DEC_ABSX,  EOR_ABSX, INC_ABSX,
                    LDA_ABSX, LDY_ABSX,  LSR_ABSX,  ORA_ABSX,  ROL_ABSX,
                    ROR_ABSX, SBC_ABSX,  STA_ABSX:
            begin
              load_prg_byte = 1'b1;
              x_to_ai       = 1'b1;
              dl_to_bi      = 1'b1;
            end
          ADC_ABSY, AND_ABSY, CMP_ABSY, EOR_ABSY, LDA_ABSY, LDX_ABSY,
                    ORA_ABSY, SBC_ABSY, STA_ABSY:
            begin
              load_prg_byte = 1'b1;
              y_to_ai       = 1'b1;
              dl_to_bi      = 1'b1;
            end
          ADC_IMM, AND_IMM, EOR_IMM, ORA_IMM:
            begin
              load_prg_byte = 1'b1;
              ac_to_ai      = 1'b1;
              dl_to_bi      = 1'b1;
            end
          ADC_INDX, AND_INDX, CMP_INDX, EOR_INDX, LDA_INDX, ORA_INDX,
                    SAX_INDX, SBC_INDX, STA_INDX,
          ADC_ZPX,  AND_ZPX,  ASL_ZPX,  CMP_ZPX,  DEC_ZPX,
                    EOR_ZPX,  INC_ZPX,  LDA_ZPX,  LDY_ZPX,
                    LSR_ZPX,  ORA_ZPX,  ROL_ZPX,  ROR_ZPX,  SBC_ZPX,  
                    STA_ZPX,  STY_ZPX:
            begin
              x_to_ai  = 1'b1;
              dl_to_bi = 1'b1;
            end
          ADC_INDY, AND_INDY, CMP_INDY, EOR_INDY, LDA_INDY, ORA_INDY,
                    SBC_INDY, STA_INDY:
            begin
              zero_to_abh = 1'b1;
              dl_to_abl   = 1'b1;
              zero_to_ai  = 1'b1;
              dl_to_bi    = 1'b1;
            end
          ADC_ZP, AND_ZP,  ASL_ZP, BIT_ZP, CMP_ZP, CPX_ZP, CPY_ZP, DEC_ZP,
                  EOR_ZP, INC_ZP,  LDA_ZP, LDX_ZP, LDY_ZP, LSR_ZP, ORA_ZP,
                  ROL_ZP, ROR_ZP, SBC_ZP: 
            begin
              zero_to_abh = 1'b1;
              dl_to_abl   = 1'b1;
            end
          ASL_ACC, LSR_ACC, ROL_ACC, ROR_ACC:
            begin
              ac_to_ai = 1'b1;
              ac_to_bi = 1'b1;
            end
          BCC, BCS, BEQ, BMI, BNE, BPL, BVC, BVS:
            begin
              load_prg_byte = 1'b1;
              dl_to_ai      = 1'b1;
              pcl_to_bi     = 1'b1;
            end
          BRK:
            begin
              if (q_irq_sel == INTERRUPT_BRK)
                incpc_noload = 1'b1;
              pch_to_dor   = 1'b1;
              one_to_abh   = 1'b1;
              s_to_abl     = 1'b1;
              neg1_to_ai   = 1'b1;
              s_to_bi      = 1'b1;
            end
          CLC:
            clc_op = 1'b1;
          CLD:
            cld_op = 1'b1;
          CLI:
            cli_op = 1'b1;
          CLV:
            clv_op = 1'b1;
          CMP_IMM, SBC_IMM:
            begin
              load_prg_byte = 1'b1;
              ac_to_ai      = 1'b1;
              invdl_to_bi   = 1'b1;
            end
          CPX_IMM:
            begin
              load_prg_byte = 1'b1;
              x_to_ai       = 1'b1;
              invdl_to_bi   = 1'b1;
            end
          CPY_IMM:
            begin
              load_prg_byte = 1'b1;
              y_to_ai       = 1'b1;
              invdl_to_bi   = 1'b1;
            end
          DEX:
            begin
              x_to_ai    = 1'b1;
              neg1_to_bi = 1'b1;
            end
          DEY:
            begin
              y_to_ai    = 1'b1;
              neg1_to_bi = 1'b1;
            end
          HLT:
            begin
              // The HLT instruction asks hci to deassert the rdy signal, effectively pausing the
              // cpu and allowing the debug block to inspect the internal state.
              brk_out = (q_clk_phase == 6'h01) && rdy;
            end
          INX:
            begin
              zero_to_ai = 1'b1;
              x_to_bi    = 1'b1;
            end
          INY:
            begin
              zero_to_ai = 1'b1;
              y_to_bi    = 1'b1;
            end
          JSR:
            begin
              incpc_noload = 1'b1;
              one_to_abh   = 1'b1;
              s_to_abl     = 1'b1;
              s_to_bi      = 1'b1;
              dl_to_s      = 1'b1;
            end
          LDX_ZPY, SAX_ZPY, STX_ZPY:
            begin
              y_to_ai  = 1'b1;
              dl_to_bi = 1'b1;
            end
          LDA_IMM:
            begin
              load_prg_byte = 1'b1;
              lda_op        = 1'b1;
            end
          LDX_IMM:
            begin
              load_prg_byte = 1'b1;
              ldx_op        = 1'b1;
            end
          LDY_IMM:
            begin
              load_prg_byte = 1'b1;
              ldy_op        = 1'b1;
            end
          PHA:
            begin
              ac_to_dor  = 1'b1;
              one_to_abh = 1'b1;
              s_to_abl   = 1'b1;
            end
          PHP:
            begin
              p_to_dor   = 1'b1;
              one_to_abh = 1'b1;
              s_to_abl   = 1'b1;
            end
          PLA, PLP, RTI, RTS:
            begin
              zero_to_ai = 1'b1;
              s_to_bi    = 1'b1;
            end
          SEC:
            sec_op = 1'b1;
          SED:
            sed_op = 1'b1;
          SEI:
            sei_op = 1'b1;
          SAX_ZP:
            begin
              ac_to_dor   = 1'b1;
              x_to_dor    = 1'b1;
              zero_to_abh = 1'b1;
              dl_to_abl   = 1'b1;
            end
          STA_ZP:
            begin
              ac_to_dor   = 1'b1;
              zero_to_abh = 1'b1;
              dl_to_abl   = 1'b1;
            end
          STX_ZP:
            begin
              x_to_dor    = 1'b1;
              zero_to_abh = 1'b1;
              dl_to_abl   = 1'b1;
            end
          STY_ZP:
            begin
              y_to_dor    = 1'b1;
              zero_to_abh = 1'b1;
              dl_to_abl   = 1'b1;
            end
          TAX:
            tax_op = 1'b1;
          TAY:
            tay_op = 1'b1;
          TSX:
            tsx_op = 1'b1;
          TXA:
            txa_op = 1'b1;
          TXS:
            txs_op = 1'b1;
          TYA:
            tya_op = 1'b1;
        endcase
      end
    else if (q_t == T2)
      begin
        case (q_ir)
          ADC_ABS, AND_ABS, ASL_ABS, BIT_ABS, CMP_ABS, CPX_ABS, CPY_ABS, DEC_ABS, EOR_ABS,
                   INC_ABS, LDA_ABS, LDX_ABS, LDY_ABS, LSR_ABS, ORA_ABS, 
                   ROL_ABS, ROR_ABS, SBC_ABS,
          JMP_IND:
            begin
              dl_to_abh     = 1'b1;
              alusum_to_abl = 1'b1;
            end
          ADC_ABSX, AND_ABSX, ASL_ABSX,  CMP_ABSX,  DEC_ABSX,  EOR_ABSX, INC_ABSX,
                    LDA_ABSX,  LDY_ABSX,  LSR_ABSX,  ORA_ABSX,  ROL_ABSX,
                    ROR_ABSX, SBC_ABSX,  STA_ABSX,
          ADC_ABSY, AND_ABSY, CMP_ABSY,  EOR_ABSY,  LDA_ABSY,
                    LDX_ABSY, ORA_ABSY,  SBC_ABSY,  
                    STA_ABSY:
            begin
              dl_to_abh     = 1'b1;
              alusum_to_abl = 1'b1;
              zero_to_ai    = 1'b1;
              dl_to_bi      = 1'b1;
            end
          ADC_IMM, SBC_IMM:
            begin
              load_prg_byte = 1'b1;
              adc_op        = 1'b1;
            end
          ADC_INDX, AND_INDX, CMP_INDX, EOR_INDX, LDA_INDX, ORA_INDX,
                    SAX_INDX, SBC_INDX, STA_INDX,
          ADC_ZPX,  AND_ZPX,  ASL_ZPX,  CMP_ZPX,  DEC_ZPX,
                    EOR_ZPX,  INC_ZPX,  LDA_ZPX,  LDY_ZPX,
                    LSR_ZPX,  ORA_ZPX,  ROL_ZPX,  ROR_ZPX,  SBC_ZPX,  
          LDX_ZPY:
            begin
              zero_to_abh   = 1'b1;
              alusum_to_abl = 1'b1;
            end
          ADC_INDY, AND_INDY, CMP_INDY, EOR_INDY, LDA_INDY, ORA_INDY,
                    SBC_INDY, STA_INDY:
            begin
              zero_to_abh   = 1'b1;
              aluinc_to_abl = 1'b1;
              y_to_ai       = 1'b1;
              dl_to_bi      = 1'b1;
            end
          ADC_ZP, AND_ZP, EOR_ZP, ORA_ZP:
            begin
              load_prg_byte = 1'b1;
              ac_to_ai      = 1'b1;
              dl_to_bi      = 1'b1;
            end
          AND_IMM:
            begin
              load_prg_byte = 1'b1;
              and_op        = 1'b1;
            end
          ASL_ACC:
            begin
              load_prg_byte = 1'b1;
              asl_acc_op    = 1'b1;
            end
          ASL_ZP, LSR_ZP, ROL_ZP, ROR_ZP:
            begin
              dl_to_ai = 1'b1;
              dl_to_bi = 1'b1;
            end
          LSR_ACC:
            begin
              load_prg_byte = 1'b1;
              lsr_acc_op    = 1'b1;
            end
          BCC, BCS, BEQ, BMI, BNE, BPL, BVC, BVS:
            begin
              alusum_to_pcl  = 1'b1;
              alusum_to_abl  = 1'b1;
              if (q_ai[7])
                neg1_to_ai = 1'b1;
              else
                one_to_ai  = 1'b1;
              pch_to_bi      = 1'b1;
            end
          BIT_ZP:
            begin
              load_prg_byte  = 1'b1;
              ac_to_ai       = 1'b1;
              dl_to_bi       = 1'b1;
              dl_bits67_to_p = 1'b1;
            end
          BRK:
            begin
              pcl_to_dor    = 1'b1;
              alusum_to_abl = 1'b1;
              alusum_to_bi  = 1'b1;
              r_nw_out      = 1'b0;
            end
          CMP_IMM, CPX_IMM, CPY_IMM:
            begin
              load_prg_byte = 1'b1;
              cmp_op        = 1'b1;
            end
          CMP_ZP, SBC_ZP:
            begin
              load_prg_byte = 1'b1;
              ac_to_ai      = 1'b1;
              invdl_to_bi   = 1'b1;
            end
          CPX_ZP:
            begin
              load_prg_byte = 1'b1;
              x_to_ai       = 1'b1;
              invdl_to_bi   = 1'b1;
            end
          CPY_ZP:
            begin
              load_prg_byte = 1'b1;
              y_to_ai       = 1'b1;
              invdl_to_bi   = 1'b1;
            end
          DEC_ZP:
            begin
              neg1_to_ai = 1'b1;
              dl_to_bi   = 1'b1;
            end
          DEX:
            begin
              load_prg_byte = 1'b1;
              dex_op        = 1'b1;
            end
          DEY:
            begin
              load_prg_byte = 1'b1;
              dey_op        = 1'b1;
            end
          EOR_IMM:
            begin
              load_prg_byte = 1'b1;
              eor_op        = 1'b1;
            end
          INC_ZP:
            begin
              zero_to_ai = 1'b1;
              dl_to_bi   = 1'b1;
            end
          INX:
            begin
              load_prg_byte = 1'b1;
              inx_op        = 1'b1;
            end
          INY:
            begin
              load_prg_byte = 1'b1;
              iny_op        = 1'b1;
            end
          JMP_ABS:
            begin
              dl_to_pch     = 1'b1;
              alusum_to_pcl = 1'b1;
              dl_to_abh     = 1'b1;
              alusum_to_abl = 1'b1;
            end
          JSR:
            begin
              pch_to_dor = 1'b1;
              neg1_to_ai = 1'b1;
            end
          LDA_ZP:
            begin
              load_prg_byte = 1'b1;
              lda_op        = 1'b1;
            end
          LDX_ZP:
            begin
              load_prg_byte = 1'b1;
              ldx_op        = 1'b1;
            end
          LDY_ZP:
            begin
              load_prg_byte = 1'b1;
              ldy_op        = 1'b1;
            end
          ORA_IMM:
            begin
              load_prg_byte = 1'b1;
              ora_op        = 1'b1;
            end
          PHA, PHP:
            begin
              load_prg_byte_noinc = 1'b1;
              s_to_ai             = 1'b1;
              neg1_to_bi          = 1'b1;
              r_nw_out            = 1'b0;
            end
          PLA, PLP:
            begin
              one_to_abh    = 1'b1;
              aluinc_to_abl = 1'b1;
              aluinc_to_s   = 1'b1;
            end
          ROL_ACC:
            begin
              load_prg_byte = 1'b1;
              rol_acc_op    = 1'b1;
            end
          ROR_ACC:
            begin
              load_prg_byte = 1'b1;
              ror_acc_op    = 1'b1;
            end
          RTI, RTS:
            begin
              one_to_abh    = 1'b1;
              aluinc_to_abl = 1'b1;
              aluinc_to_bi  = 1'b1;
            end
          SAX_ABS:
            begin
              ac_to_dor     = 1'b1;
              x_to_dor      = 1'b1;
              dl_to_abh     = 1'b1;
              alusum_to_abl = 1'b1;
            end
          SAX_ZP, STA_ZP, STX_ZP, STY_ZP:
            begin
              load_prg_byte = 1'b1;
              r_nw_out      = 1'b0;
            end
          SAX_ZPY:
            begin
              ac_to_dor     = 1'b1;
              x_to_dor      = 1'b1;
              zero_to_abh   = 1'b1;
              alusum_to_abl = 1'b1;
            end
          STA_ABS:
            begin
              ac_to_dor     = 1'b1;
              dl_to_abh     = 1'b1;
              alusum_to_abl = 1'b1;
            end
          STA_ZPX:
            begin
              ac_to_dor     = 1'b1;
              zero_to_abh   = 1'b1;
              alusum_to_abl = 1'b1;
            end
          STX_ABS:
            begin
              x_to_dor      = 1'b1;
              dl_to_abh     = 1'b1;
              alusum_to_abl = 1'b1;
            end
          STX_ZPY:
            begin
              x_to_dor      = 1'b1;
              zero_to_abh   = 1'b1;
              alusum_to_abl = 1'b1;
            end
          STY_ABS:
            begin
              y_to_dor      = 1'b1;
              dl_to_abh     = 1'b1;
              alusum_to_abl = 1'b1;
            end
          STY_ZPX:
            begin
              y_to_dor      = 1'b1;
              zero_to_abh   = 1'b1;
              alusum_to_abl = 1'b1;
            end
        endcase
      end
    else if (q_t == T3)
      begin
        case (q_ir)
          ADC_ABS, AND_ABS, EOR_ABS, ORA_ABS,
          ADC_ZPX, AND_ZPX, EOR_ZPX, ORA_ZPX:
            begin
              load_prg_byte = 1'b1;
              ac_to_ai      = 1'b1;
              dl_to_bi      = 1'b1;
            end
          ADC_ABSX, AND_ABSX,  ASL_ABSX,  CMP_ABSX,  DEC_ABSX, EOR_ABSX, INC_ABSX,
                    LDA_ABSX,  LDY_ABSX,  LSR_ABSX,  ORA_ABSX, ROL_ABSX,
                    ROR_ABSX,  SBC_ABSX,
          ADC_ABSY, AND_ABSY,  CMP_ABSY,  EOR_ABSY,  LDA_ABSY,
                    LDX_ABSY,  ORA_ABSY,  SBC_ABSY:
            begin
              aluinc_to_abh = q_acr;
            end
          ADC_INDX, AND_INDX, CMP_INDX, EOR_INDX, LDA_INDX, ORA_INDX,
                    SAX_INDX, STA_INDX, SBC_INDX:
            begin
              zero_to_abh   = 1'b1;
              aluinc_to_abl = 1'b1;
              zero_to_ai    = 1'b1;
              dl_to_bi      = 1'b1;
            end
          ADC_INDY, AND_INDY, CMP_INDY, EOR_INDY, LDA_INDY, ORA_INDY,
                    SBC_INDY, STA_INDY:
            begin
              dl_to_abh     = 1'b1;
              alusum_to_abl = 1'b1;
              zero_to_ai    = 1'b1;
              dl_to_bi      = 1'b1;
            end
          ADC_ZP, SBC_ZP:
            begin
              load_prg_byte = 1'b1;
              adc_op        = 1'b1;
            end
          AND_ZP:
            begin
              load_prg_byte = 1'b1;
              and_op        = 1'b1;
            end
          ASL_ABS, LSR_ABS, ROL_ABS, ROR_ABS,
          ASL_ZPX, LSR_ZPX, ROL_ZPX, ROR_ZPX:
            begin
              dl_to_ai = 1'b1;
              dl_to_bi = 1'b1;
            end
          ASL_ZP:
            asl_mem_op = 1'b1;
          BCC, BCS, BEQ, BMI, BNE, BPL, BVC, BVS:
            begin
              alusum_to_pch = 1'b1;
              alusum_to_abh = 1'b1;
            end
          BIT_ABS:
            begin
              load_prg_byte  = 1'b1;
              ac_to_ai       = 1'b1;
              dl_to_bi       = 1'b1;
              dl_bits67_to_p = 1'b1;
            end
          BIT_ZP:
            begin
              load_prg_byte = 1'b1;
              bit_op        = 1'b1;
            end
          BRK:
            begin
              p_to_dor      = 1'b1;
              alusum_to_abl = 1'b1;
              alusum_to_bi  = 1'b1;
              r_nw_out      = 1'b0;
            end
          CMP_ABS, SBC_ABS,
          CMP_ZPX, SBC_ZPX:
            begin
              load_prg_byte = 1'b1;
              ac_to_ai      = 1'b1;
              invdl_to_bi   = 1'b1;
            end
          CMP_ZP, CPX_ZP, CPY_ZP:
            begin
              load_prg_byte = 1'b1;
              cmp_op        = 1'b1;
            end
          CPX_ABS:
            begin
              load_prg_byte = 1'b1;
              x_to_ai       = 1'b1;
              invdl_to_bi   = 1'b1;
            end
          CPY_ABS:
            begin
              load_prg_byte = 1'b1;
              y_to_ai       = 1'b1;
              invdl_to_bi   = 1'b1;
            end
          DEC_ABS,
          DEC_ZPX:
            begin
              neg1_to_ai = 1'b1;
              dl_to_bi   = 1'b1;
            end
          DEC_ZP:
            dec_op = 1'b1;
          EOR_ZP:
            begin
              load_prg_byte = 1'b1;
              eor_op        = 1'b1;
            end
          INC_ABS,
          INC_ZPX:
            begin
              zero_to_ai = 1'b1;
              dl_to_bi   = 1'b1;
            end
          INC_ZP:
            inc_op = 1'b1;
          JMP_IND:
            begin
              aluinc_to_abl = 1'b1;
              zero_to_ai    = 1'b1;
              dl_to_bi      = 1'b1;
            end
          JSR:
            begin
              pcl_to_dor    = 1'b1;
              alusum_to_abl = 1'b1;
              alusum_to_bi  = 1'b1;
              r_nw_out      = 1'b0;
            end
          LDA_ABS, LDA_ZPX:
            begin
              load_prg_byte = 1'b1;
              lda_op        = 1'b1;
            end
          LDX_ABS, LDX_ZPY:
            begin
              load_prg_byte = 1'b1;
              ldx_op        = 1'b1;
            end
          LDY_ABS, LDY_ZPX:
            begin
              load_prg_byte = 1'b1;
              ldy_op        = 1'b1;
            end
          LSR_ZP:
            lsr_mem_op = 1'b1;
          ORA_ZP:
            begin
              load_prg_byte = 1'b1;
              ora_op        = 1'b1;
            end
          PHA, PHP:
            begin
              load_prg_byte = 1'b1;
              alusum_to_s   = 1'b1;
            end
          PLA:
            begin
              load_prg_byte_noinc = 1'b1;
              lda_op              = 1'b1;
            end
          PLP:
            begin
              load_prg_byte_noinc = 1'b1;
              dl_to_p             = 1'b1;
            end
          ROL_ZP:
            rol_mem_op = 1'b1;
          ROR_ZP:
            ror_mem_op = 1'b1;
          RTI:
            begin
              aluinc_to_abl = 1'b1;
              aluinc_to_bi  = 1'b1;
              dl_to_p       = 1'b1;
            end
          RTS:
            begin
              aluinc_to_abl = 1'b1;
              dl_to_s       = 1'b1;
            end
          SAX_ABS, STA_ABS, STX_ABS, STY_ABS,
          STA_ZPX, STY_ZPX,
          SAX_ZPY, STX_ZPY:
            begin
              load_prg_byte = 1'b1;
              r_nw_out      = 1'b0;
            end
          STA_ABSX,
          STA_ABSY:
            begin
              ac_to_dor     = 1'b1;
              aluinc_to_abh = q_acr;
            end
        endcase
      end
    else if (q_t == T4)
      begin
        case (q_ir)
          ADC_ABS, SBC_ABS,
          ADC_ZPX, SBC_ZPX:
            begin
              load_prg_byte = 1'b1;
              adc_op        = 1'b1;
            end
          ADC_ABSX, AND_ABSX, EOR_ABSX, ORA_ABSX,
          ADC_ABSY, AND_ABSY, EOR_ABSY, ORA_ABSY:
            begin
              load_prg_byte = 1'b1;
              ac_to_ai      = 1'b1;
              dl_to_bi      = 1'b1;
            end
          ADC_INDX, AND_INDX, CMP_INDX, EOR_INDX, LDA_INDX, ORA_INDX,
                    SBC_INDX:
            begin
              dl_to_abh     = 1'b1;
              alusum_to_abl = 1'b1;
            end
          ADC_INDY, AND_INDY, CMP_INDY, EOR_INDY, LDA_INDY, ORA_INDY,
                    SBC_INDY:
            begin
              aluinc_to_abh = q_acr;
            end
          AND_ABS,
          AND_ZPX:
            begin
              load_prg_byte = 1'b1;
              and_op        = 1'b1;
            end
          ASL_ABS,
          ASL_ZPX:
            asl_mem_op = 1'b1;
          ASL_ZP,   DEC_ZP, INC_ZP, LSR_ZP, ROL_ZP, ROR_ZP,
          STA_ABSX,
          STA_ABSY:
            begin
              load_prg_byte = 1'b1;
              r_nw_out      = 1'b0;
            end
          ASL_ABSX, LSR_ABSX, ROL_ABSX, ROR_ABSX:
            begin
              dl_to_ai = 1'b1;
              dl_to_bi = 1'b1;
            end
          BIT_ABS:
            begin
              load_prg_byte = 1'b1;
              bit_op        = 1'b1;
            end
          BRK:
            begin
              ff_to_abh = 1'b1;
              r_nw_out  = 1'b0;
              one_to_i  = 1'b1;
              case (q_irq_sel)
                INTERRUPT_RST:                fc_to_abl = 1'b1;
                INTERRUPT_NMI:                fa_to_abl = 1'b1;
                INTERRUPT_IRQ, INTERRUPT_BRK: fe_to_abl = 1'b1;
              endcase
            end
          CMP_ABS, CPX_ABS, CPY_ABS,
          CMP_ZPX:
            begin
              load_prg_byte = 1'b1;
              cmp_op        = 1'b1;
            end
          CMP_ABSX, SBC_ABSX,
          CMP_ABSY, SBC_ABSY:
            begin
              load_prg_byte = 1'b1;
              ac_to_ai      = 1'b1;
              invdl_to_bi   = 1'b1;
            end
          DEC_ABS,
          DEC_ZPX:
            dec_op = 1'b1;
          DEC_ABSX:
            begin
              neg1_to_ai = 1'b1;
              dl_to_bi   = 1'b1;
            end
          EOR_ABS,
          EOR_ZPX:
            begin
              load_prg_byte = 1'b1;
              eor_op        = 1'b1;
            end
          INC_ABS,
          INC_ZPX:
            inc_op = 1'b1;
          INC_ABSX:
            begin
              zero_to_ai = 1'b1;
              dl_to_bi   = 1'b1;
            end
          JMP_IND:
            begin
              dl_to_pch     = 1'b1;
              alusum_to_pcl = 1'b1;
              dl_to_abh     = 1'b1;
              alusum_to_abl = 1'b1;
            end
          JSR:
            begin
              load_prg_byte_noinc = 1'b1;
              r_nw_out            = 1'b0;
            end
          LDA_ABSX,
          LDA_ABSY:
            begin
              load_prg_byte = 1'b1;
              lda_op        = 1'b1;
            end
          LDX_ABSY:
            begin
              load_prg_byte = 1'b1;
              ldx_op        = 1'b1;
            end
          LDY_ABSX:
            begin
              load_prg_byte = 1'b1;
              ldy_op        = 1'b1;
            end
          LSR_ABS,
          LSR_ZPX:
            lsr_mem_op = 1'b1;
          ORA_ABS,
          ORA_ZPX:
            begin
              load_prg_byte = 1'b1;
              ora_op        = 1'b1;
            end
          ROL_ABS,
          ROL_ZPX:
            rol_mem_op = 1'b1;
          ROR_ABS,
          ROR_ZPX:
            ror_mem_op = 1'b1;
          RTI:
            begin
              aluinc_to_abl = 1'b1;
              dl_to_s       = 1'b1;
            end
          RTS:
            begin
              dl_to_pch   = 1'b1;
              s_to_pcl    = 1'b1;
              aluinc_to_s = 1'b1;
            end
          SAX_INDX:
            begin
              ac_to_dor     = 1'b1;
              x_to_dor      = 1'b1;
              dl_to_abh     = 1'b1;
              alusum_to_abl = 1'b1;
            end
          STA_INDX:
            begin
              ac_to_dor     = 1'b1;
              dl_to_abh     = 1'b1;
              alusum_to_abl = 1'b1;
            end
          STA_INDY:
            begin
              ac_to_dor     = 1'b1;
              aluinc_to_abh = q_acr;
            end
        endcase
      end
    else if (q_t == T5)
      begin
        case (q_ir)
          ADC_ABSX, SBC_ABSX,
          ADC_ABSY, SBC_ABSY:
            begin
              load_prg_byte = 1'b1;
              adc_op        = 1'b1;
            end
          ADC_INDX, AND_INDX, EOR_INDX, ORA_INDX,
          ADC_INDY, AND_INDY, EOR_INDY, ORA_INDY:
            begin
              load_prg_byte = 1'b1;
              ac_to_ai      = 1'b1;
              dl_to_bi      = 1'b1;
            end
          AND_ABSX,
          AND_ABSY:
            begin
              load_prg_byte = 1'b1;
              and_op        = 1'b1;
            end
          ASL_ABS, DEC_ABS, INC_ABS, LSR_ABS, ROL_ABS, ROR_ABS,
          ASL_ZPX, DEC_ZPX, INC_ZPX, LSR_ZPX, ROL_ZPX, ROR_ZPX,
          SAX_INDX, STA_INDX,
          STA_INDY:
            begin
              load_prg_byte = 1'b1;
              r_nw_out      = 1'b0;
            end
          ASL_ABSX:
            asl_mem_op = 1'b1;
          BRK:
            begin
              ff_to_abh = 1'b1;
              dl_to_s   = 1'b1;
              case (q_irq_sel)
                INTERRUPT_RST:                fd_to_abl = 1'b1;
                INTERRUPT_NMI:                fb_to_abl = 1'b1;
                INTERRUPT_IRQ, INTERRUPT_BRK: ff_to_abl = 1'b1;
              endcase
            end
          CMP_ABSX,
          CMP_ABSY:
            begin
              load_prg_byte = 1'b1;
              cmp_op        = 1'b1;
            end
          CMP_INDX, SBC_INDX,
          CMP_INDY, SBC_INDY:
            begin
              load_prg_byte = 1'b1;
              ac_to_ai      = 1'b1;
              invdl_to_bi   = 1'b1;
            end
          DEC_ABSX:
            dec_op = 1'b1;
          EOR_ABSX,
          EOR_ABSY:
            begin
              load_prg_byte = 1'b1;
              eor_op        = 1'b1;
            end
          INC_ABSX:
            inc_op = 1'b1;
          JSR:
            begin
              dl_to_pch    = 1'b1;
              s_to_pcl     = 1'b1;
              dl_to_abh    = 1'b1;
              s_to_abl     = 1'b1;
              alusum_to_s  = 1'b1;
            end
          LDA_INDX,
          LDA_INDY:
            begin
              load_prg_byte = 1'b1;
              lda_op        = 1'b1;
            end
          LSR_ABSX:
            lsr_mem_op = 1'b1;
          ORA_ABSX,
          ORA_ABSY:
            begin
              load_prg_byte = 1'b1;
              ora_op        = 1'b1;
            end
          ROL_ABSX:
            rol_mem_op = 1'b1;
          ROR_ABSX:
            ror_mem_op = 1'b1;
          RTI:
            begin
              dl_to_pch   = 1'b1;
              s_to_pcl    = 1'b1;
              dl_to_abh   = 1'b1;
              s_to_abl    = 1'b1;
              aluinc_to_s = 1'b1;
            end
          RTS:
            load_prg_byte = 1'b1;
        endcase
      end
    else if (q_t == T6)
      begin
        case (q_ir)
          ADC_INDX, SBC_INDX,
          ADC_INDY, SBC_INDY:
            begin
              load_prg_byte = 1'b1;
              adc_op        = 1'b1;
            end
          AND_INDX,
          AND_INDY:
            begin
              load_prg_byte = 1'b1;
              and_op        = 1'b1;
            end
          ASL_ABSX, DEC_ABSX, INC_ABSX, LSR_ABSX, ROL_ABSX, ROR_ABSX:
            begin
              load_prg_byte  = 1'b1;
              r_nw_out       = 1'b0;
            end
          BRK:
            begin
              dl_to_pch   = 1'b1;
              s_to_pcl    = 1'b1;
              dl_to_abh   = 1'b1;
              s_to_abl    = 1'b1;
              alusum_to_s = 1'b1;

              case (q_irq_sel)
                INTERRUPT_RST: clear_rst = 1'b1;
                INTERRUPT_NMI: clear_nmi = 1'b1;
              endcase
            end
          CMP_INDX,
          CMP_INDY:
            begin
              load_prg_byte = 1'b1;
              cmp_op        = 1'b1;
            end
          EOR_INDX,
          EOR_INDY:
            begin
              load_prg_byte = 1'b1;
              eor_op        = 1'b1;
            end
          ORA_INDX,
          ORA_INDY:
            begin
              load_prg_byte = 1'b1;
              ora_op        = 1'b1;
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
assign add_adl    = aluinc_to_abl        | aluinc_to_bi         | alusum_to_abl        |
                    alusum_to_bi         | alusum_to_pcl;
assign dl_adl     = dl_to_abl;
assign pcl_adl    = load_prg_byte        | load_prg_byte_noinc  |
                    pcl_to_bi;
assign s_adl      = s_to_abl             | s_to_bi              | s_to_pcl;
assign zero_adl0  = fa_to_abl            | fc_to_abl            | fe_to_abl;
assign zero_adl1  = fc_to_abl            | fd_to_abl;
assign zero_adl2  = fa_to_abl            | fb_to_abl;
assign dl_adh     = dl_to_abh            | dl_to_pch;
assign pch_adh    = load_prg_byte        | load_prg_byte_noinc;
assign zero_adh0  = zero_to_abh;
assign zero_adh17 = one_to_abh           | one_to_ai            | zero_to_abh;
assign ac_db      = ac_to_bi             | ac_to_dor;
assign dl_db      = dl_to_ai             | dl_to_bi             |
                    dl_to_p              | dl_to_s              | invdl_to_bi          |
                    lda_op               | ldx_op               | ldy_op;
assign p_db       = p_to_dor;
assign pch_db     = pch_to_bi            | pch_to_dor;
assign pcl_db     = pcl_to_dor;
assign ac_sb      = ac_to_ai             | tax_op               | tay_op;
assign add_sb     = adc_op               | aluinc_to_abh        |
                    aluinc_to_s          | alusum_to_abh        | alusum_to_pch        |
                    alusum_to_s          | and_op               |
                    asl_acc_op           | asl_mem_op           | bit_op               |
                    cmp_op               | dec_op               | dex_op               |
                    dey_op               | eor_op               | inc_op               |
                    inx_op               | iny_op               | lsr_acc_op           |
                    lsr_mem_op           | ora_op               | rol_acc_op           |
                    rol_mem_op           | ror_acc_op           | ror_mem_op;
assign x_sb       = txa_op               | txs_op               | x_to_ai              |
                    x_to_bi              | x_to_dor;
assign y_sb       = tya_op               | y_to_ai              | y_to_bi              |
                    y_to_dor;
assign s_sb       = s_to_ai              | tsx_op;
assign sb_adh     = aluinc_to_abh        | alusum_to_abh        | alusum_to_pch        |
                    one_to_ai            | one_to_i;
assign sb_db      = adc_op               |
                    and_op               | asl_acc_op           |
                    asl_mem_op           | bit_op               | cmp_op               |
                    dl_to_s              | dec_op               | dex_op               |
                    dey_op               | dl_to_ai             | eor_op               |
                    inc_op               | inx_op               | iny_op               |
                    lda_op               | ldx_op               | ldy_op               |
                    lsr_acc_op           | lsr_mem_op           | one_to_i             |
                    ora_op               | rol_acc_op           | rol_mem_op           |
                    ror_acc_op           | ror_mem_op           | tax_op               |
                    tay_op               | tsx_op               | txa_op               |
                    tya_op               | x_to_bi              | x_to_dor             |
                    y_to_bi              | y_to_dor;
assign adh_abh    = aluinc_to_abh        | alusum_to_abh        | dl_to_abh            |
                    ff_to_abh            | load_prg_byte        | load_prg_byte_noinc  |
                    one_to_abh           | zero_to_abh;
assign adl_abl    = aluinc_to_abl        | alusum_to_abl        | dl_to_abl            |
                    fa_to_abl            | fb_to_abl            | fc_to_abl            |
                    fd_to_abl            | fe_to_abl            | ff_to_abl            |
                    load_prg_byte        | load_prg_byte_noinc  |
                    s_to_abl;
assign adl_add    = aluinc_to_bi         | alusum_to_bi         | pcl_to_bi            |
                    s_to_bi;
assign db_add     = ac_to_bi             | dl_to_bi             |
                    neg1_to_bi           | pch_to_bi            | x_to_bi              |
                    y_to_bi;
assign invdb_add  = invdl_to_bi;
assign sb_s       = aluinc_to_s          | alusum_to_s          | dl_to_s              |
                    txs_op;
assign zero_add   = zero_to_ai;
assign sb_ac      = adc_op               | and_op               |
                    asl_acc_op           | eor_op               |
                    lda_op               | lsr_acc_op           | ora_op               |
                    rol_acc_op           | ror_acc_op           | txa_op               |
                    tya_op;
assign sb_add     = ac_to_ai             | dl_to_ai             | neg1_to_ai           |
                    one_to_ai            | s_to_ai              | x_to_ai              |
                    y_to_ai;
assign adh_pch    = alusum_to_pch        | dl_to_pch;
assign adl_pcl    = alusum_to_pcl        | s_to_pcl;
assign sb_x       = dex_op               | inx_op               | ldx_op               |
                    tax_op               | tsx_op;
assign sb_y       = dey_op               | iny_op               | ldy_op               |
                    tay_op;
assign acr_c      = adc_op               | asl_acc_op           | asl_mem_op           |
                    cmp_op               | lsr_acc_op           | lsr_mem_op           |
                    rol_acc_op           | rol_mem_op           | ror_acc_op           |
                    ror_mem_op;
assign db0_c      = dl_to_p;
assign ir5_c      = clc_op               | sec_op;
assign db3_d      = dl_to_p;
assign ir5_d      = cld_op               | sed_op;
assign db2_i      = dl_to_p              | one_to_i;
assign ir5_i      = cli_op               | sei_op;
assign db7_n      = adc_op               | and_op               |
                    asl_acc_op           | asl_mem_op           |
                    cmp_op               | dec_op               | dex_op               |
                    dey_op               | dl_bits67_to_p       | dl_to_p              |
                    eor_op               | inc_op               | inx_op               |
                    iny_op               | lda_op               | ldx_op               |
                    ldy_op               | lsr_acc_op           | lsr_mem_op           |
                    ora_op               | rol_acc_op           | rol_mem_op           |
                    ror_acc_op           | ror_mem_op           | tax_op               |
                    tay_op               | tsx_op               | txa_op               |
                    tya_op;
assign avr_v      = adc_op;
assign db6_v      = dl_bits67_to_p       | dl_to_p;
assign zero_v     = clv_op;
assign db1_z      = dl_to_p;
assign dbz_z      = adc_op               | and_op               |
                    asl_acc_op           | asl_mem_op           |
                    bit_op               | cmp_op               | dec_op               |
                    dex_op               | dey_op               | eor_op               |
                    inc_op               | inx_op               | iny_op               |
                    lda_op               | ldx_op               | ldy_op               |
                    lsr_acc_op           | lsr_mem_op           | ora_op               |
                    rol_acc_op           | rol_mem_op           | ror_acc_op           |
                    ror_mem_op           | tax_op               | tay_op               |
                    tsx_op               | txa_op               | tya_op;
assign ands       = and_op               | bit_op;
assign eors       = eor_op;
assign ors        = ora_op;
assign sums       = adc_op               | aluinc_to_abh        | aluinc_to_abl        |
                    aluinc_to_bi         | aluinc_to_s          |
                    alusum_to_abh        | alusum_to_abl        | alusum_to_bi         |
                    alusum_to_pch        | alusum_to_pcl        | alusum_to_s          |
                    asl_acc_op           | asl_mem_op           | cmp_op               |
                    dec_op               | dex_op               | dey_op               |
                    inc_op               | inx_op               | iny_op               |
                    rol_acc_op           | rol_mem_op;
assign srs        = lsr_acc_op           | lsr_mem_op           |
                    ror_acc_op           | ror_mem_op;

assign addc       = (adc_op | rol_acc_op | rol_mem_op | ror_acc_op | ror_mem_op) ? q_c :
                    aluinc_to_abh        | aluinc_to_abl        | aluinc_to_bi         |
                    aluinc_to_s          | cmp_op               |
                    inc_op               | inx_op               | iny_op;
assign i_pc       = (incpc_noload        | load_prg_byte)       & !force_noinc_pc;

//
// Update internal buses.  Use in/out to replicate pass mosfets and avoid using internal
// tristate buffers.
//
assign adh_in[7:1]  = (dl_adh)     ? q_dl[7:1]  :
                      (pch_adh)    ? q_pch[7:1] :
                      (zero_adh17) ? 7'h00      : 7'h7F;
assign adh_in[0]    = (dl_adh)     ? q_dl[0]    :
                      (pch_adh)    ? q_pch[0]   :
                      (zero_adh0)  ? 1'b0       : 1'b1;

assign adl[7:3] = (add_adl)   ? q_add[7:3] :
                  (dl_adl)    ? q_dl[7:3]  :
                  (pcl_adl)   ? q_pcl[7:3] :
                  (s_adl)     ? q_s[7:3]   : 5'h1F;
assign adl[2]   = (add_adl)   ? q_add[2]   :
                  (dl_adl)    ? q_dl[2]    :
                  (pcl_adl)   ? q_pcl[2]   :
                  (s_adl)     ? q_s[2]     :
                  (zero_adl2) ? 1'b0       : 1'b1;
assign adl[1]   = (add_adl)   ? q_add[1]   :
                  (dl_adl)    ? q_dl[1]    :
                  (pcl_adl)   ? q_pcl[1]   :
                  (s_adl)     ? q_s[1]     :
                  (zero_adl1) ? 1'b0       : 1'b1;
assign adl[0]   = (add_adl)   ? q_add[0]   :
                  (dl_adl)    ? q_dl[0]    :
                  (pcl_adl)   ? q_pcl[0]   :
                  (s_adl)     ? q_s[0]     :
                  (zero_adl0) ? 1'b0       : 1'b1;

assign db_in = 8'hFF & ({8{~ac_db}}  | q_ac)  &
                       ({8{~dl_db}}  | q_dl)  &
                       ({8{~p_db}}   | p)     &
                       ({8{~pch_db}} | q_pch) &
                       ({8{~pcl_db}} | q_pcl);

assign sb_in = 8'hFF & ({8{~ac_sb}}  | q_ac)  &
                       ({8{~add_sb}} | q_add) &
                       ({8{~s_sb}}   | q_s)   &
                       ({8{~x_sb}}   | q_x)   &
                       ({8{~y_sb}}   | q_y);

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
assign d_ac             = (sb_ac)           ? sb_out                        : q_ac;
assign d_x              = (sb_x)            ? sb_out                        : q_x;
assign d_y              = (sb_y)            ? sb_out                        : q_y;
assign d_c              = (acr_c)           ? acr                           :
                          (db0_c)           ? db_out[0]                     :
                          (ir5_c)           ? q_ir[5]                       : q_c;
assign d_d              = (db3_d)           ? db_out[3]                     :
                          (ir5_d)           ? q_ir[5]                       : q_d;
assign d_i              = (db2_i)           ? db_out[2]                     :
                          (ir5_i)           ? q_ir[5]                       : q_i;
assign d_n              = (db7_n)           ? db_out[7]                     : q_n;
assign d_v              = (avr_v)           ? avr                           :
                          (db6_v)           ? db_out[6]                     :
                          (zero_v)          ? 1'b0                          : q_v;
assign d_z              = (db1_z)           ? db_out[1]                     :
                          (dbz_z)           ? ~|db_out                      : q_z;
assign d_abh            = (adh_abh)         ? adh_out                       : q_abh;
assign d_abl            = (adl_abl)         ? adl                           : q_abl;
assign d_ai             = (sb_add)          ? sb_out                        :
                          (zero_add)        ? 8'h0                          : q_ai;
assign d_bi             = (adl_add)         ? adl                           :
                          (db_add)          ? db_out                        :
                          (invdb_add)       ? ~db_out                       : q_bi;
assign d_dl             = (r_nw_out)        ? d_in                          : q_dl;
assign d_dor            = db_out;
assign d_pd             = (r_nw_out)        ? d_in                          : q_pd;
assign d_s              = (sb_s)            ? sb_out                        : q_s;

assign d_pchs           = (adh_pch)         ? adh_out                       : q_pch;
assign d_pcls           = (adl_pcl)         ? adl                           : q_pcl;
assign { d_pch, d_pcl } = (i_pc)            ? { q_pchs, q_pcls } + 16'h0001 : { q_pchs, q_pcls };

// Combine full processor status register.
assign p = { q_n, q_v, 1'b1, (q_irq_sel == INTERRUPT_BRK), q_d, q_i, q_z, q_c };

//
// Assign output signals.
//
assign d_out = q_dor;
assign a_out = { q_abh, q_abl };

always @*
  begin
    case (dbgreg_sel_in)
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

