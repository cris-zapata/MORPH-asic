
`timescale 1ns/1ps

module morph_spi_full_duplex_tb;

    logic clk = 0;
    logic rst_n = 0;
    logic rx = 1;
    logic prog_mode = 0;

    wire [7:0] gpio_in_pins;
    wire [7:0] gpio_out_pins;
    wire [7:0] gpio_oe;
    wire [7:0] debug_pc;

    // 50 MHz CPU clock
    always #10 clk = ~clk;

    // ============================================
    // MORPH DUT
    // ============================================

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

    // SPI pin assignments
    wire spi_sclk = gpio_out_pins[0];
    wire spi_mosi = gpio_out_pins[1];
    wire spi_cs   = gpio_out_pins[3];

    logic spi_miso = 0;

    // Connect slave MISO to MORPH GPIO bit 2
    assign gpio_in_pins = {5'b0, spi_miso, 2'b0};

    localparam logic [7:0] MASTER_TX = 8'hA5;
    localparam logic [7:0] SLAVE_TX  = 8'h3C;

    logic [7:0] slave_rx = 0;

    integer sample_count = 0;
    integer slave_bit_index = 7;

    integer addr = 0;
    integer i;

    // ============================================
    // INSTRUCTION MEMORY HELPERS
    // ============================================

    task automatic emit(input logic [15:0] inst);
        begin
            if (addr >= 256)
                $fatal(1, "Program exceeds instruction memory");

            dut.cpu.u_instruction_memory.memory[addr] = inst;
            addr = addr + 1;
        end
    endtask

    // LOADI R0, value
    // OUT R0
    task automatic write_gpio(input logic [7:0] value);
        begin
            emit({8'h20, value});
            emit(16'h7000);
        end
    endtask

    // Read MISO and assemble receive byte in R1
    task automatic sample_miso;
        begin
            emit(16'h8800); // IN R2
            emit(16'h1B40); // AND R2, R3
            emit(16'h18E0); // SHR R2
            emit(16'h18E0); // SHR R2
            emit(16'h14C0); // SHL R1
            emit(16'h1660); // OR R1, R2
        end
    endtask

    // ============================================
    // SIMULATED SPI MODE 0 SLAVE
    // ============================================

    // Prepare the first outgoing bit when CS falls
    always @(negedge spi_cs) begin
        slave_bit_index = 7;
        slave_rx = 8'h00;
        sample_count = 0;
        spi_miso = SLAVE_TX[7];
    end

    // Update MISO on falling SCLK edges
    always @(negedge spi_sclk) begin
        if (spi_cs === 1'b0 &&
            sample_count > 0 &&
            slave_bit_index > 0) begin

            slave_bit_index = slave_bit_index - 1;
            spi_miso = SLAVE_TX[slave_bit_index];
        end
    end

    // Capture MOSI on rising SCLK edges
    always @(posedge spi_sclk) begin
        if (spi_cs === 1'b0) begin

            slave_rx = {slave_rx[6:0], spi_mosi};
            sample_count = sample_count + 1;

            $display(
                "SPI bit %0d: MOSI=%b MISO=%b",
                sample_count, spi_mosi, spi_miso
            );
        end
    end

    // ============================================
    // PROGRAM MORPH
    // ============================================

    initial begin

        $dumpfile("morph_spi_full_duplex.vcd");
        $dumpvars(0, morph_spi_full_duplex_tb);

        addr = 0;

        // Configure GPIO directions
        // bit 0 = SCLK output
        // bit 1 = MOSI output
        // bit 2 = MISO input
        // bit 3 = CS output

        emit(16'h200B); // LOADI R0, 0x0B
        emit(16'h6000); // DIR R0

        // Initialize receive accumulator
        emit(16'h2400); // LOADI R1, 0x00

        // Load MISO mask
        emit(16'h2C04); // LOADI R3, 0x04

        // SPI idle: CS high, SCLK low
        write_gpio(8'h08);

        // Transfer 8 bits MSB first
        for (i = 7; i >= 0; i = i - 1) begin

            // SCLK LOW, CS LOW
            // MOSI contains current TX bit
            write_gpio({6'b0, MASTER_TX[i], 1'b0});

            // SCLK HIGH
            // Slave captures MOSI
            write_gpio({6'b0, MASTER_TX[i], 1'b1});

            // MORPH reads MISO and assembles byte
            sample_miso();

        end

        // Finish transfer
        write_gpio(8'h00); // SCLK low
        write_gpio(8'h08); // CS high

        // Infinite loop at final address
        emit(16'h3000 | addr[7:0]);

        $display("Program size: %0d instructions", addr);

        // Release reset
        #80;
        rst_n = 1;

        // Wait until all 8 bits have been transferred
        wait(sample_count == 8 && spi_cs === 1'b1);

        repeat (3) @(negedge clk);

        // ========================================
        // VERIFY RESULTS
        // ========================================

        $display("");
        $display("================================");
        $display(" MORPH SPI FULL-DUPLEX RESULTS");
        $display("================================");

        $display("Slave received: %02h", slave_rx);

        $display("MORPH received: %02h",
            dut.cpu.u_reg_file.registers[1]);

        $display("SPI bits sampled: %0d", sample_count);

        if (sample_count !== 8)
            $fatal(1, "FAIL: Incorrect number of SPI bits");

        if (slave_rx !== MASTER_TX)
            $fatal(1, "FAIL: Slave received incorrect byte");

        if (dut.cpu.u_reg_file.registers[1] !== SLAVE_TX)
            $fatal(1, "FAIL: MORPH received incorrect byte");

        if (gpio_oe !== 8'h0B)
            $fatal(1, "FAIL: Incorrect GPIO direction");

        $display("");
        $display("PASS: MORPH SPI FULL-DUPLEX");
        $display("");

        $finish;

    end

    // Simulation timeout
    initial begin
        #100000;
        $fatal(1, "FAIL: SPI simulation timeout");
    end

endmodule
