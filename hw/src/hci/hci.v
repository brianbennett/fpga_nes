/***************************************************************************************************
** fpga_nes/hw/src/hci/hci.v
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
*  Host communication interface.  Accepts packets over a serial connection, interacts with the rest
*  of the hw system as specified, and returns the specified data.
***************************************************************************************************/

module hci
(
  input  wire        clk,              // 100MHz system clock signal
  input  wire        rst,              // reset signal
  input  wire        rx,               // rs-232 rx signal
  input  wire        brk,              // signal for cpu-intiated debug break
  input  wire [ 7:0] cpu_din,          // cpu data bus (D) [input]
  input  wire [ 7:0] cpu_dbgreg_in,    // cpu debug register read bus
  input  wire [ 7:0] ppu_vram_din,     // ppu data bus [input]
  output wire        tx,               // rs-232 tx signal
  output wire        active,           // dbg block is active (disable CPU)
  output reg         cpu_r_nw,         // cpu R/!W pin
  output wire [15:0] cpu_a,            // cpu A bus (A)
  output reg  [ 7:0] cpu_dout,         // cpu data bus (D) [output]
  output reg  [ 3:0] cpu_dbgreg_sel,   // selects cpu register to read/write through cpu_dbgreg_in
  output reg  [ 7:0] cpu_dbgreg_out,   // cpu register write value for debug reg writes
  output reg         cpu_dbgreg_wr,    // selects cpu register read/write mode
  output reg         ppu_vram_wr,      // ppu memory write enable signal
  output wire [15:0] ppu_vram_a,       // ppu memory address
  output wire [ 7:0] ppu_vram_dout,    // ppu data bus [output]
  output wire [39:0] cart_cfg,         // cartridge config data (from iNES header)
  output wire        cart_cfg_upd      // pulse on cart_cfg update so cart can reset
);

// Debug packet opcodes.
localparam [7:0] OP_ECHO                 = 8'h00,
                 OP_CPU_MEM_RD           = 8'h01,
                 OP_CPU_MEM_WR           = 8'h02,
                 OP_DBG_BRK              = 8'h03,
                 OP_DBG_RUN              = 8'h04,
                 OP_CPU_REG_RD           = 8'h05,
                 OP_CPU_REG_WR           = 8'h06,
                 OP_QUERY_DBG_BRK        = 8'h07,
                 OP_QUERY_ERR_CODE       = 8'h08,
                 OP_PPU_MEM_RD           = 8'h09,
                 OP_PPU_MEM_WR           = 8'h0A,
                 OP_PPU_DISABLE          = 8'h0B,
                 OP_CART_SET_CFG         = 8'h0C;

// Error code bit positions.
localparam DBG_UART_PARITY_ERR = 0,
           DBG_UNKNOWN_OPCODE  = 1;

// Symbolic state representations.
localparam [4:0] S_DISABLED             = 5'h00,
                 S_DECODE               = 5'h01,
                 S_ECHO_STG_0           = 5'h02,
                 S_ECHO_STG_1           = 5'h03,
                 S_CPU_MEM_RD_STG_0     = 5'h04,
                 S_CPU_MEM_RD_STG_1     = 5'h05,
                 S_CPU_MEM_WR_STG_0     = 5'h06,
                 S_CPU_MEM_WR_STG_1     = 5'h07,
                 S_CPU_REG_RD           = 5'h08,
                 S_CPU_REG_WR_STG_0     = 5'h09,
                 S_CPU_REG_WR_STG_1     = 5'h0A,
                 S_QUERY_ERR_CODE       = 5'h0B,
                 S_PPU_MEM_RD_STG_0     = 5'h0C,
                 S_PPU_MEM_RD_STG_1     = 5'h0D,
                 S_PPU_MEM_WR_STG_0     = 5'h0E,
                 S_PPU_MEM_WR_STG_1     = 5'h0F,
                 S_PPU_DISABLE          = 5'h10,
                 S_CART_SET_CFG_STG_0   = 5'h11,
                 S_CART_SET_CFG_STG_1   = 5'h12;

reg [ 4:0] q_state,            d_state;
reg [ 2:0] q_decode_cnt,       d_decode_cnt;
reg [16:0] q_execute_cnt,      d_execute_cnt;
reg [15:0] q_addr,             d_addr;
reg [ 1:0] q_err_code,         d_err_code;
reg [39:0] q_cart_cfg,         d_cart_cfg;
reg        q_cart_cfg_upd,     d_cart_cfg_upd;

// UART output buffer FFs.
reg  [7:0] q_tx_data, d_tx_data;
reg        q_wr_en,   d_wr_en;

// UART input signals.
reg        rd_en;
wire [7:0] rd_data;
wire       rx_empty;
wire       tx_full;
wire       parity_err;

// Update FF state.
always @(posedge clk)
  begin
    if (rst)
      begin
        q_state            <= S_DECODE;
        q_decode_cnt       <= 0;
        q_execute_cnt      <= 0;
        q_addr             <= 16'h0000;
        q_err_code         <= 0;
        q_cart_cfg         <= 40'h0000000000;
        q_cart_cfg_upd     <= 1'b0;
        q_tx_data          <= 8'h00;
        q_wr_en            <= 1'b0;
      end
    else
      begin
        q_state            <= d_state;
        q_decode_cnt       <= d_decode_cnt;
        q_execute_cnt      <= d_execute_cnt;
        q_addr             <= d_addr;
        q_err_code         <= d_err_code;
        q_cart_cfg         <= d_cart_cfg;
        q_cart_cfg_upd     <= d_cart_cfg_upd;
        q_tx_data          <= d_tx_data;
        q_wr_en            <= d_wr_en;
      end
  end

// Instantiate the serial controller block.
uart #(.SYS_CLK_FREQ(100000000),
       .BAUD_RATE(38400),
       .DATA_BITS(8),
       .STOP_BITS(1),
       .PARITY_MODE(1)) uart_blk
(
  .clk(clk),
  .reset(rst),
  .rx(rx),
  .tx_data(q_tx_data),
  .rd_en(rd_en),
  .wr_en(q_wr_en),
  .tx(tx),
  .rx_data(rd_data),
  .rx_empty(rx_empty),
  .tx_full(tx_full),
  .parity_err(parity_err)
);

always @*
  begin
    // Setup default FF updates.
    d_state        = q_state;
    d_decode_cnt   = q_decode_cnt;
    d_execute_cnt  = q_execute_cnt;
    d_addr         = q_addr;
    d_err_code     = q_err_code;
    d_cart_cfg     = q_cart_cfg;
    d_cart_cfg_upd = 1'b0;

    rd_en         = 1'b0;
    d_tx_data     = 8'h00;
    d_wr_en       = 1'b0;

    // Setup default output regs.
    cpu_r_nw       = 1'b1;
    cpu_dout       = rd_data;
    cpu_dbgreg_sel = 0;
    cpu_dbgreg_out = 0;
    cpu_dbgreg_wr  = 1'b0;
    ppu_vram_wr    = 1'b0;

    if (parity_err)
      d_err_code[DBG_UART_PARITY_ERR] = 1'b1;

    case (q_state)
      S_DISABLED:
        begin
          if (brk)
            begin
              // Received CPU initiated break.  Begin active debugging.
              d_state   = S_DECODE;
            end
          else if (!rx_empty)
            begin
              rd_en = 1'b1;  // pop opcode off uart fifo

              if (rd_data == OP_DBG_BRK)
                begin
                  d_state = S_DECODE;
                end
              else if (rd_data == OP_QUERY_DBG_BRK)
                begin
                  d_tx_data = 8'h00;  // Write "0" over UART to indicate we are not in a debug break
                  d_wr_en   = 1'b1;
                end
            end
        end
      S_DECODE:
        begin
          if (!rx_empty)
            begin
              rd_en        = 1'b1;  // pop opcode off uart fifo
              d_decode_cnt = 0;     // start decode count at 0 for decode stage

              // Move to appropriate decode stage based on opcode.
              case (rd_data)
                OP_ECHO:                 d_state = S_ECHO_STG_0;
                OP_CPU_MEM_RD:           d_state = S_CPU_MEM_RD_STG_0;
                OP_CPU_MEM_WR:           d_state = S_CPU_MEM_WR_STG_0;
                OP_DBG_BRK:              d_state = S_DECODE;
                OP_CPU_REG_RD:           d_state = S_CPU_REG_RD;
                OP_CPU_REG_WR:           d_state = S_CPU_REG_WR_STG_0;
                OP_QUERY_ERR_CODE:       d_state = S_QUERY_ERR_CODE;
                OP_PPU_MEM_RD:           d_state = S_PPU_MEM_RD_STG_0;
                OP_PPU_MEM_WR:           d_state = S_PPU_MEM_WR_STG_0;
                OP_PPU_DISABLE:          d_state = S_PPU_DISABLE;
                OP_CART_SET_CFG:         d_state = S_CART_SET_CFG_STG_0;
                OP_DBG_RUN:
                  begin
                    d_state = S_DISABLED;
                  end
                OP_QUERY_DBG_BRK:
                  begin
                    d_tx_data = 8'h01;  // Write "1" over UART to indicate we are in a debug break
                    d_wr_en   = 1'b1;
                  end
                default:
                  begin
                    // Invalid opcode.  Ignore, but set error code.
                    d_err_code[DBG_UNKNOWN_OPCODE] = 1'b1;
                    d_state = S_DECODE;
                  end
              endcase
            end
        end

      // --- ECHO ---
      //   OP_CODE
      //   CNT_LO
      //   CNT_HI
      //   DATA
      S_ECHO_STG_0:
        begin
          if (!rx_empty)
            begin
              rd_en        = 1'b1;                 // pop packet byte off uart fifo
              d_decode_cnt = q_decode_cnt + 3'h1;  // advance to next decode stage
              if (q_decode_cnt == 0)
                begin
                  // Read CNT_LO into low bits of execute count.
                  d_execute_cnt = rd_data;
                end
              else
                begin
                  // Read CNT_HI into high bits of execute count.
                  d_execute_cnt = { rd_data, q_execute_cnt[7:0] };
                  d_state = (d_execute_cnt) ? S_ECHO_STG_1 : S_DECODE;
                end
            end
        end
      S_ECHO_STG_1:
        begin
          if (!rx_empty)
            begin
              rd_en         = 1'b1;                       // pop packet byte off uart fifo
              d_execute_cnt = q_execute_cnt - 17'h00001;  // advance to next execute stage

              // Echo packet DATA byte over uart.
              d_tx_data = rd_data;
              d_wr_en   = 1'b1;

              // After last byte of packet, return to decode stage.
              if (d_execute_cnt == 0)
                d_state = S_DECODE;
            end
        end

      // --- CPU_MEM_RD ---
      //   OP_CODE
      //   ADDR_LO
      //   ADDR_HI
      //   CNT_LO
      //   CNT_HI
      S_CPU_MEM_RD_STG_0:
        begin
          if (!rx_empty)
            begin
              rd_en        = 1'b1;                 // pop packet byte off uart fifo
              d_decode_cnt = q_decode_cnt + 3'h1;  // advance to next decode stage
              if (q_decode_cnt == 0)
                begin
                  // Read ADDR_LO into low bits of addr.
                  d_addr = rd_data;
                end
              else if (q_decode_cnt == 1)
                begin
                  // Read ADDR_HI into high bits of addr.
                  d_addr = { rd_data, q_addr[7:0] };
                end
              else if (q_decode_cnt == 2)
                begin
                  // Read CNT_LO into low bits of execute count.
                  d_execute_cnt = rd_data;
                end
              else
                begin
                  // Read CNT_HI into high bits of execute count.  Execute count is shifted by 1:
                  // use 2 clock cycles per byte read.
                  d_execute_cnt = { rd_data, q_execute_cnt[7:0], 1'b0 };
                  d_state = (d_execute_cnt) ? S_CPU_MEM_RD_STG_1 : S_DECODE;
                end
            end
        end
      S_CPU_MEM_RD_STG_1:
        begin
          if (~q_execute_cnt[0])
            begin
              // Dummy cycle.  Allow memory read 1 cycle to return result, and allow uart tx fifo
              // 1 cycle to update tx_full setting.
              d_execute_cnt = q_execute_cnt - 17'h00001;
            end
          else
            begin
              if (!tx_full)
                begin
                  d_execute_cnt = q_execute_cnt - 17'h00001;  // advance to next execute stage
                  d_tx_data     = cpu_din;                    // write data from cpu D bus
                  d_wr_en       = 1'b1;                       // request uart write

                  d_addr = q_addr + 16'h0001;                 // advance to next byte

                  // After last byte is written to uart, return to decode stage.
                  if (d_execute_cnt == 0)
                    d_state = S_DECODE;
                end
            end
        end

      // --- CPU_MEM_WR ---
      //   OP_CODE
      //   ADDR_LO
      //   ADDR_HI
      //   CNT_LO
      //   CNT_HI
      //   DATA
      S_CPU_MEM_WR_STG_0:
        begin
          if (!rx_empty)
            begin
              rd_en        = 1'b1;                 // pop packet byte off uart fifo
              d_decode_cnt = q_decode_cnt + 3'h1;  // advance to next decode stage
              if (q_decode_cnt == 0)
                begin
                  // Read ADDR_LO into low bits of addr.
                  d_addr = rd_data;
                end
              else if (q_decode_cnt == 1)
                begin
                  // Read ADDR_HI into high bits of addr.
                  d_addr = { rd_data, q_addr[7:0] };
                end
              else if (q_decode_cnt == 2)
                begin
                  // Read CNT_LO into low bits of execute count.
                  d_execute_cnt = rd_data;
                end
              else
                begin
                  // Read CNT_HI into high bits of execute count.
                  d_execute_cnt = { rd_data, q_execute_cnt[7:0] };
                  d_state = (d_execute_cnt) ? S_CPU_MEM_WR_STG_1 : S_DECODE;
                end
            end
        end
      S_CPU_MEM_WR_STG_1:
        begin
          if (!rx_empty)
            begin
              rd_en         = 1'b1;                       // pop packet byte off uart fifo
              d_execute_cnt = q_execute_cnt - 17'h00001;  // advance to next execute stage
              d_addr        = q_addr + 16'h0001;          // advance to next byte

              cpu_r_nw      = 1'b0;

              // After last byte is written to memory, return to decode stage.
              if (d_execute_cnt == 0)
                d_state = S_DECODE;
            end
        end

      // --- CPU_REG_RD ---
      //   OP_CODE
      //   REG_SEL
      S_CPU_REG_RD:
        begin
          if (!rx_empty && !tx_full)
            begin
              rd_en          = 1'b1;           // pop REG_SEL byte off uart fifo
              cpu_dbgreg_sel = rd_data[3:0];   // select CPU reg based on REG_SEL
              d_tx_data      = cpu_dbgreg_in;  // send reg read results to uart
              d_wr_en        = 1'b1;           // request uart write

              d_state = S_DECODE;
            end
        end

      // --- CPU_REG_WR ---
      //   OP_CODE
      //   REG_SEL
      //   DATA
      S_CPU_REG_WR_STG_0:
        begin
          if (!rx_empty)
            begin
              rd_en   = 1'b1;
              d_addr  = rd_data;
              d_state = S_CPU_REG_WR_STG_1;
            end
        end
      S_CPU_REG_WR_STG_1:
        begin
          if (!rx_empty)
            begin
              rd_en          = 1'b1;
              cpu_dbgreg_sel = q_addr[3:0];
              cpu_dbgreg_wr  = 1'b1;
              cpu_dbgreg_out = rd_data;
              d_state        = S_DECODE;
            end
        end

      // --- QUERY_ERR_CODE ---
      //   OP_CODE
      S_QUERY_ERR_CODE:
        begin
          if (!tx_full)
            begin
              d_tx_data = q_err_code; // write current error code
              d_wr_en   = 1'b1;       // request uart write
              d_state   = S_DECODE;
            end
        end

      // --- PPU_MEM_RD ---
      //   OP_CODE
      //   ADDR_LO
      //   ADDR_HI
      //   CNT_LO
      //   CNT_HI
      S_PPU_MEM_RD_STG_0:
        begin
          if (!rx_empty)
            begin
              rd_en        = 1'b1;                 // pop packet byte off uart fifo
              d_decode_cnt = q_decode_cnt + 3'h1;  // advance to next decode stage
              if (q_decode_cnt == 0)
                begin
                  // Read ADDR_LO into low bits of addr.
                  d_addr = rd_data;
                end
              else if (q_decode_cnt == 1)
                begin
                  // Read ADDR_HI into high bits of addr.
                  d_addr = { rd_data, q_addr[7:0] };
                end
              else if (q_decode_cnt == 2)
                begin
                  // Read CNT_LO into low bits of execute count.
                  d_execute_cnt = rd_data;
                end
              else
                begin
                  // Read CNT_HI into high bits of execute count.  Execute count is shifted by 1:
                  // use 2 clock cycles per byte read.
                  d_execute_cnt = { rd_data, q_execute_cnt[7:0], 1'b0 };
                  d_state = (d_execute_cnt) ? S_PPU_MEM_RD_STG_1 : S_DECODE;
                end
            end
        end
      S_PPU_MEM_RD_STG_1:
        begin
          if (~q_execute_cnt[0])
            begin
              // Dummy cycle.  Allow memory read 1 cycle to return result, and allow uart tx fifo
              // 1 cycle to update tx_full setting.
              d_execute_cnt = q_execute_cnt - 17'h00001;
            end
          else
            begin
              if (!tx_full)
                begin
                  d_execute_cnt = q_execute_cnt - 17'h00001;  // advance to next execute stage
                  d_tx_data     = ppu_vram_din;               // write data from ppu D bus
                  d_wr_en       = 1'b1;                       // request uart write

                  d_addr = q_addr + 16'h0001;                 // advance to next byte

                  // After last byte is written to uart, return to decode stage.
                  if (d_execute_cnt == 0)
                    d_state = S_DECODE;
                end
            end
        end

      // --- PPU_MEM_WR ---
      //   OP_CODE
      //   ADDR_LO
      //   ADDR_HI
      //   CNT_LO
      //   CNT_HI
      //   DATA
      S_PPU_MEM_WR_STG_0:
        begin
          if (!rx_empty)
            begin
              rd_en        = 1'b1;                 // pop packet byte off uart fifo
              d_decode_cnt = q_decode_cnt + 3'h1;  // advance to next decode stage
              if (q_decode_cnt == 0)
                begin
                  // Read ADDR_LO into low bits of addr.
                  d_addr = rd_data;
                end
              else if (q_decode_cnt == 1)
                begin
                  // Read ADDR_HI into high bits of addr.
                  d_addr = { rd_data, q_addr[7:0] };
                end
              else if (q_decode_cnt == 2)
                begin
                  // Read CNT_LO into low bits of execute count.
                  d_execute_cnt = rd_data;
                end
              else
                begin
                  // Read CNT_HI into high bits of execute count.
                  d_execute_cnt = { rd_data, q_execute_cnt[7:0] };
                  d_state = (d_execute_cnt) ? S_PPU_MEM_WR_STG_1 : S_DECODE;
                end
            end
        end
      S_PPU_MEM_WR_STG_1:
        begin
          if (!rx_empty)
            begin
              rd_en         = 1'b1;                       // pop packet byte off uart fifo
              d_execute_cnt = q_execute_cnt - 17'h00001;  // advance to next execute stage
              d_addr        = q_addr + 16'h0001;          // advance to next byte

              ppu_vram_wr   = 1'b1;

              // After last byte is written to memory, return to decode stage.
              if (d_execute_cnt == 0)
                d_state = S_DECODE;
            end
        end

      // --- PPU_DISABLE ---
      //   OP_CODE
      S_PPU_DISABLE:
        begin
          d_decode_cnt = q_decode_cnt + 3'h1;  // advance to next decode stage

          if (q_decode_cnt == 0)
            begin
              d_addr = 16'h2000;
            end
          else if (q_decode_cnt == 1)
            begin
              // Write 0x2000 to 0.
              cpu_r_nw = 1'b0;
              cpu_dout = 8'h00;

              // Set addr to 0x0000 for one cycle (due to PPU quirk only recognizing register
              // interface reads/writes when address bits [15-13] change from 3'b001 from another
              // value.
              d_addr   = 16'h0000;
            end
          else if (q_decode_cnt == 2)
            begin
              d_addr = 16'h2001;
            end
          else if (q_decode_cnt == 3)
            begin
              // Write 0x2000 to 0.
              cpu_r_nw = 1'b0;
              cpu_dout = 8'h00;

              // Set addr to 0x0000 for one cycle (due to PPU quirk only recognizing register
              // interface reads/writes when address bits [15-13] change from 3'b001 from another
              // value.
              d_addr   = 16'h0000;
            end
          else if (q_decode_cnt == 4)
            begin
              d_addr = 16'h2002;
            end
          else if (q_decode_cnt == 5)
            begin
              // Read 0x2002 to reset PPU byte pointer.
              d_addr  = 16'h0000;
              d_state = S_DECODE;
            end
        end

      // --- CART_SET_CFG ---
      //   OP_CODE
      //   iNES byte 4 (16KB PRG-ROM bank count)
      //   iNES byte 5 (8KB CHR-ROM bank count)
      //   iNES byte 6 (ROM Control Byte 1)
      //   iNES byte 7 (ROM Control Byte 2)
      //   iNES byte 8 (8KB RAM bank count)
      S_CART_SET_CFG_STG_0:
        begin
          d_execute_cnt = 16'h0004;
          d_state       = S_CART_SET_CFG_STG_1;
        end
      S_CART_SET_CFG_STG_1:
        begin
          if (!rx_empty)
            begin
              rd_en         = 1'b1;                       // pop packet byte off uart fifo
              d_execute_cnt = q_execute_cnt - 17'h00001;  // advance to next execute stage

              d_cart_cfg = { q_cart_cfg[31:0], rd_data };

              // After last byte of packet, return to decode stage.
              if (q_execute_cnt == 0)
                begin
                  d_state        = S_DECODE;
                  d_cart_cfg_upd = 1'b1;
                end
            end
        end
    endcase
  end

assign cpu_a            = q_addr;
assign active           = (q_state != S_DISABLED);
assign ppu_vram_a       = q_addr;
assign ppu_vram_dout    = rd_data;
assign cart_cfg         = q_cart_cfg;
assign cart_cfg_upd     = q_cart_cfg_upd;

endmodule

