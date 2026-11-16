
`timescale 1ns/1ps

module morph_spi_tb;

    logic clk = 0;
    logic rst_n = 0;
    logic prog_mode = 1;
    logic rx = 1;
    logic [7:0] gpio_in_pins = 0;
    logic [7:0] tx_byte = 8'hA5;

    wire [7:0] gpio_out_pins;
    wire [7:0] gpio_oe;
    wire [7:0] debug_pc;
    wire spi_sclk = gpio_out_pins[0];
    wire spi_mosi = gpio_out_pins[1];
    wire spi_cs   = gpio_out_pins[3];

    logic [7:0] received_byte = 0;
    integer bit_count = 0;
    integer errors = 0;
    integer addr = 0;
    integer i;

    always #10 clk = ~clk; // 50 MHz

    morph_top dut (
        .clk(clk),
        .rst_n(rst_n),
        .rx(rx),
        .prog_mode(prog_mode),
        .gpio_in_pins(gpio_in_pins),
        .gpio_out_pins(gpio_out_pins),
        .gpio_oe(gpio_oe),
        .debug_pc(debug_pc)
    );

    // Emit a 16-bit CPU instruction.
    task automatic emit(input logic [15:0] inst);
        begin
            if (addr >= 256) begin
                $display("FAIL: Program exceeds instruction memory");
                $fatal(1);
            end

            dut.cpu.u_instruction_memory.memory[addr] = inst;
            addr = addr + 1;
        end
    endtask

    // Write an 8-bit GPIO output value using R1.
    task automatic write_gpio(input logic [7:0] value);
        begin
            emit({8'h24, value}); // LOADI R1, value
            emit(16'h7400);       // OUT R1
        end
    endtask

    // WAIT R2, where R2 was initialized to 5.
    task automatic delay_spi;
        begin
            emit(16'h9800); // WAIT R2
        end
    endtask

    // Observe rising SCLK edges while CS is low.
    always @(posedge gpio_out_pins[0]) begin
        if (rst_n &&
            !prog_mode &&
            gpio_out_pins[3] === 1'b0) begin

            if (gpio_oe[0] !== 1'b1 ||
                gpio_oe[1] !== 1'b1 ||
                gpio_oe[3] !== 1'b1) begin
                $display("FAIL: SPI output directions incorrect");
                errors = errors + 1;
            end

            if (bit_count < 8) begin
                received_byte = {
                    received_byte[6:0],
                    gpio_out_pins[1]
                };
                bit_count = bit_count + 1;

                $display(
                    "SPI sample %0d: MOSI=%b time=%0t",
                    bit_count, gpio_out_pins[1], $time
                );
            end
            else begin
                $display("FAIL: Unexpected extra SPI clock");
                errors = errors + 1;
            end
        end
    end

    initial begin
        $dumpfile("morph_spi.vcd");
        $dumpvars(0, morph_spi_tb);

        // Prepare the program while the CPU is held in reset.
        addr = 0;

        emit(16'h200B); // LOADI R0, 0x0B (direction mask)
        emit(16'h6000); // DIR R0
        emit(16'h2805); // LOADI R2, 5 (delay)

        write_gpio(8'h08); // CS=1, SCLK=0, MOSI=0
        delay_spi();

        write_gpio(8'h02); // CS=0, MOSI=1, SCLK=0
        delay_spi();

        // Transmit 0xA5 = 10100101, MSB first.
        for (i = 7; i >= 0; i = i - 1) begin
            // SCLK low, MOSI = current bit
            write_gpio({6'b0, tx_byte[i], 1'b0});
            delay_spi();

            // SCLK high, MOSI unchanged
            write_gpio({6'b0, tx_byte[i], 1'b1});
            delay_spi();
        end

        write_gpio(8'h00); // SCLK low
        delay_spi();

        write_gpio(8'h08); // CS high, transaction finished

        // Jump to the current address indefinitely.
        emit(16'h3000 | addr[7:0]);

        // Release reset and start the CPU.
        repeat (3) @(negedge clk);
        rst_n = 1;

        repeat (2) @(negedge clk);
        prog_mode = 0;

        // Allow enough time for all instructions.
        repeat (400) @(posedge clk);
        #1;

        $display("");
        $display("==================================");
        $display("SPI bits sampled: %0d", bit_count);
        $display("SPI received byte: %02h", received_byte);
        $display("Expected byte: A5");

        if (bit_count == 8 &&
            received_byte === 8'hA5 &&
            errors == 0 &&
            gpio_out_pins[3] === 1'b1) begin
            $display("PASS: MORPH SPI Mode 0 TX");
        end
        else begin
            $display("FAIL: MORPH SPI Mode 0 TX");
            errors = errors + 1;
        end

        $display("==================================");
        $finish;
    end

endmodule
