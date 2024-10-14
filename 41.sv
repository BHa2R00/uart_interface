`timescale 1ns/1ps


module uart (                 //# bus: slave=u_uart, addr0=h010a ;
  output test_so, 
  input test_se, test_si,
  output tx,                  //# io: mux={1,3,5} ;
  input rx,                   //# io: mux={0,2,4} ;
  output reg rintr, wintr,    //# bus: addr=h0003, data[21:20], type=ro  ; dma: req=rx, req=tx ; intr;
  input [3:0] rlht, rhlt,     //# bus: addr=h0003, data[19:16], type=rw  ;
  input [3:0] wlht, whlt,     //# bus: addr=h0003, data[15:12], type=rw  ;
  output rfull, rempty,       //# bus: addr=h0003, data[11:10], type=ro  ;
  output wfull, wempty,       //# bus: addr=h0003, data[ 9: 8], type=ro  ;
  output [3:0] rcnt, wcnt,    //# bus: addr=h0003, data[ 7: 0], type=ro  ;
  input pop, push, clear,     //# bus: addr=h0000, data[ 4: 2], type=w1p ; dma: ack=tx, ack=rx, nil;
  output [7:0] rchar,         //# bus: addr=h0002, data[15: 8], type=ro  ;
  input [7:0] wchar,          //# bus: addr=h0002, data[ 7: 0], type=rw  ;
  input update,               //# bus: addr=h0000, data[ 1: 1], type=w1p ;
  input [15:0] div,           //# bus: addr=h0001, data[15: 0], type=rw  ;
  input setb,                 //# bus: addr=h0000, data[ 0: 0], type=rw  ;
  input frstb, fclk,          //# rc: frstb, fclk= ;
  input rstb, clk             //# rc: prstb, pclk ;
);

reg [1:0] fclk_d;
reg [1:0] update_d;
wire update_p = update_d == 2'b01;
reg [15:0] cnt;
wire eq = cnt == 16'd0;
reg uclk;
reg [3:0] uclk_d;
wire uclk_p = uclk_d[3:2] == 2'b01;
wire uclk_n = uclk_d[3:2] == 2'b10;
reg [7:0] rb[0:7];
reg [7:0] wb[0:7];
reg [3:0] ra1, ra0;
reg [3:0] wa1, wa0;
assign rcnt = ra1 - ra0;
assign wcnt = wa1 - wa0;
assign rfull  = rcnt == 4'd8;
assign rempty = rcnt == 4'd0;
assign wfull  = wcnt == 4'd8;
assign wempty = wcnt == 4'd0;
reg [3:0] ra, ta;
reg [3:0] nxt_ra, nxt_ta;
wire xortx = ^(wb[wa0[2:0]]);
wire xorrx = ^(rb[ra1[2:0]]);
assign tx =
  (ta >= 4'd11) ? 1'b0 : 
  (ta >= 4'd9) ? 1'b1 : 
  (ta == 4'd8) ? xortx : 
  wb[wa0[2:0]][ta[2:0]];
reg [1:0] clear_d, push_d, pop_d;
wire clear_p = clear_d == 2'b01;
wire push_p = push_d == 2'b01;
wire pop_p = pop_d == 2'b01;
wire tidle = ta == 4'd9;
wire ridle = ra == 4'd9;
reg [1:0] tidle_d, ridle_d;
wire tidle_p = tidle_d == 2'b01;
wire ridle_p = ridle_d == 2'b01;
reg valid;
assign rchar = rb[ra0[2:0]];

always@(negedge frstb or posedge fclk) begin
  if(~frstb) update_d <= 2'b11;
  else update_d <= {update_d[0],update};
end

always@(negedge frstb or posedge fclk) begin
  if(~frstb) cnt <= 16'd0;
  else begin
    if(update_p) cnt <= 16'd0;
    else cnt <= eq ? div : cnt - 16'd1;
  end
end

always@(negedge frstb or posedge fclk) begin
  if(~frstb) uclk <= 1'b0;
  else if(eq) uclk <= ~uclk;
end

always@(negedge rstb or posedge clk) begin
  if(~rstb) uclk_d <= 4'b0000;
  else uclk_d <= {uclk_d[2:0],uclk};
end

always@(negedge rstb or posedge clk) begin
  if(~rstb) ta <= 4'd9;
  else if(setb && uclk_p) ta <= nxt_ta;
end
always@(*) begin
  nxt_ta = ta;
  case(ta)
    4'd9 : if(~wempty) nxt_ta = 4'd10;
    4'd10: nxt_ta = 4'd11;
    4'd11: nxt_ta = 4'd0;
    4'd0,4'd1,4'd2,4'd3,
    4'd4,4'd5,4'd6,4'd7,
    4'd8 : nxt_ta = ta + 4'd1;
  endcase
end

always@(negedge rstb or posedge clk) begin
  if(~rstb) ra <= 4'd9;
  else if(setb && uclk_n) ra <= nxt_ra;
end
always@(*) begin
  nxt_ra = ra;
  case(ra)
    4'd9 : if(rx && (~rfull)) nxt_ra = 4'd10;
    4'd10: if(~rx) nxt_ra = 4'd11;
    4'd11: nxt_ra = 4'd0;
    4'd0,4'd1,4'd2,4'd3,
    4'd4,4'd5,4'd6,4'd7,
    4'd8 : nxt_ra = ra + 4'd1;
  endcase
end

always@(*) begin
  if(clk && setb && (4'd7 >= nxt_ra) && uclk_n) rb[ra1[2:0]][nxt_ra[2:0]] <= rx;
end
always@(negedge rstb or posedge clk) begin
  if(~rstb) valid = 1'b0;
  else if(setb && (4'd8 == nxt_ra) && uclk_n) valid = xorrx == rx;
end

always@(negedge rstb or posedge clk) begin
  if(~rstb) clear_d <= 2'b11;
  else clear_d <= {clear_d[0],clear};
end

always@(negedge rstb or posedge clk) begin
  if(~rstb) push_d <= 2'b11;
  else push_d <= {push_d[0],push};
end

always@(negedge rstb or posedge clk) begin
  if(~rstb) pop_d <= 2'b11;
  else pop_d <= {pop_d[0],pop};
end

always@(negedge rstb or posedge clk) begin
  if(~rstb) tidle_d <= 2'b11;
  else tidle_d <= {tidle_d[0],tidle};
end

always@(negedge rstb or posedge clk) begin
  if(~rstb) ridle_d <= 2'b11;
  else ridle_d <= {ridle_d[0],ridle};
end

always@(negedge rstb or posedge clk) begin
  if(~rstb) wa1 <= 4'd0;
  else if(setb) begin
    if(clear_p) wa1 <= 4'd0;
    else if(push_p) wa1 <= wa1 + 4'd1;
  end
end

always@(negedge rstb or posedge clk) begin
  if(~rstb) ra0 <= 4'd0;
  else if(setb) begin
    if(clear_p) ra0 <= 4'd0;
    else if(pop_p) ra0 <= ra0 + 4'd1;
  end
end

always@(negedge rstb or posedge clk) begin
  if(~rstb) wa0 <= 4'd0;
  else if(setb) begin
    if(clear_p) wa0 <= 4'd0;
    else if(tidle_p && (~wempty)) wa0 <= wa0 + 4'd1;
  end
end

always@(negedge rstb or posedge clk) begin
  if(~rstb) ra1 <= 4'd0;
  else if(setb) begin
    if(clear_p) ra1 <= 4'd0;
    else if(ridle_p && (~rfull) && valid) ra1 <= ra1 + 4'd1;
  end
end

always@(*) begin
  if(clk && setb && push_p) wb[wa1[2:0]] <= wchar;
end

always@(negedge rstb or posedge clk) begin
  if(~rstb) rintr <= 1'b0;
  else if(setb && 
      (
        (rintr && push_p && (rcnt == rhlt))||
        ((~rintr) && ridle_p && (rcnt == rlht))
      )
    ) rintr <= ~rintr;
end

always@(negedge rstb or posedge clk) begin
  if(~rstb) wintr <= 1'b0;
  else if(setb && 
      (
        (wintr && tidle_p && (wcnt == whlt))||
        ((~wintr) && pop_p && (wcnt == wlht))
      )
    ) wintr <= ~wintr;
end

endmodule


`ifdef SIM
module uart_tb;

wire x1, x2;
wire rintr1, wintr1;
wire rintr2, wintr2;
reg [3:0] rlht1, rhlt1;
reg [3:0] rlht2, rhlt2;
reg [3:0] wlht1, whlt1;
reg [3:0] wlht2, whlt2;
wire rfull1, rempty1;
wire rfull2, rempty2;
wire wfull1, wempty1;
wire wfull2, wempty2;
wire [3:0] wcnt1, rcnt1;
wire [3:0] wcnt2, rcnt2;
wire [7:0] rchar1, rchar2;
reg [7:0] wchar1, wchar2;
reg [15:0] div;
reg update1, clear1, push1, pop1;
reg update2, clear2, push2, pop2;
reg frstb, rstb, setb, clk, fclk;
reg [63:0] wuint1, wuint2;
reg [63:0] ruint1, ruint2;
logic check1, check2;

uart u_uart1 (
  .rx(x2), 
  .tx(x1), 
  .rintr(rintr1), .wintr(wintr1), 
  .rlht(rlht1), .rhlt(rhlt1), 
  .wlht(wlht1), .whlt(whlt1), 
  .rfull(rfull1), .rempty(rempty1), 
  .wfull(wfull1), .wempty(wempty1), 
  .wcnt(wcnt1), .rcnt(rcnt1), 
  .rchar(rchar1), 
  .wchar(wchar1), 
  .div(div),
  .update(update1), .clear(clear1), .push(push1), .pop(pop1), 
  .rstb(rstb), .setb(setb), .clk(clk), .fclk(fclk), .frstb(frstb)  
);

uart u_uart2 (
  .rx(x1), 
  .tx(x2), 
  .rintr(rintr2), .wintr(wintr2), 
  .rlht(rlht2), .rhlt(rhlt2), 
  .wlht(wlht2), .whlt(whlt2), 
  .rfull(rfull2), .rempty(rempty2), 
  .wfull(wfull2), .wempty(wempty2), 
  .wcnt(wcnt2), .rcnt(rcnt2), 
  .rchar(rchar2), 
  .wchar(wchar2), 
  .div(div),
  .update(update2), .clear(clear2), .push(push2), .pop(pop2), 
  .rstb(rstb), .setb(setb), .clk(clk), .fclk(fclk), .frstb(frstb) 
);

always #250 clk = ~clk;
always #250 fclk = ~fclk;

initial begin
  `ifdef FST
  $dumpfile("a.fst");
  $dumpvars(0,uart_tb);
  `endif
  `ifdef FSDB
  $fsdbDumpfile("a.fsdb");
  $fsdbDumpvars(0,uart_tb);
  `endif
  fclk = 1'b0;
  clk = 1'b0;
  rstb = 1'b0;
  frstb = 1'b0;
  setb = 1'b0;
  update1 = 1'b0;
  update2 = 1'b0;
  clear1 = 1'b0;
  clear2 = 1'b0;
  push1 = 1'b0;
  pop1 = 1'b0;
  push2 = 1'b0;
  pop2 = 1'b0;
  rlht1 = 4'd1;
  rhlt1 = 4'd1;
  rlht2 = 4'd1;
  rhlt2 = 4'd1;
  wlht1 = 4'd1;
  whlt1 = 4'd1;
  wlht2 = 4'd1;
  whlt2 = 4'd1;
  check1 = 1;
  check2 = 1;
  repeat(5) begin
    repeat(5) @(posedge clk); rstb = 1'b1;
    repeat(5) @(posedge clk); frstb = 1'b1;
    repeat(5) @(posedge clk); setb = 1'b1;
    repeat(5) begin
    div = $urandom_range('h1,'hf); $write("div=%x\n", div);
    repeat($urandom_range(5,55)) @(posedge clk); update2 = 1'b1;
    repeat($urandom_range(1,5)) @(posedge clk); update1 = 1'b1;
    rlht1 = $urandom_range(1,6);
    rhlt1 = $urandom_range(1,6);
    rlht2 = $urandom_range(1,6);
    rhlt2 = $urandom_range(1,6);
    wlht1 = $urandom_range(1,6);
    whlt1 = $urandom_range(1,6);
    wlht2 = $urandom_range(1,6);
    whlt2 = $urandom_range(1,6);
    repeat(5) @(posedge clk); clear1 = 1'b1;
    repeat(5) @(posedge clk); clear1 = 1'b0;
    repeat(5) @(posedge clk); clear2 = 1'b1;
    repeat(5) @(posedge clk); clear2 = 1'b0;
    repeat($urandom_range(1,55)) @(posedge clk);
    repeat(55) begin
      repeat($urandom_range(1,55)) @(posedge fclk);
      wuint1 = {$urandom_range(0,{32{1'b1}}),$urandom_range(0,{32{1'b1}})};
      wuint2 = {$urandom_range(0,{32{1'b1}}),$urandom_range(0,{32{1'b1}})};
      push1 = 1'b0; pop1 = 1'b0;
      push2 = 1'b0; pop2 = 1'b0;
      fork
        begin
          do @(posedge clk); while(~wempty1);
          $write("push1: wuint1 = %x, ", wuint1); 
          wchar1 = wuint1[07:00];
          repeat(2) @(posedge clk); push1 = 1'b1;
          repeat(2) @(posedge clk); push1 = 1'b0;
          wchar1 = wuint1[15:08];
          repeat(2) @(posedge clk); push1 = 1'b1;
          repeat(2) @(posedge clk); push1 = 1'b0;
          wchar1 = wuint1[23:16];
          repeat(2) @(posedge clk); push1 = 1'b1;
          repeat(2) @(posedge clk); push1 = 1'b0;
          wchar1 = wuint1[31:24];
          repeat(2) @(posedge clk); push1 = 1'b1;
          repeat(2) @(posedge clk); push1 = 1'b0;
          wchar1 = wuint1[39:32];
          repeat(2) @(posedge clk); push1 = 1'b1;
          repeat(2) @(posedge clk); push1 = 1'b0;
          wchar1 = wuint1[47:40];
          repeat(2) @(posedge clk); push1 = 1'b1;
          repeat(2) @(posedge clk); push1 = 1'b0;
          wchar1 = wuint1[55:48];
          repeat(2) @(posedge clk); push1 = 1'b1;
          repeat(2) @(posedge clk); push1 = 1'b0;
          wchar1 = wuint1[63:56];
          repeat(2) @(posedge clk); push1 = 1'b1;
          repeat(2) @(posedge clk); push1 = 1'b0;
        end
        begin
          do @(posedge clk); while(~wempty2);
          $write("push2: wuint2 = %x, ", wuint2); 
          wchar2 = wuint2[07:00];
          repeat(2) @(posedge clk); push2 = 1'b1;
          repeat(2) @(posedge clk); push2 = 1'b0;
          wchar2 = wuint2[15:08];
          repeat(2) @(posedge clk); push2 = 1'b1;
          repeat(2) @(posedge clk); push2 = 1'b0;
          wchar2 = wuint2[23:16];
          repeat(2) @(posedge clk); push2 = 1'b1;
          repeat(2) @(posedge clk); push2 = 1'b0;
          wchar2 = wuint2[31:24];
          repeat(2) @(posedge clk); push2 = 1'b1;
          repeat(2) @(posedge clk); push2 = 1'b0;
          wchar2 = wuint2[39:32];
          repeat(2) @(posedge clk); push2 = 1'b1;
          repeat(2) @(posedge clk); push2 = 1'b0;
          wchar2 = wuint2[47:40];
          repeat(2) @(posedge clk); push2 = 1'b1;
          repeat(2) @(posedge clk); push2 = 1'b0;
          wchar2 = wuint2[55:48];
          repeat(2) @(posedge clk); push2 = 1'b1;
          repeat(2) @(posedge clk); push2 = 1'b0;
          wchar2 = wuint2[63:56];
          repeat(2) @(posedge clk); push2 = 1'b1;
          repeat(2) @(posedge clk); push2 = 1'b0;
        end
        begin
          @(posedge rfull1);
          ruint1[07:00] = rchar1;
          repeat(2) @(posedge clk); pop1 = 1'b1;
          repeat(2) @(posedge clk); pop1 = 1'b0;
          ruint1[15:08] = rchar1;
          repeat(2) @(posedge clk); pop1 = 1'b1;
          repeat(2) @(posedge clk); pop1 = 1'b0;
          ruint1[23:16] = rchar1;
          repeat(2) @(posedge clk); pop1 = 1'b1;
          repeat(2) @(posedge clk); pop1 = 1'b0;
          ruint1[31:24] = rchar1;
          repeat(2) @(posedge clk); pop1 = 1'b1;
          repeat(2) @(posedge clk); pop1 = 1'b0;
          ruint1[39:32] = rchar1;
          repeat(2) @(posedge clk); pop1 = 1'b1;
          repeat(2) @(posedge clk); pop1 = 1'b0;
          ruint1[47:40] = rchar1;
          repeat(2) @(posedge clk); pop1 = 1'b1;
          repeat(2) @(posedge clk); pop1 = 1'b0;
          ruint1[55:48] = rchar1;
          repeat(2) @(posedge clk); pop1 = 1'b1;
          repeat(2) @(posedge clk); pop1 = 1'b0;
          ruint1[63:56] = rchar1;
          repeat(2) @(posedge clk); pop1 = 1'b1;
          repeat(2) @(posedge clk); pop1 = 1'b0;
          $write("pop1: ruint1 = %x, ", ruint1); 
        end
        begin
          @(posedge rfull2);
          ruint2[07:00] = rchar2;
          repeat(2) @(posedge clk); pop2 = 1'b1;
          repeat(2) @(posedge clk); pop2 = 1'b0;
          ruint2[15:08] = rchar2;
          repeat(2) @(posedge clk); pop2 = 1'b1;
          repeat(2) @(posedge clk); pop2 = 1'b0;
          ruint2[23:16] = rchar2;
          repeat(2) @(posedge clk); pop2 = 1'b1;
          repeat(2) @(posedge clk); pop2 = 1'b0;
          ruint2[31:24] = rchar2;
          repeat(2) @(posedge clk); pop2 = 1'b1;
          repeat(2) @(posedge clk); pop2 = 1'b0;
          ruint2[39:32] = rchar2;
          repeat(2) @(posedge clk); pop2 = 1'b1;
          repeat(2) @(posedge clk); pop2 = 1'b0;
          ruint2[47:40] = rchar2;
          repeat(2) @(posedge clk); pop2 = 1'b1;
          repeat(2) @(posedge clk); pop2 = 1'b0;
          ruint2[55:48] = rchar2;
          repeat(2) @(posedge clk); pop2 = 1'b1;
          repeat(2) @(posedge clk); pop2 = 1'b0;
          ruint2[63:56] = rchar2;
          repeat(2) @(posedge clk); pop2 = 1'b1;
          repeat(2) @(posedge clk); pop2 = 1'b0;
          $write("pop2: ruint2 = %x, ", ruint2); 
        end
      join $write("\n");
      fork
        if(check1) begin
          check1 = wuint2 == ruint1;
          $write("wuint2 = %x, ruint1 = %x, check1 = %b, ", wuint2, ruint1, check1);
        end
        if(check2) begin
          check2 = wuint1 == ruint2;
          $write("wuint1 = %x, ruint2 = %x, check2 = %b, ", wuint1, ruint2, check2);
        end
      join $write("\n");
    end
    repeat($urandom_range(1,55)) @(posedge clk); update2 = 1'b0;
    repeat($urandom_range(1,5)) @(posedge clk); update1 = 1'b0;
    end
    repeat(5) @(posedge clk); setb = 1'b0;
    repeat(5) @(posedge clk); frstb = 1'b0;
    repeat(5) @(posedge clk); rstb = 1'b0;
  end
  if(check1 && check2) $write("\npass\n"); else $write("\nfail\n");
  $finish;
end

endmodule
`endif
