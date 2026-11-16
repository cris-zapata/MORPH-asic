
`timescale 1ns/1ps

module morph_program_tb;

    reg clk;
    reg rst_n;
    reg prog_mode;
    reg rx;

    reg [7:0] gpio_in_pins;

    wire [7:0] gpio_out_pins;
    wire [7:0] gpio_oe;
    wire [7:0] debug_pc;

    morph_top uut (
        .clk(clk),
        .rst_n(rst_n),
        .rx(rx),
        .prog_mode(prog_mode),
        .gpio_in_pins(gpio_in_pins),
        .gpio_out_pins(gpio_out_pins),
        .gpio_oe(gpio_oe),
        .debug_pc(debug_pc)
    );

    // 50 MHz clock
    always #10 clk = ~clk;

    initial begin
        $dumpfile("morph_program_tb.vcd");
        $dumpvars(0, morph_program_tb);

        clk = 0;
        rst_n = 0;
        prog_mode = 1;
        rx = 1;
        gpio_in_pins = 8'h00;

        // Hold reset
        #40;
        rst_n = 1;

        // Load instructions directly through CPU programming interface
        // This bypasses UART for the initial CPU/GPIO integration test.

        @(negedge clk);
        force uut.prog_addr = 8'h00;
        force uut.prog_data = 16'h20FF;
        force uut.prog_we = 1'b1;

        @(negedge clk);
        force uut.prog_addr = 8'h01;
        force uut.prog_data = 16'h6000;

        @(negedge clk);
        force uut.prog_addr = 8'h02;
        force uut.prog_data = 16'h24AA;

        @(negedge clk);
        force uut.prog_addr = 8'h03;
        force uut.prog_data = 16'h7400;

        @(negedge clk);
        force uut.prog_addr = 8'h04;
        force uut.prog_data = 16'h3004;

        @(negedge clk);
        force uut.prog_we = 1'b0;

        // Release programming signals
        #1;
        release uut.prog_addr;
        release uut.prog_data;
        release uut.prog_we;

        // Begin CPU execution
        @(negedge clk);
        prog_mode = 0;

        // Allow CPU to execute the program
        repeat (10) @(negedge clk);

        $display("GPIO OE  = %b", gpio_oe);
        $display("GPIO OUT = %b", gpio_out_pins);
        $display("PC       = %d", debug_pc);

        if (gpio_oe == 8'hFF &&
            gpio_out_pins == 8'hAA)
            $display("MORPH GPIO PROGRAM: PASS");
        else
            $display("MORPH GPIO PROGRAM: FAIL");

        $finish;
    end

endmodule
