// Description of the LED panel:
// http://bikerglen.com/projects/lighting/led-panel-1up/#The_LED_Panel
//
// PANEL_[ABCD] ... select rows (in pairs from top and bottom half)
// PANEL_OE ....... display the selected rows (active low)
// PANEL_CLK ...... serial clock for color data
// PANEL_STB ...... latch shifted data (active high)
// PANEL_[RGB]0 ... color channel for top half
// PANEL_[RGB]1 ... color channel for bottom half
// taken from http://svn.clifford.at/handicraft/2015/c3demo/fpga/ledpanel.v
// modified by Niklas Fauth 2020

`default_nettype none
module ledpanel (
  input wire reset,
  input wire ctrl_clk,

	input wire ctrl_en,
	input wire [3:0] ctrl_wr,           // Which color memory block to write
	input wire [15:0] ctrl_addr,        // Addr to write color info on [col_info][row_info]
	input wire [23:0] ctrl_wdat,        // Data to be written [R][G][B]

	input wire display_clock,
	output reg panel_r0, panel_g0, panel_b0, panel_r1, panel_g1, panel_b1,
	output reg panel_a, panel_b, panel_c, panel_d, panel_e, panel_clk, panel_stb, panel_oe
);

  parameter integer INPUT_DEPTH          = 6;    // bits of color before gamma correction
  parameter integer COLOR_DEPTH          = 7;    // bits of color after gamma correction
  parameter integer CHAINED              = 2;    // number of panels in chain

  localparam integer SIZE_BITS = $clog2(CHAINED);

  reg [COLOR_DEPTH-1:0] video_mem_r [0:CHAINED*4096-1];
	reg [COLOR_DEPTH-1:0] video_mem_g [0:CHAINED*4096-1];
	reg [COLOR_DEPTH-1:0] video_mem_b [0:CHAINED*4096-1];

  reg [COLOR_DEPTH-1:0] gamma_mem   [0:2**COLOR_DEPTH-1];

  initial begin:video_mem_init
        panel_a <= 0;
        panel_b <= 0;
        panel_c <= 0;
        panel_d <= 0;
				panel_e <= 0;

				$readmemh("6bit_to_7bit_gamma.mem",gamma_mem);

        $readmemh("red.mem",video_mem_r);
        $readmemh("green.mem",video_mem_g);
        $readmemh("blue.mem",video_mem_b);
	end

  always @(posedge ctrl_clk) begin
		if (ctrl_en && ctrl_wr[2]) video_mem_r[ctrl_addr] <= ctrl_wdat[16+INPUT_DEPTH-1:16];
		if (ctrl_en && ctrl_wr[1]) video_mem_g[ctrl_addr] <= ctrl_wdat[8+INPUT_DEPTH-1:8];
		if (ctrl_en && ctrl_wr[0]) video_mem_b[ctrl_addr] <= ctrl_wdat[0+INPUT_DEPTH-1:0];
	end

	reg [5+COLOR_DEPTH+SIZE_BITS:0] cnt_x = 0;
	reg [4:0]                       cnt_y = 0;
	reg [2:0]                       cnt_z = 0;
	reg state = 0;


  // State machine.
  localparam
      S_START   =  0,
      S_R1      =  1,
      S_R1C     =  2,
      S_R1E     =  3,
      S_R2      =  4,
      S_R2C     =  5,
      S_R2E     =  6,
      S_R3      =  7,
      S_R3C     =  8,
      S_R3E     =  9,
      S_WORK    = 10;
  // FM6126 Init Values

  localparam MAX_LED   = CHAINED * 64;
  localparam FM_R1     = 16'b1111111111001110; // 2'b1111111111001110; // 16'h7FFF; 2'b0111001111111111
  localparam FM_R2     = 16'b1110000001100010; // 2'b1110000001100010; // 16'h0040; 2'b0100011000000111
  localparam FM_R3     = 16'b0101111100000000; // 2'b0101111100000000;              2'b0000000011111010

  localparam REG_11    = MAX_LED-11;
  localparam REG_12    = MAX_LED-12;
  localparam REG_13    = MAX_LED-13;

  reg [4:0] cstate = S_START;
  reg [15:0] frames;

  wire WorkMode = cstate == S_WORK;

	reg [5+SIZE_BITS:0] addr_x;
	reg [5:0]           addr_y;
	reg [2:0]           addr_z;
	reg [2:0]           data_rgb;
	reg [2:0]           data_rgb_q;
	reg [5+COLOR_DEPTH+SIZE_BITS:0] max_cnt_x;
  reg [15:0]                      init_reg;

  reg [3:0] initClockDivider = 0;

  // wire initClock = initClockDivider[3]; // Divide by four
  wire initClock = display_clock; // initClockDivider[3]; // Divide by four

  always @(posedge display_clock) begin
    initClockDivider <= reset ? 0 : initClockDivider + 1;
  end

  reg [15:0] bitCount;
  reg initOe;
  reg initClk;
  reg initStb;
  reg outBit;
  // Init routine
  always @(posedge initClock)
  begin
    if (reset)
    begin
      bitCount <= 0;
      cstate   <= S_START;
      initOe   <= 0;
      initClk  <= 0;
      initStb  <= 0;
      outBit   <= 0;
    end
    else
    begin
      case (cstate)
        S_START:
          begin
            initStb   <= 0;
            initOe    <= 1;
            initClk   <= 0;
            bitCount  <= 0;
            // Setup FM6126/7 init
            init_reg  <= FM_R1;
            cstate    <= S_R1;
          end
        S_R1:
          begin
            outBit    <= init_reg[15];
            init_reg  <= {init_reg[14:0], init_reg[15]};
            initStb   <= bitCount > REG_12;
            initClk   <= 0;
            bitCount  <= bitCount + 1;

            if (bitCount == MAX_LED)
              cstate  <= S_R1E;
            else
              cstate  <= S_R1C;
          end
        S_R1C:
          begin
            initClk   <= 1;
            cstate    <= S_R1;
          end
        S_R1E:
          begin
            init_reg  <= FM_R2;
            cstate    <= S_R2;
            initStb   <= 0;
            initClk   <= 0;
            bitCount  <= 0;
            outBit    <= 0;
          end
        S_R2:
          begin
            outBit    <= init_reg[15];
            init_reg  <= {init_reg[14:0], init_reg[15]};
            initStb   <= bitCount > REG_13;
            initClk   <= 0;
            bitCount  <= bitCount + 1;

            if (bitCount == MAX_LED)
              cstate  <= S_R2E;
            else
              cstate  <= S_R2C;
          end
        S_R2C:
          begin
            initClk   <= 1;
            cstate    <= S_R2;
          end
        S_R2E:
          begin
            initStb   <= 0;
            initClk   <= 0;
            bitCount  <= 0;
            init_reg  <= FM_R3;
            cstate    <= S_R3;
            outBit    <= 0;
            // cstate    <= S_WORK;
          end
        S_R3:
          begin
            outBit    <= init_reg[15];
            init_reg  <= {init_reg[14:0], init_reg[15]};
            initStb   <= bitCount > REG_11;
            initClk   <= 0;
            bitCount  <= bitCount + 1;

            if (bitCount == MAX_LED)
              cstate  <= S_R3E;
            else
              cstate  <= S_R3C;
          end
        S_R3C:
          begin
            initClk   <= 1;
            cstate    <= S_R3;
          end
        S_R3E:
          begin
            initStb   <= 0;
            initClk   <= 0;
            bitCount  <= 0;
            outBit    <= 0;
            cstate    <= S_WORK;
          end
        S_WORK:
          begin
            if (frames == 8192)
            begin
              bitCount <= 0;
              cstate   <= S_START;
              initOe   <= 0;
              initClk  <= 0;
              initStb  <= 0;
              outBit   <= 0;
            end
          end
      endcase
    end
  end

  // PWM Counter
	always @(posedge display_clock) begin
    if (WorkMode) begin
  		case (cnt_z)
        0: max_cnt_x = 64*CHAINED+8;
        1: max_cnt_x = 128*CHAINED;
        2: max_cnt_x = 256*CHAINED;
        3: max_cnt_x = 512*CHAINED;
        4: max_cnt_x = 1024*CHAINED;
        5: max_cnt_x = 2048*CHAINED;
        6: max_cnt_x = 4096*CHAINED;
        7: max_cnt_x = 8192*CHAINED;
  		endcase
    end
	end

  // Position Counters
	always @(posedge display_clock) begin
    if (reset) begin
      state  <= 0;
      cnt_x  <= 0;
      cnt_z  <= 0;
      cnt_y  <= 0;
      frames <= 0;
    end
    else if (WorkMode) begin
      state <= !state;
      if (!state) begin
        if (cnt_x > max_cnt_x) begin
          cnt_x <= 0;
          cnt_z <= cnt_z + 1;
          if (cnt_z == COLOR_DEPTH-1) begin
            cnt_y <= cnt_y + 1;
            cnt_z <= 0;
          end
        end else begin
          cnt_x <= cnt_x + 1;
        end

        if (cnt_y == 0 && cnt_x == 0 && cnt_z == 0)
        begin
          frames <= frames + 1;
        end
      end
    end
    else
      frames <= 0;
	end

	always @(posedge display_clock) begin
    if (reset) begin
      panel_stb <= 0;
      panel_oe  <= 0;
      panel_clk <= 0;
    end
    else if (WorkMode) begin
  		panel_oe <= 64*CHAINED-8 < cnt_x && cnt_x < 64*CHAINED+8;
  		if (state) begin
  			panel_clk <= 1 < cnt_x && cnt_x < 64*CHAINED+2;
  			panel_stb <= cnt_x == 64*CHAINED+2;
  		end else begin
        panel_clk <= 0;
        panel_stb <= 0;
  		end
    end
    else begin
      panel_stb <= initStb;
      panel_oe  <= initOe;
      panel_clk <= initClk;
    end
	end

  // Set read addreses
	always @(posedge display_clock) begin
    if (reset)
    begin
        addr_x <= 0;
        addr_y <= 0;
        addr_z <= 0;
    end
    else
    begin
      if (WorkMode) begin
    		addr_x <= cnt_x[5+SIZE_BITS:0];
    		addr_y <= cnt_y + 32*(!state);
    		addr_z <= cnt_z;
      end
    end
	end

  // Load memory data
	always @(posedge display_clock) begin
    if (reset)
    begin
      data_rgb <= 0;
    end
    else
    begin
      data_rgb[2] <= gamma_mem[video_mem_r[{addr_y, addr_x}]][addr_z];
      data_rgb[1] <= gamma_mem[video_mem_g[{addr_y, addr_x}]][addr_z];
      data_rgb[0] <= gamma_mem[video_mem_b[{addr_y, addr_x}]][addr_z];
    end
	end

  // Control color / address output
  always @(posedge display_clock) begin
    if (reset) begin
      {panel_r1, panel_r0} <= 0;
      {panel_g1, panel_g0} <= 0;
      {panel_b1, panel_b0} <= 0;
      {panel_e, panel_d, panel_c, panel_b, panel_a} <= 0;
      data_rgb_q <= 0;
    end
    else
    begin
      if (!WorkMode) begin
        panel_r0 <= outBit;
        panel_r1 <= outBit;
        panel_g0 <= outBit;
        panel_g1 <= outBit;
        panel_b0 <= outBit;
        panel_b1 <= outBit;
      end
      else begin
        data_rgb_q <= data_rgb;
        if (!state) begin
          if (0 < cnt_x && cnt_x < 64*CHAINED+1) begin
            {panel_r1, panel_r0} <= {data_rgb[2], data_rgb_q[2]};
            {panel_g1, panel_g0} <= {data_rgb[1], data_rgb_q[1]};
            {panel_b1, panel_b0} <= {data_rgb[0], data_rgb_q[0]};
          end else begin
            {panel_r1, panel_r0} <= 0;
            {panel_g1, panel_g0} <= 0;
            {panel_b1, panel_b0} <= 0;
          end
        end
        else if (cnt_x == 64*CHAINED) begin
          {panel_e, panel_d, panel_c, panel_b, panel_a} <= cnt_y;
        end
      end
    end
	end
endmodule
