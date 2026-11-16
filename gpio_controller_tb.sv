
`timescale 1ns/1ps

module gpio_controller_tb;

    reg clk;
    reg rst_n;
    reg [7:0] gpio_wdata;
    reg gpio_we;
    reg gpio_sel;
    reg [7:0] gpio_in_pins;

    wire [7:0] gpio_out_pins;
    wire [7:0] gpio_oe;
    wire [7:0] gpio_rdata;

    gpio_controller uut (
        .clk(clk),
        .rst_n(rst_n),
        .gpio_wdata(gpio_wdata),
        .gpio_we(gpio_we),
        .gpio_sel(gpio_sel),
        .gpio_in_pins(gpio_in_pins),
        .gpio_out_pins(gpio_out_pins),
        .gpio_oe(gpio_oe),
        .gpio_rdata(gpio_rdata)
    );

    // 50 MHz clock
    always #10 clk = ~clk;

    initial begin
        $dumpfile("gpio_controller_tb.vcd");
        $dumpvars(0, gpio_controller_tb);

        clk = 0;
        rst_n = 0;
        gpio_wdata = 0;
        gpio_we = 0;
        gpio_sel = 0;
        gpio_in_pins = 0;

        // Reset
        #40;
        rst_n = 1;

        // Set GPIO 7:4 as outputs
        #20;
        gpio_we = 1;
        gpio_sel = 1;
        gpio_wdata = 8'b1111_0000;

        #20;
        gpio_we = 0;

        // Write output data
        #20;
        gpio_we = 1;
        gpio_sel = 0;
        gpio_wdata = 8'b1010_1010;

        #20;
        gpio_we = 0;

        // Change input pin values
        #20;
        gpio_in_pins = 8'b0101_0011;

        // Test write enable disabled
        #20;
        gpio_wdata = 8'b1111_1111;

        // Set all GPIO pins as outputs
        #20;
        gpio_we = 1;
        gpio_sel = 1;
        gpio_wdata = 8'b1111_1111;

        #20;
        gpio_we = 0;

        // Set all GPIO pins as inputs
        #20;
        gpio_we = 1;
        gpio_sel = 1;
        gpio_wdata = 8'b0000_0000;

        #20;
        gpio_we = 0;

        #40;

        $display("GPIO Controller Simulation Complete");
        $finish;
    end

endmodule
