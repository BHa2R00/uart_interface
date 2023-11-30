module uart_tx(
	output empty, 
	input fill, 
	output tx, 
	input [7:0] tx_data, 
	input [1:0] parity, 
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

reg [1:0] fill_d, uclk_d;
always@(negedge rstn or posedge clk) begin
	if(!rstn) begin
		fill_d <= 2'b00;
		uclk_d <= 2'b00;
	end
	else if(enable) begin
		fill_d[1] <= fill_d[0];
		fill_d[0] <= fill;
		uclk_d[1] <= uclk_d[0];
		uclk_d[0] <= uclk;
	end
end
wire fill_01 = fill_d == 2'b01;
wire uclk_10 = uclk_d == 2'b10;

reg [10:0] buffer;
reg [3:0] bcnt1, bcnt2;
wire bcnt2_end = 
	parity == 2'b00 ? bcnt2 == 4'd9 : 
	parity == 2'b01 ? bcnt2 == 4'd10 : 
	parity == 2'b10 ? bcnt2 == 4'd10 : 
	parity == 2'b11 ? bcnt2 == 4'd10 : 
	0;
always@(negedge rstn or posedge clk) begin
	if(!rstn) begin
		buffer <= 11'b11111111111;
		bcnt1 <= 4'd0;
		bcnt2 <= 4'd0;
		enable_uclk <= 1'b0;
	end
	else if(enable) begin
		if(bcnt1 == 4'd0) begin
			if(fill_01) begin
				bcnt1 <= bcnt1 + 4'd1;
				bcnt2 <= 4'd0;
				buffer[0] <= 1'b1;
				buffer[1] <= 1'b0;
				buffer[9:2] <= tx_data;
				case(parity)
					2'b00: buffer[10] <= 1'b1;
					default: buffer[10] <= tx_data[0];
				endcase
				enable_uclk <= 1'b1;
			end
		end
		else if(bcnt1 == 4'd10) begin
			if(uclk_10) begin
				if(bcnt2_end) begin
					bcnt1 <= 4'd0;
					bcnt2 <= 4'd0;
					enable_uclk <= 1'b0;
				end
				else bcnt2 <= bcnt2 + 4'd1;
			end
		end
		else if(bcnt1 == 4'd1) bcnt1 <= bcnt1 + 4'd1;
		else begin
			bcnt1 <= bcnt1 + 4'd1;
			case(parity)
				2'b00: buffer[10] <= 1'b1;
				2'b01, 2'b10: buffer[10] <= buffer[10] ^ buffer[bcnt1];
				2'b11: buffer[10] <= buffer[10] ~^ buffer[bcnt1];
				default: buffer[10] <= buffer[10];
			endcase
		end
	end
end
assign tx = buffer[bcnt2];
assign empty = (bcnt1 == 4'd0) && (bcnt2 == 4'd0);

endmodule
