`timescale 1ns/1ps


module uart_tx (
  output idle, 
  output reg tx, 
  input [7:0] data, 
  input write, 
  input [15:0] div, 
  input rstb, setb, clk 
);

reg [1:0] write_d;
wire write_p = write_d == 2'b01;
reg [1:0] cst, nst;
parameter [1:0] IDLE = (0^(0>>1));
parameter [1:0] LOAD = (1^(1>>1));
parameter [1:0] WAIT = (2^(2>>1));
parameter [1:0] POP  = (3^(3>>1));
reg [15:0] cnt, d;
wire eq = cnt == 16'd0;
reg [31:0] bth;
wire gt = bth > 4'd10;
reg [10:0] b;

always@(negedge rstb or posedge clk) begin
  if(~rstb) write_d <= 2'b00;
  else if(setb) write_d <= {write_d[0],write};
end

always@(negedge rstb or posedge clk) begin
  if(~rstb) cst <= IDLE;
  else if(setb) cst <= nst;
end
always@(*) begin
  nst = cst;
  case(cst)
    IDLE: if(write_p) nst = LOAD;
    LOAD: nst = WAIT;
    WAIT: if(eq) nst = POP;
    POP : nst = gt ? IDLE : WAIT;
  endcase
end

always@(negedge rstb or posedge clk) begin
	if(~rstb) d <= 16'd0;
	else if(setb) begin
		case(nst)
			LOAD: d <= div;
		endcase
	end
end

always@(negedge rstb or posedge clk) begin
  if(~rstb) cnt <= 16'd0;
  else if(setb) begin
    case(cst)
      LOAD, POP: cnt <= div;
      WAIT: cnt <= cnt - 16'd1;
    endcase
  end
end

always@(negedge rstb or posedge clk) begin
  if(~rstb) bth <= 4'd0;
  else if(setb) begin
    case(cst)
      LOAD: bth <= 4'd0;
      POP : bth <= bth + 4'd1;
    endcase
  end
end

always@(negedge rstb or posedge clk) begin
  if(~rstb) b <= 11'b11111111111;
  else if(setb) begin
    case(cst)
      LOAD: b <= {1'b1,(^data),data,1'b0};
    endcase
  end
end

always@(negedge rstb or posedge clk) begin
	if(~rstb) tx <= 1'b1;
	else if(setb) begin
		case(cst)
			POP: if(~gt) tx <= b[bth];
		endcase
	end
end

assign idle = cst == IDLE;

endmodule


`ifdef SIM
module uart_tx_tb;

wire idle;
wire tx;
reg [7:0] data;
reg write;
reg [15:0] div;
reg rstb, setb, clk;

uart_tx u_uart_tx (
  .idle(idle), 
  .tx(tx), 
  .data(data), 
  .write(write), 
  .div(div), 
  .rstb(rstb), .setb(setb), .clk(clk) 
);

always #1 clk = ~clk;

initial begin
  `ifdef FST
  $dumpfile("a.fst");
  $dumpvars(0,uart_tx_tb);
  `endif
  `ifdef FSDB
  $fsdbDumpfile("a.fsdb");
  $fsdbDumpvars(0,uart_tx_tb);
  `endif
  clk = 1'b0;
  rstb = 1'b0;
  setb = 1'b0;
  write = 1'b0;
  repeat(5) begin
    repeat(5) @(posedge clk); rstb = 1'b1;
    repeat(5) @(posedge clk); setb = 1'b1;
    repeat(55) begin
      data = $urandom_range(0,{8{1'b1}});
      write = 1'b0;
      div = $urandom_range(0,{4{1'b1}});
      repeat(2) @(posedge clk); write = 1'b1;
      @(posedge idle); write = 1'b0;
    end
    repeat(5) @(posedge clk); setb = 1'b0;
    repeat(5) @(posedge clk); rstb = 1'b0;
  end
  $finish;
end

endmodule
`endif


module uart_rx (
  output idle, 
  input rx, 
  output reg err, 
  output [7:0] data, 
  input read, 
  input [15:0] div, 
  input rstb, setb, clk 
);

reg [1:0] read_d;
wire read_p = read_d == 2'b01;
reg [1:0] cst, nst;
parameter [1:0] IDLE = (0^(0>>1));
parameter [1:0] LOAD = (1^(1>>1));
parameter [1:0] WAIT = (2^(2>>1));
parameter [1:0] PUSH = (3^(3>>1));
reg [15:0] cnt, d;
wire eq = cnt == 8'd0;
reg [9:0] b;
reg [3:0] bth;
wire gt = bth > 9;

always@(negedge rstb or posedge clk) begin
  if(~rstb) read_d <= 2'b00;
  else if(setb) read_d <= {read_d[0],read};
end

always@(negedge rstb or posedge clk) begin
  if(~rstb) cst <= IDLE;
  else if(setb) cst <= nst;
end
always@(*) begin
  nst = cst;
  case(cst)
    IDLE: if(read_p) nst = LOAD;
    LOAD: if(~rx) nst = WAIT;
    WAIT: if(eq) nst = PUSH;
    PUSH: nst = (gt && b[9]) ? IDLE : WAIT;
  endcase
end

always@(negedge rstb or posedge clk) begin
  if(~rstb) d <= 16'd0;
  else if(setb) begin
    case(nst)
      LOAD: d <= div;
    endcase
  end
end

always@(negedge rstb or posedge clk) begin
  if(~rstb) cnt <= 16'd0;
  else if(setb) begin
    case(cst)
      LOAD, PUSH: cnt <= d;
      WAIT: cnt <= cnt - 16'd1;
    endcase
  end
end

always@(negedge rstb or posedge clk) begin
  if(~rstb) bth <= 4'd0;
  else if(setb) begin
    case(cst)
      LOAD: bth <= 4'd0;
      PUSH: bth <= bth + 4'd1;
    endcase
  end
end

always@(posedge clk) begin
  if(setb) begin
    case(cst)
      PUSH: b[bth] <= rx;
    endcase
  end
end

assign data = err ? 8'b11111111 : b[7:0];

always@(negedge rstb or posedge clk) begin
  if(~rstb) err <= 1'b0;
  else if(setb) begin
    case(cst)
      PUSH: if(bth == 9) err <= (^b[7:0]) != b[8];
    endcase
  end
end

assign idle = cst == IDLE;

endmodule


`ifdef SIM
module uart_txrx_tb;

wire widle, ridle;
wire x, err;
reg [7:0] wdata;
wire [7:0] rdata;
reg write, read;
reg [15:0] div;
reg rstb, setb, clk;
logic check;

uart_tx u_uart_tx (
  .idle(widle), 
  .tx(x), 
  .data(wdata), 
  .write(write), 
  .div(div), 
  .rstb(rstb), .setb(setb), .clk(clk) 
);

uart_rx u_uart_rx (
  .idle(ridle), 
  .rx(x), 
  .err(err), 
  .data(rdata), 
  .read(read), 
  .div(div), 
  .rstb(rstb), .setb(setb), .clk(clk) 
);

always #1 clk = ~clk;

initial begin
  `ifdef FST
  $dumpfile("a.fst");
  $dumpvars(0,uart_txrx_tb);
  `endif
  `ifdef FSDB
  $fsdbDumpfile("a.fsdb");
  $fsdbDumpvars(0,uart_txrx_tb);
  `endif
  clk = 1'b0;
  rstb = 1'b0;
  setb = 1'b0;
  write = 1'b0;
  read = 1'b0;
  check = 1;
  repeat(5) begin
    repeat(5) @(posedge clk); rstb = 1'b1;
    repeat(5) @(posedge clk); setb = 1'b1;
    repeat(55) begin
      @(posedge clk); 
      div = $urandom_range(0,((1<<4)-1));
      wdata = $urandom_range(0,((1<<8)-1));
      write = 1'b0; read = 1'b0;
      fork
        begin
          repeat(2) @(posedge clk); write = 1'b1;
          @(posedge widle); write = 1'b0;
        end
        begin
          repeat(2) @(posedge clk); read = 1'b1;
          @(posedge ridle); read = 1'b0;
        end
      join
      if(check) begin
        check = wdata == rdata;
        $write("wdata = %x, rdata = %x, check = %b\n", wdata, rdata, check);
      end
    end
    repeat(5) @(posedge clk); setb = 1'b0;
    repeat(5) @(posedge clk); rstb = 1'b0;
  end
  if(check) $write("pass\n"); else $write("fail\n");
  $finish;
end

endmodule
`endif
