///////////////////////////////////////////////////////////////////////////////////////////////////
// Module Name: cpumc
//
// Author:      Brian Bennett (brian.k.bennett@gmail.com)
// Create Date: 08/21/2010
//
// Description:
// 
// CPU Memory Controller.
//
///////////////////////////////////////////////////////////////////////////////////////////////////
module cpumc
(
  input  wire        clk,      // 50MHz system clock signal
  input  wire        rst,      // reset signal
  input  wire [ 7:0] cfg,      // cpumc mapper config
  input  wire        req,      // memory request is valid
  input  wire        wr,       // write enable signal
  input  wire        erase,    // erase enable signal
  input  wire [15:0] addr,     // 16-bit memory address
  input  wire [ 7:0] din,      // data input bus
  output reg  [ 7:0] dout,     // data output bus
  output wire        sf_rdy,   // flash ram ready for a new request

  inout  wire [ 7:0] sf_d,     // flash ram data bus
  output wire [23:0] sf_a,     // flash ram addr bus
  output wire        sf_byte,  // flash ram byte addressing enable
  output wire        sf_ce0,   // flash ram command bit
  output wire        sf_oe,    // flash ram command bit
  output wire        sf_we     // flash ram command bit
);

// CPU Memory Map
//   0x0000 - 0x1FFF RAM           (0x0800 - 0x1FFF mirrors 0x0000 - 0x07FF)
//   0x2000 - 0x401F I/O Regs      (0x2008 - 0x3FFF mirrors 0x2000 - 0x2007)
//   0x4020 - 0x5FFF Expansion ROM (currently unsupported)
//   0x6000 - 0x7FFF SRAM          (currently unsupported)
//   0x8000 - 0xBFFF PRG-ROM LO
//   0xC000 - 0xFFFF PRG-ROM HI

// Block ram instance for "RAM" memory range (0x0000 - 0x1FFF).  0x0800 - 0x1FFF mirrors
// 0x0000 - 0x07FF, so we only need 2048 bytes of physical block ram.

wire [10:0] ram_addr;
wire [ 7:0] ram_rd_data;
reg         ram_wr;

single_port_ram_sync #(.ADDR_WIDTH(11),
                       .DATA_WIDTH(8)) ram(
  .clk(clk),
  .we(ram_wr),
  .addr_a(ram_addr),
  .din_a(din),
  .dout_a(ram_rd_data)
);

assign ram_addr = addr[10:0];

// StrataFlash controller for PRG-ROM ranges.
wire        prgrom_req;
wire [ 1:0] prgrom_req_type;
wire [23:0] prgrom_addr;
wire [ 7:0] prgrom_rd_data;
reg         prgrom_wr;

sf_cntl prgrom(
  .clk(clk),
  .reset(rst),
  .req(prgrom_req),
  .req_type(prgrom_req_type),
  .addr(prgrom_addr),
  .wr_data(din),
  .rd_data(prgrom_rd_data),
  .rdy(sf_rdy),
  .sf_d(sf_d),
  .sf_a(sf_a),
  .sf_byte_n(sf_byte),
  .sf_ce0_n(sf_ce0),
  .sf_oe_n(sf_oe),
  .sf_we_n(sf_we)
);

assign prgrom_req      = (req && addr[15]);
assign prgrom_req_type = (erase)     ? 2'h2 :
                         (prgrom_wr) ? 2'h1 :
                                       2'h0;
assign prgrom_addr     = (cfg[0]) ? { 9'h000, addr[14:0] } : { 10'h000, addr[13:0] };

always @*
  begin
    dout      = 8'h00;
    ram_wr    = 1'b0;
    prgrom_wr = 1'b0;

    if (addr[15:13] == 0)
      begin
        // RAM range (0x0000 - 0x1FFF).
        dout   = ram_rd_data;
        ram_wr = wr;
      end
    else if (addr[15] == 1'b1)
      begin
        // PRG-ROM HI range (0xC000 - 0xFFFF).
        dout      = prgrom_rd_data;
        prgrom_wr = wr;
      end
  end

endmodule

