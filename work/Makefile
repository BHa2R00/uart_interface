uart_tb: ../tb/uart_tb.sv 
	rm -rfv uart_tb.fst
	iverilog ../tb/uart_tb.sv 
	vvp ./a.out -fst
	gtkwave ./uart_tb.fst
