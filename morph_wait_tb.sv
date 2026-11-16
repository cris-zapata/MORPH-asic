
`timescale 1ns/1ps

module morph_wait_tb;

    logic clk;
    logic rst_n;
    logic prog_mode;

    logic uart_rx_pin;
    logic [7:0] gpio_in_pins;

    wire [7:0] gpio_out_pins;
    wire [7:0] gpio_oe;
    wire [7:0] debug_pc;

    integer errors = 0;

    // 50 MHz clock: 20 ns period
    initial clk = 1'b0;
    always #10 clk = ~clk;

    // MORPH top-level DUT
    morph_top dut (
        .clk(clk),
        .rst_n(rst_n),
        .prog_mode(prog_mode),
        .rx(uart_rx_pin),
        .gpio_in_pins(gpio_in_pins),
        .gpio_out_pins(gpio_out_pins),
        .gpio_oe(gpio_oe),
        .debug_pc(debug_pc)
    );

    // Test a WAIT instruction with a specified register value.
    task automatic test_wait(
        input logic [7:0] delay_value,
        input integer expected_cycles
    );

        integer cycles;
        integer timeout;

        begin
            // Freeze the CPU while preparing the test.
            @(negedge clk);
            prog_mode = 1'b1;
            rst_n = 1'b0;

            // Program:
            // 00: LOADI R0, delay_value
            // 01: WAIT R0
            // 02: LOADI R1, AA
            // 03: OUT R1
            // 04: JMP 04

            dut.cpu.u_instruction_memory.memory[0] =
                {8'h20, delay_value};

            dut.cpu.u_instruction_memory.memory[1] = 16'h9000;
            dut.cpu.u_instruction_memory.memory[2] = 16'h24AA;
            dut.cpu.u_instruction_memory.memory[3] = 16'h7400;
            dut.cpu.u_instruction_memory.memory[4] = 16'h3004;

            repeat (3) @(negedge clk);

            rst_n = 1'b1;

            repeat (2) @(negedge clk);

            prog_mode = 1'b0;

            // First clock executes LOADI.
            @(posedge clk);
            #1;

            if (debug_pc !== 8'h01) begin
                $display("FAIL: PC did not reach WAIT instruction");
                errors = errors + 1;
            end

            // Count clock edges spent executing WAIT.
            cycles = 0;
            timeout = 0;

            while (debug_pc === 8'h01 && timeout < 300) begin
                @(posedge clk);
                #1;

                cycles = cycles + 1;
                timeout = timeout + 1;
            end

            $display("--------------------------------------");
            $display("WAIT R0 = %0d", delay_value);
            $display("Expected cycles: %0d", expected_cycles);
            $display("Measured cycles: %0d", cycles);
            $display("Final PC: %02h", debug_pc);

            if (cycles == expected_cycles &&
                debug_pc === 8'h02) begin
                $display("PASS: WAIT timing correct");
            end
            else begin
                $display("FAIL: WAIT timing incorrect");
                errors = errors + 1;
            end

            // Allow LOADI R1, OUT R1, JMP 04 to execute.
            repeat (4) @(posedge clk);
            #1;

            if (gpio_out_pins === 8'hAA) begin
                $display("PASS: CPU resumed after WAIT");
            end
            else begin
                $display("FAIL: GPIO output incorrect: %02h",
                         gpio_out_pins);
                errors = errors + 1;
            end

            $display("--------------------------------------");
        end
    endtask

    initial begin

        $dumpfile("morph_wait.vcd");
        $dumpvars(0, morph_wait_tb);

        rst_n = 1'b0;
        prog_mode = 1'b1;
        uart_rx_pin = 1'b1;
        gpio_in_pins = 8'h00;

        repeat (2) @(negedge clk);

        test_wait(8'd0,   1);
        test_wait(8'd1,   1);
        test_wait(8'd5,   5);
        test_wait(8'd255, 255);

        $display("");
        $display("======================================");

        if (errors == 0)
            $display("ALL MORPH WAIT TESTS PASSED");
        else
            $display("MORPH WAIT TESTS FAILED: %0d errors", errors);

        $display("======================================");

        $finish;
    end

endmodule
