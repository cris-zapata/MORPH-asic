`timescale 1ns/1ps
module uart_rx_tb;
logic clk;
logic rst_n;
logic rx;
logic [7:0] rx_data;
logic rx_valid;
uart_rx dut (
    .clk(clk),
    .rst_n(rst_n),
    .rx(rx),
    .rx_data(rx_data),
    .rx_valid(rx_valid)
);
initial clk = 0;
always #10 clk = ~clk;
initial begin
    $dumpfile("Uart_rx.vcd");
    $dumpvars(0, uart_rx_tb);
end
initial begin
    rst_n = 0;
    rx = 1;
    #100;
    rst_n = 1;
    #100;
    rx = 0;
    #8680;
    rx = 1;
    #8680;
    rx = 0;
    #8680;
    rx = 0;
    #8680;
    rx = 0;
    #8680;
    rx = 0;
    #8680;
    rx = 0;
    #8680;
    rx = 1;
    #8680;
    rx = 0;
    #8680;
    rx = 1;
    #8680;
    #100000;
    $finish;
end
endmodule