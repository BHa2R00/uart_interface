
uart_tb: ../tb/uart_tb.sv 
	rm -rfv ../work/uart_tb.fst
	iverilog -g2012 ../tb/uart_tb.sv 
	vvp ./a.out -fst
	gtkwave ../work/uart_tb.fst
