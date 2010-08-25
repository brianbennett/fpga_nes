///////////////////////////////////////////////////////////////////////////////////////////////////
// Module Name: dbg
//
// Author:      Brian Bennett (brian.k.bennett@gmail.com)
// Create Date: 08/09/2010
//
// Description:
// 
// Debugging module for an fpga-based NES emulator.  Accepts packets over a serial connection, 
// interacts with the rest of the hw system as specified, and returns the specified data.
//
///////////////////////////////////////////////////////////////////////////////////////////////////
module dbg
(
  input  wire        clk,        // 50MHz system clock signal
  input  wire        rst,        // reset signal
  input  wire        rx,         // rs-232 rx signal
  input  wire        cpumc_err,  // cpumc error signal
  inout  wire [ 7:0] cpu_d,      // CPU data bus (D)
  output wire        tx,         // rs-232 tx signal
  output reg         cpu_r_nw,   // CPU R/!W pin
  output wire [15:0] cpu_a       // CPU A bus (A)
);

// Debug packet opcodes.
localparam [7:0] OP_ECHO       = 8'h00,
                 OP_CPU_MEM_RD = 8'h01,
                 OP_CPU_MEM_WR = 8'h02;

// Error code bit positions.
localparam DBG_UART_PARITY_ERR = 0,
           DBG_UNKNOWN_OPCODE  = 1,
           DBG_INVALID_MEM_REQ = 2;

// Symbolic state representations.
localparam [2:0] S_DECODE           = 3'h0,
                 S_ECHO_STG_0       = 3'h1,
                 S_ECHO_STG_1       = 3'h2,
                 S_CPU_MEM_RD_STG_0 = 3'h3,
                 S_CPU_MEM_RD_STG_1 = 3'h4,
                 S_CPU_MEM_WR_STG_0 = 3'h5,
                 S_CPU_MEM_WR_STG_1 = 3'h6;

reg [ 2:0] q_state,       d_state;
reg [ 1:0] q_decode_cnt,  d_decode_cnt;
reg [16:0] q_execute_cnt, d_execute_cnt;
reg [15:0] q_addr,        d_addr;
reg [ 2:0] q_err_code,    d_err_code;

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
        q_state       <= S_DECODE;
        q_decode_cnt  <= 0;
        q_execute_cnt <= 0;
        q_addr        <= 16'h0000;
        q_err_code    <= 0;
        q_tx_data     <= 8'h00;
        q_wr_en       <= 1'b0;
      end
    else
      begin
        q_state       <= d_state;
        q_decode_cnt  <= d_decode_cnt;
        q_execute_cnt <= d_execute_cnt;
        q_addr        <= d_addr;
        q_err_code    <= d_err_code;
        q_tx_data     <= d_tx_data;
        q_wr_en       <= d_wr_en;
      end
  end

// Instantiate the serial controller block.
uart #(.BAUD_RATE(19200),
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
    d_state       = q_state;
    d_decode_cnt  = q_decode_cnt;
    d_execute_cnt = q_execute_cnt;
    d_addr        = q_addr;
    d_err_code    = q_err_code;

    rd_en         = 1'b0;
    d_tx_data     = 8'h00;
    d_wr_en       = 1'b0;

    cpu_r_nw      = 1'b1;

    if (parity_err)
      d_err_code[DBG_UART_PARITY_ERR] = 1'b1;

    if (cpumc_err)
      d_err_code[DBG_INVALID_MEM_REQ] = 1'b1;

    case (q_state)
      S_DECODE:
        begin
          if (!rx_empty)
            begin
              rd_en        = 1'b1;  // pop opcode off uart fifo
              d_decode_cnt = 0;     // start decode count at 0 for decode stage

              // Move to appropriate decode stage based on opcode.
              case (rd_data)
                OP_ECHO:       d_state = S_ECHO_STG_0;
                OP_CPU_MEM_RD: d_state = S_CPU_MEM_RD_STG_0;
                OP_CPU_MEM_WR: d_state = S_CPU_MEM_WR_STG_0;
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
              rd_en        = 1'b1;              // pop packet byte off uart fifo
              d_decode_cnt = q_decode_cnt + 1;  // advance to next decode stage
              if (q_decode_cnt == 0)
                begin
                  // Read CNT_LO into low bits of execute count.
                  d_execute_cnt = rd_data;
                end
              else
                begin
                  // Read CNT_HI into high bits of execute count.
                  d_execute_cnt = { rd_data, q_execute_cnt[7:0] };
                  d_state = S_ECHO_STG_1;
                end
            end
        end
      S_ECHO_STG_1:
        begin
          if (!rx_empty)
            begin
              rd_en         = 1'b1;               // pop packet byte off uart fifo
              d_execute_cnt = q_execute_cnt - 1;  // advance to next execute stage

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
              rd_en        = 1'b1;              // pop packet byte off uart fifo
              d_decode_cnt = q_decode_cnt + 1;  // advance to next decode stage
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
                  d_state = S_CPU_MEM_RD_STG_1;
                end
            end
        end
      S_CPU_MEM_RD_STG_1:
        begin
          if (~q_execute_cnt[0])
            begin
              // Dummy cycle.  Allow memory read 1 cycle to return result, and allow uart tx fifo
              // 1 cycle to update tx_full setting.
              d_execute_cnt = q_execute_cnt - 1;
            end
          else
            begin
              if (!tx_full)
                begin
                  d_execute_cnt = q_execute_cnt - 1;  // advance to next execute stage (read byte)
                  d_tx_data     = cpu_d;              // write data from cpu D bus
                  d_wr_en       = 1'b1;               // request uart write

                  d_addr = q_addr + 1;                // advance to next byte

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
              rd_en        = 1'b1;              // pop packet byte off uart fifo
              d_decode_cnt = q_decode_cnt + 1;  // advance to next decode stage
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
                  d_state = S_CPU_MEM_WR_STG_1;
                end
            end
        end
      S_CPU_MEM_WR_STG_1:
        begin
          if (!rx_empty)
            begin
              rd_en         = 1'b1;               // pop packet byte off uart fifo
              d_execute_cnt = q_execute_cnt - 1;  // advance to next execute stage (write byte)
              d_addr        = q_addr + 1;         // advance to next byte

              cpu_r_nw      = 1'b0;

              // After last byte is written to memory, return to decode stage.
              if (d_execute_cnt == 0)
                d_state = S_DECODE;
            end
        end
    endcase
  end

assign cpu_a = q_addr;
assign cpu_d = (cpu_r_nw) ? 8'bzzzzzzzz : rd_data;

endmodule

