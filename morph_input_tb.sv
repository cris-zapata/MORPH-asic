
`timescale 1ns/1ps

module morph_input_tb;

    logic clk;
    logic rst_n;
    logic rx;
    logic prog_mode;

    logic [7:0] gpio_in_pins;
    wire [7:0] gpio_out_pins;
    wire [7:0] gpio_oe;
    wire [7:0] debug_pc;

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

    always #10 clk = ~clk;

    initial begin
        $dumpfile("morph_input.vcd");
        $dumpvars(0, morph_input_tb);

        clk = 0;
        rst_n = 0;
        rx = 1;
        prog_mode = 1;
        gpio_in_pins = 8'hA5;

        // Load program into instruction memory
        
        
        dut.cpu.u_instruction_memory.memory[0] = 16'h8800;
        dut.cpu.u_instruction_memory.memory[1] = 16'h20FF;
        dut.cpu.u_instruction_memory.memory[2] = 16'h6000;
        dut.cpu.u_instruction_memory.memory[3] = 16'h7800;
        dut.cpu.u_instruction_memory.memory[4] = 16'h3004;


        #40;
        rst_n = 1;

        #40;
        prog_mode = 0;

        #200;
        $display("R2 = %h", dut.cpu.u_reg_file.registers[2]);
        $display("GPIO OUT = %h", gpio_out_pins);
        $display("GPIO OE = %h", gpio_oe);
        $display("PC = %h", debug_pc);

        if (gpio_out_pins !== 8'hA5)
            $display("FAIL: Incorrect GPIO output");
        else if (gpio_oe !== 8'hFF)
            $display("FAIL: Incorrect GPIO direction");
        else
            $display("PASS: GPIO input/output test");

        $finish;
    end

endmodule
