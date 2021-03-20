`timescale 1 ns/1 ns  // time-unit = 1 ns, precision = 10 ps

module LEDPanelTest;
  localparam ms = 1e6;
  localparam us = 1e3;

  reg           clk = 0;
  reg           reset = 0;
  reg           ctrl_clk = 0;

  reg           ctrl_en = 0;
  reg   [3:0]   ctrl_wr = 0;          // Which color memory block to write
  reg   [15:0]  ctrl_addr = 0;        // Addr to write color info on [col_info][row_info]
  reg   [23:0]  ctrl_wdat = 0;        // Data to be written [R][G][B]
  wire display_clock;

  assign display_clock = clk;
  wire          panel_r0, panel_g0, panel_b0, panel_r1, panel_g1, panel_b1;
  wire          panel_a, panel_b, panel_c, panel_d, panel_e, panel_clk, panel_stb, panel_oe;

  ledpanel panel(
    reset,
    ctrl_clk,
    ctrl_en,
    ctrl_wr,
    ctrl_addr,
    ctrl_wdat,

    clk,
    panel_r0, panel_g0, panel_b0, panel_r1, panel_g1, panel_b1,
    panel_a, panel_b, panel_c, panel_d, panel_e, panel_clk, panel_stb, panel_oe
  );

  initial begin
    $dumpfile("ledpanel.vcd");
    $dumpvars(0, LEDPanelTest);
    
    reset = 1;
    ctrl_clk = 0;
    ctrl_en = 0;
    ctrl_wr = 0;
    ctrl_addr = 0;
    ctrl_wdat = 0;

    repeat(8)
    begin
      #10
      clk = 1;
      #10
      clk = 0;
    end
    reset = 0;

    repeat(16384)
    begin
      #10
      clk = 1;
      #10
      clk = 0;
    end

  end
endmodule