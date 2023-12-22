`include "../rtl/uart.v"
`timescale 1ns/100ps

module uart_tb;

reg clk;
initial clk = 0;
always #8.9 clk = ~clk;
reg rstn, enable;

reg [31:0] div;

wire tx_ack;
reg tx_req;
wire tx;
reg [7:0] tx_data;
uart_tx u_uart_tx(
	.ack(tx_ack), 
	.req(tx_req), 
	.tx(tx), 
	.tx_data(tx_data), 
	.div(div), 
	.enable(enable), 
	.rstn(rstn), .clk(clk)
);

wire rx_ack;
reg rx_req;
wire rx = tx;
wire [7:0] rx_data;
uart_rx u_uart_rx(
	.ack(rx_ack), 
	.req(rx_req), 
	.rx(rx), 
	.rx_data(rx_data), 
	.div(div), 
	.enable(enable), 
	.rstn(rstn), .clk(clk)
);

task reset();
	tx_req = 0;
	rx_req = 0;
	tx_data = 0;
	div = $urandom_range(10,200);
	rstn = 0;
	repeat(5) @(posedge clk);
	rstn = 1;
endtask

task set();
	rstn = 1;
	repeat(5) @(posedge clk);
	rstn = 0;
endtask

integer fin;

task test();
	$display("start test");
	fin = $fopen("../src/rc4.fth","r");
	enable = 0;
	repeat(5) @(posedge clk);
	enable = 1;
	repeat(5) @(posedge clk);
	while(!$feof(fin)) begin
		div = $urandom_range(10,200);
		rx_req = ~rx_req;
		repeat(5) @(posedge clk);
		tx_data = $fgetc(fin);
		tx_req = ~tx_req;
		//@(negedge tx_ack or posedge tx_ack);
		@(negedge rx_ack or posedge rx_ack);
		$write("%c", rx_data);
		repeat(1000) @(posedge clk);
	end
	repeat(5) @(posedge clk);
	enable = 0;
	$fclose(fin);
	$display("end test");
endtask

initial begin
	reset();
	test();
	set();
	$finish;
end

initial begin
	$dumpfile("../work/uart_tb.fst");
	$dumpvars(0, uart_tb);
end

endmodule
