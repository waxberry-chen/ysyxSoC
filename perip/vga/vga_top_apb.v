module vga_top_apb(
  input         clock,
  input         reset,
  input  [31:0] in_paddr,
  input         in_psel,
  input         in_penable,
  input  [2:0]  in_pprot,
  input         in_pwrite,
  input  [31:0] in_pwdata,
  input  [3:0]  in_pstrb,
  output        in_pready,
  output [31:0] in_prdata,
  output        in_pslverr,

  output [7:0]  vga_r,
  output [7:0]  vga_g,
  output [7:0]  vga_b,
  output        vga_hsync,
  output        vga_vsync,
  output        vga_valid
);

// Explicitly disabled peripheral for the NPC integration profile.
// Deterministic APB error and benign external outputs; no device functionality.
assign in_pready = in_psel && in_penable;
assign in_prdata = 32'b0;
assign in_pslverr = 1'b1;
assign vga_r = 0;
assign vga_g = 0;
assign vga_b = 0;
assign vga_hsync = 1;
assign vga_vsync = 1;
assign vga_valid = 0;

endmodule
