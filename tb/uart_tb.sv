`timescale 1ns/100ps
`include "../rtl/uart_tx.v"
module uart_tb;

reg rstn, enable;

reg clk;
initial clk = 1'b0;
always #4.5 clk = ~clk;

wire u1_uart_tx_empty;
reg u1_uart_tx_fill;
wire u1_uart_tx_tx;
reg [7:0] u1_uart_tx_tx_data;
uart_tx u1_uart_tx(
	.empty(u1_uart_tx_empty), 
	.fill(u1_uart_tx_fill), 
	.tx(u1_uart_tx_tx), 
	.tx_data(u1_uart_tx_tx_data), 
	.parity(2'b00), 
	.div(32'd48), 
	.enable(enable), 
	.rstn(rstn), .clk(clk)
);

initial begin
	rstn = 1'b0;
	enable = 1'b0;
	u1_uart_tx_fill = 1'b0;
	u1_uart_tx_tx_data = 8'd0;
	repeat(2) @(negedge clk);
	rstn = 1'b1;
	repeat(2) @(negedge clk);
	enable = 1'b1;
	repeat(2) @(negedge clk);
	u1_uart_tx_fill = 1'b1;
	repeat(100) begin
		@(negedge u1_uart_tx_empty);
		u1_uart_tx_fill = 1'b0;
		u1_uart_tx_tx_data = $urandom_range(33, 126);
		$display("u1_uart_tx_tx_data = %x", u1_uart_tx_tx_data);
		@(posedge u1_uart_tx_empty);
		u1_uart_tx_fill = 1'b1;
	end
	repeat(2) @(negedge clk);
	rstn = 1'b0;
	repeat(2) @(negedge clk);
	$finish;
end
initial begin
	$dumpfile("../work/uart_tb.fst");
	$dumpvars(0,uart1_tb);
end

endmodule
