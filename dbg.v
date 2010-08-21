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
  input  wire clk,  // 50MHz system clock signal
  input  wire rst,  // reset signal
  input  wire rx,   // rs-232 rx signal
  output wire tx    // rs-232 tx signal
);

// Debug packet opcodes.
localparam [7:0] OP_ECHO = 8'h00;

// Error code bit positions.
localparam DBG_UART_PARITY_ERR = 1'b0,
           DBG_UNKNOWN_OPCODE  = 1'b1;

// Symbolic state representations.
localparam [1:0] S_DECODE      = 2'h0,
                 S_ECHO_STG_0  = 2'h1,
                 S_ECHO_STG_1  = 2'h2;

reg [ 1:0] q_state,       d_state;
reg        q_decode_cnt,  d_decode_cnt;
reg [15:0] q_execute_cnt, d_execute_cnt;
reg [ 1:0] q_err_code,    d_err_code;

// UART output buffer FFs.
reg  [7:0] q_tx_data, d_tx_data;
reg        q_wr_en,   d_wr_en;

// UART input signals.
reg        rd_en;
wire [7:0] rd_data;
wire       rx_empty;
wire       parity_err;

// Update FF state.
always @(posedge clk)
  begin
    if (rst)
      begin
        q_state       <= S_DECODE;
        q_decode_cnt  <= 1'h0;
        q_execute_cnt <= 16'h0000;
        q_tx_data     <= 8'h00;
        q_wr_en       <= 1'b0;
        q_err_code    <= 2'b0;
      end
    else
      begin
        q_state       <= d_state;
        q_decode_cnt  <= d_decode_cnt;
        q_execute_cnt <= d_execute_cnt;
        q_tx_data     <= d_tx_data;
        q_wr_en       <= d_wr_en;
        q_err_code    <= d_err_code;
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
  .parity_err(parity_err)
);

always @*
  begin
    // Setup default FF updates.
    d_state       = q_state;
    d_decode_cnt  = q_decode_cnt;
    d_execute_cnt = q_execute_cnt;
    d_err_code    = q_err_code;

    rd_en         = 1'b0;
    d_tx_data     = 8'h00;
    d_wr_en       = 1'b0;

    if (parity_err)
      d_err_code[DBG_UART_PARITY_ERR] = 1'b1;

    case (q_state)
      S_DECODE:
        begin
          if (!rx_empty)
            begin
              rd_en        = 1'b1;
              d_decode_cnt = 0;
              case (rd_data)
                OP_ECHO: d_state = S_ECHO_STG_0;
                default: 
                  begin
                    d_err_code[DBG_UNKNOWN_OPCODE] = 1'b1;
                    d_state = S_DECODE;
                  end
              endcase
            end
        end
      S_ECHO_STG_0:
        begin
          if (!rx_empty)
            begin
              rd_en        = 1'b1;
              d_decode_cnt = q_decode_cnt + 1;
              if (q_decode_cnt == 0)
                begin
                  d_execute_cnt = rd_data;
                end
              else
                begin
                  d_execute_cnt = { rd_data, q_execute_cnt[7:0] };
                  d_state = S_ECHO_STG_1;
                end
            end
        end
      S_ECHO_STG_1:
        begin
          if (!rx_empty)
            begin
              rd_en         = 1'b1;
              d_execute_cnt = q_execute_cnt - 1;

              d_tx_data = rd_data;
              d_wr_en   = 1'b1;

              if (d_execute_cnt == 0)
                d_state = S_DECODE;
            end
        end
    endcase 
  end

endmodule

