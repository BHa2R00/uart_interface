module uart_tx(
	output reg ack, 
	output reg [1:0] cst, nst, 
	input req, 
	output reg tx, 
	input [7:0] tx_data, 
	input [31:0] div, 
	input enable, 
	input rstn, clk 
);

reg enable_uclk;
reg [31:0] cnt;
reg uclk;
always@(negedge rstn or posedge clk) begin
	if(!rstn) begin
		cnt <= 32'd0;
		uclk <= 1'b0;
	end
	else if(enable) begin
		if(enable_uclk) begin
			if(cnt == 32'd0) begin
				cnt <= div;
				uclk <= ~uclk;
			end
			else cnt <= cnt - 32'd1;
		end
		else uclk <= 1'b0;
	end
end

reg [1:0] req_d, uclk_d;
always@(negedge rstn or posedge clk) begin
	if(!rstn) begin
		req_d <= 2'b00;
		uclk_d <= 2'b00;
	end
	else if(enable) begin
		req_d[1] <= req_d[0];
		req_d[0] <= req;
		uclk_d[1] <= uclk_d[0];
		uclk_d[0] <= uclk;
	end
end
wire req_x = ^req_d;
wire uclk_10 = uclk_d == 2'b10;
wire uclk_01 = uclk_d == 2'b01;

reg [2:0] nth;

`ifndef GRAY
	`define GRAY(X) (X^(X>>1))
`endif
localparam [1:0]
	st_end		= `GRAY(3),
	st_tx		= `GRAY(2),
	st_start	= `GRAY(1),
	st_idle		= `GRAY(0);

always@(negedge rstn or posedge clk) begin
	if(!rstn) cst <= st_idle;
	else if(enable) cst <= nst;
end

always@(*) begin
	case(cst)
		st_idle: nst = uclk_10 ? st_start : cst;
		st_start: nst = uclk_10 ? st_tx : cst;
		st_tx: nst = (uclk_10 && (nth == 0)) ? st_end : cst;
		st_end: nst = uclk_10 ? st_idle : cst;
		default: nst = st_idle;
	endcase
end

always@(negedge rstn or posedge clk) begin
	if(!rstn) enable_uclk <= 0;
	else if(enable) begin
		case(nst)
			st_idle: if(req_x) enable_uclk <= 1;
			st_end: if(uclk_01) enable_uclk <= 0;
			default: enable_uclk <= enable_uclk;
		endcase
	end
end

always@(negedge rstn or posedge clk)  begin
	if(!rstn) nth <= 0;
	else if(enable) begin
		case(nst)
			st_idle: nth <= 7;
			st_tx: if(uclk_01) nth <= nth - 1;
			default: nth <= nth;
		endcase
	end
end

reg [7:0] data;
always@(negedge rstn or posedge clk) begin
	if(!rstn) begin
		tx <= 1;
		data <= 0;
	end
	else if(enable) begin
		case(nst)
			st_idle: begin
				if(req_x) begin
					tx <= 0;
					data <= tx_data;
				end
			end
			st_start: tx <= 0;
			st_tx: tx <= data[nth];
			st_end: if(uclk_01) tx <= 1;
			default: begin
				tx <= tx;
				data <= data;
			end
		endcase
	end
end

always@(negedge rstn or posedge clk) begin
	if(!rstn) ack <= 1'b0;
	else if(enable) begin
		case(nst)
			st_end: if(uclk_10) ack <= ~ack;
			default: ack <= ack;
		endcase
	end
end

endmodule


module uart_rx(
	output reg ack, 
	output reg [2:0] cst, nst, 
	input req, 
	input rx, 
	output reg [7:0] rx_data, 
	input [31:0] div, 
	input enable, 
	input rstn, clk 
);

reg enable_uclk;
reg [31:0] cnt;
reg uclk;
always@(negedge rstn or posedge clk) begin
	if(!rstn) begin
		cnt <= 32'd0;
		uclk <= 1'b0;
	end
	else if(enable) begin
		if(enable_uclk) begin
			if(cnt == 32'd0) begin
				cnt <= div;
				uclk <= ~uclk;
			end
			else cnt <= cnt - 32'd1;
		end
		else uclk <= 1'b0;
	end
end

reg [1:0] req_d, uclk_d, rx_d;
always@(negedge rstn or posedge clk) begin
	if(!rstn) begin
		req_d <= 2'b00;
		uclk_d <= 2'b00;
		rx_d <= 2'b00;
	end
	else if(enable) begin
		req_d[1] <= req_d[0];
		req_d[0] <= req;
		uclk_d[1] <= uclk_d[0];
		uclk_d[0] <= uclk;
		rx_d[1] <= rx_d[0];
		rx_d[0] <= rx;
	end
end
wire req_x = ^req_d;
wire uclk_01 = uclk_d == 2'b01;
wire uclk_10 = uclk_d == 2'b10;
wire rx_10 = rx_d == 2'b10;

reg [2:0] nth;

`ifndef GRAY
	`define GRAY(X) (X^(X>>1))
`endif
localparam [2:0]
	st_end		= `GRAY(4),
	st_rx		= `GRAY(3),
	st_start	= `GRAY(2),
	st_clear	= `GRAY(1),
	st_idle		= `GRAY(0);

always@(negedge rstn or posedge clk) begin
	if(!rstn) cst <= st_idle;
	else if(enable) cst <= nst;
end

always@(*) begin
	case(cst)
		st_idle: nst = req_x ? st_clear: cst;
		st_clear: nst = rx_10 ? st_start: cst;
		st_start: nst = uclk_10 ? (rx == 0 ? st_rx : st_idle) : cst;
		st_rx: nst = (uclk_01 && (nth == 0)) ? st_end : cst;
		st_end: nst = uclk_01 ? st_idle : cst;
		default: nst = st_idle;
	endcase
end

always@(negedge rstn or posedge clk) begin
	if(!rstn) enable_uclk <= 0;
	else if(enable) begin
		case(cst)
			st_clear, st_start: if(rx_10) enable_uclk <= 1;
			st_end: if(uclk_01) enable_uclk <= 0;
			default: enable_uclk <= enable_uclk;
		endcase
	end
end

always@(negedge rstn or posedge clk)  begin
	if(!rstn) nth <= 0;
	else if(enable) begin
		case(cst)
			st_clear: nth <= 7;
			st_rx: if(uclk_01) nth <= nth - 1;
			default: nth <= nth;
		endcase
	end
end

reg [7:0] data;
always@(negedge rstn or posedge clk) begin
	if(!rstn) begin
		rx_data <= 0;
		data <= 0;
	end
	else if(enable) begin
		case(cst)
			st_clear: if(uclk_01) data <= 0;
			st_rx: if(uclk_01) data[nth] <= rx;
			st_end: rx_data <= data;
			default: begin
				rx_data <= rx_data;
				data <= data;
			end
		endcase
	end
end

always@(negedge rstn or posedge clk) begin
	if(!rstn) ack <= 1'b0;
	else if(enable) begin
		case(cst)
			st_end: if(uclk_01) ack <= ~ack;
			default: ack <= ack;
		endcase
	end
end

endmodule
