`timescale 1ns/1ps
module program_loader_tb;
logic clk;
logic rst_n;
logic [7:0] rx_data;
logic rx_valid;
logic [7:0] prog_addr;
logic [15:0] prog_data;
logic prog_we;
program_loader dut (
    .clk(clk),
    .rst_n(rst_n),
    .rx_data(rx_data),
    .rx_valid(rx_valid),
    .prog_addr(prog_addr),
    .prog_data(prog_data),
    .prog_we(prog_we)
);
initial clk = 0;
always #10 clk = ~clk;
initial begin
    $dumpfile("program_loader.vcd");
    $dumpvars(0, program_loader_tb);
end
initial begin
    rst_n = 0;
    rx_data = 8'h00;
    rx_valid = 0;
    #45;
    rst_n = 1;
    #10;
    rx_data = 8'h00;
    rx_valid = 1;
    #20;
    rx_valid = 0;
    #20;
    rx_data = 8'h20;
    rx_valid = 1;
    #20;
    rx_valid = 0;
    #20;
    rx_data = 8'h05;
    rx_valid = 1;
    #20;
    rx_valid = 0;
    #100;
    $finish;
end
endmodule