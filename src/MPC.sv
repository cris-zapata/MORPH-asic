module MPC (
    input  logic clk,
    input  logic rst_n,
    input  logic arbitration_lost,
    input  logic clear_arbitration,
    output logic arbitration_lost_reg
);
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        arbitration_lost_reg <= 1'b0;
    end
    else if (arbitration_lost) begin
        arbitration_lost_reg <= 1'b1;
    end
    else if (clear_arbitration) begin
        arbitration_lost_reg <= 1'b0;
    end
end
endmodule
module program_counter (
    input logic clk,
    input logic rst_n,
    input logic jump_en,
    input logic pc_en,
    input logic [7:0] jump_address,
    output logic [7:0] pc
);
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pc <= 8'd0;
    end
    else if (pc_en) begin
        if (jump_en) begin
            pc <= jump_address;
        end
        else begin
            pc <= pc + 1'b1;
        end
    end
end
endmodule
//instructions starting point
module instruction_memory (
    input logic clk,
    input logic write_en,
    input logic [7:0] write_address,
    input logic [15:0] write_data,
    input logic [7:0] address,
    output logic [15:0] instruction
);
logic [15:0] memory [0:255];
//comb inst read
assign instruction = memory[address];
//sync inst write
always_ff @(posedge clk) begin
    if (write_en) begin
        memory[write_address] <= write_data;
    end
end
endmodule
//register file module design
module reg_file (
    input logic clk,
    input logic rst_n,
    input logic write_en,
    input logic [1:0] write_address,
    input logic [7:0] write_data,
    input logic [1:0] read_address_a,
    input logic [1:0] read_address_b,
    output logic [7:0] read_data_a,
    output logic [7:0] read_data_b
);
logic [7:0] registers [0:3];
//R&W logic:
integer i;
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (i = 0; i < 4; i = i + 1) begin
            registers[i] <= 8'd0;
        end
    end
    else if (write_en) begin //write enable is high
        registers[write_address] <= write_data; //write data into write addr
    end
end
assign read_data_a = registers[read_address_a]; //assign read address to read data
assign read_data_b = registers[read_address_b];
endmodule
//alu implementation
module alu (
    input logic [7:0] a,
    input logic [7:0] b,
    output logic [7:0] result,
    input logic [2:0] op,
    output logic carry,
    output logic zero
);
logic [8:0] arithmetic_result;
always_comb begin
    //8 operations
    case (op)
    3'b000: arithmetic_result = {1'b0, a} + {1'b0, b};
    3'b001: arithmetic_result = {1'b0, a} - {1'b0, b};
    3'b010: arithmetic_result = {1'b0, a} & {1'b0, b};
    3'b011: arithmetic_result = {1'b0, a} | {1'b0, b};
    3'b100: arithmetic_result = {1'b0, a} ^ {1'b0, b};
    3'b101: arithmetic_result = {1'b0, ~a};
    3'b110: arithmetic_result = {1'b0, (a << 1)};
    3'b111: arithmetic_result = {1'b0, (a >> 1)};
    default: arithmetic_result = 9'd0;
    endcase
end
//result, carry-flag, zero-flag
assign result = arithmetic_result[7:0];
assign carry = arithmetic_result[8];
assign zero = (result == 8'b0);
endmodule
//instruction decoder
module instruction_decoder (
    input logic [15:0] instruction,
    input logic z_flag,
    output logic jump_en,
    output logic [7:0] jump_address,
    output logic reg_write_en,
    output logic [1:0] writeback_sel,
    output logic gpio_we,
    output logic gpio_sel,
    output logic wait_en
);
logic [3:0] opcode; //cpu instruction
logic [11:0] operand; // remaining space for regs and unused bits
assign opcode = instruction[15:12];
assign operand = instruction[11:0];
always_comb begin
    jump_en = 1'b0;
    jump_address = 8'd0;
    reg_write_en = 1'b0;
    writeback_sel = 2'b00;
    wait_en = 1'b0;
    gpio_we = 1'b0;
    gpio_sel = 1'b0;
    case (opcode)
    4'b0001: begin
        reg_write_en = 1'b1;
        end
    4'b0010: begin
        reg_write_en = 1'b1;
        writeback_sel = 2'b01;
        end
    4'b0011: begin
        jump_en = 1'b1;
        jump_address = operand[7:0];
        end
    4'b0100: begin
        if (z_flag) begin
            jump_en = 1'b1;
            jump_address = operand[7:0];
            end
        end
    4'b0101: begin
        if (!z_flag) begin
            jump_en = 1'b1;
            jump_address = operand[7:0];
            end
        end
    4'b0110: begin
        gpio_we = 1'b1;
        gpio_sel = 1'b1;
    end
    4'b0111: begin
        gpio_we = 1'b1;
        gpio_sel = 1'b0;
    end
    4'b1000: begin
        reg_write_en = 1'b1;
        writeback_sel = 2'b10;
    end
    4'b1001: begin
        wait_en = 1'b1;
    end
    default: begin
    end
    endcase
end
endmodule
/*
// uart transmitter implementation
module uart_tx (
    input logic clk,
    input logic rst_n,
    input logic [7:0] tx_data,
    input logic tx_start,
    output logic tx,
    output logic tx_busy
);
logic [7:0] tx_buffer;
logic [8:0] baud_counter;
logic [2:0] bit_counter;
logic baud_enable;
logic baud_tck;
// UART FSM declarations
typedef enum logic [1:0] {
    IDLE,
    START,
    DATA,
    STOP
} uart_state_t;
uart_state_t c, n;
assign baud_enable = (c != IDLE);
assign tx_busy = baud_enable;
assign baud_tck = (baud_counter == 9'd433) && baud_enable; //9 bit value for baud_tck
// Baud rate counter
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        baud_counter <= 9'd0;
    end
    else if (!baud_enable) begin
        baud_counter <= 9'd0;
    end
    else if (baud_counter == 9'd433) begin
        baud_counter <= 9'd0;
    end
    else begin
        baud_counter <= baud_counter + 1'b1;
    end
end
// FSM state regs
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        c <= IDLE;
    end
    else begin
        c <= n;
    end
end
// FSM next state logic
always_comb begin
    n = c;
    case (c)
    IDLE: begin
        if (tx_start) begin
            n = START;
        end
    end
    START: begin
        if (baud_tck) begin
            n = DATA;
        end
    end
    DATA: begin
        if (bit_counter == 3'd7 && baud_tck) begin
            n = STOP;
        end
    end
    STOP: begin
        if (baud_tck) begin
            n = IDLE;
        end
    end
    default: begin
        n = IDLE;
    end
endcase
end
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        bit_counter <= 3'd0;
    end
    else if (c != DATA) begin
        bit_counter <= 3'd0;
    end
    else if (c == DATA && baud_tck) begin
        bit_counter <= bit_counter + 1'b1;
    end
end
always_comb begin
    tx = 1'b1;
    case (c)
    IDLE: begin
        tx = 1'b1;
    end
    START: begin
        tx = 1'b0;
    end
    DATA: begin
        tx = tx_buffer[bit_counter];  
    end
    STOP: begin
        tx = 1'b1;
    end
    default: begin
        tx = 1'b1;
    end
endcase
end
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        tx_buffer <= 8'd0;
    end
    else if (c == IDLE && tx_start) begin
        tx_buffer <= tx_data;
    end
end
endmodule //end of uart implementation
*/
//program loader module for external readings
module uart_rx (
    input logic clk,
    input logic rst_n,
    input logic rx,
    output logic [7:0] rx_data,
    output logic rx_valid
);
typedef enum logic [1:0] {
    IDLE,
    START,
    DATA,
    STOP
} state_t;
state_t c, n;
logic [8:0] baud_counter;
logic [2:0] bit_counter;
localparam  integer CLKS_PER_BIT = 434;
localparam integer HALF_BIT = 217;
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        baud_counter <= 9'b0;
        bit_counter <= 3'b0;
        rx_data <= 8'b0;
    end
    else begin
        if (c == IDLE) begin
            bit_counter <= 3'b0;
            baud_counter <= 9'b0;
        end
        else if (c == START) begin
            if (baud_counter == HALF_BIT - 1) begin
                baud_counter <= 9'b0;
            end
            else begin
                baud_counter <= baud_counter + 1'b1;
            end
        end
        else if (c == DATA) begin
            if (baud_counter == CLKS_PER_BIT - 1) begin
                baud_counter <= 9'b0;
                bit_counter <= bit_counter + 1'b1;
                rx_data[bit_counter] <= rx;
            end
            else begin
                baud_counter <= baud_counter + 1'b1;
            end
        end
        else if (c == STOP) begin
            if (baud_counter == CLKS_PER_BIT - 1) begin
                 baud_counter <= 9'b0;
            end
            else begin
                baud_counter <= baud_counter + 1'b1;
            end
        end
    end
end
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        c <= IDLE;
    end
    else begin
        c <= n;
    end
end
always_comb begin
    n = c;
    case(c)
    IDLE: begin
        if (!rx) begin
            n = START;
        end
    end
    START: begin
        if (baud_counter == HALF_BIT -1) begin
            if (!rx) begin
                n = DATA;
            end
            else begin
                n = IDLE;
            end
        end
    end
    DATA: begin
        if (baud_counter == CLKS_PER_BIT -1 && bit_counter == 3'd7) begin
            n = STOP;
        end
    end
    STOP: begin
        if (baud_counter == CLKS_PER_BIT - 1) begin
            n = IDLE;
        end
    end
    default: begin
        n = IDLE;
    end
endcase
end
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rx_valid <= 1'b0;
    end
    else begin
        rx_valid <= 1'b0;
        if (c == STOP && baud_counter == CLKS_PER_BIT - 1 && rx) begin
            rx_valid <= 1'b1;
        end
    end
end
endmodule
module program_loader (
    input logic clk,
    input logic rst_n,
    input logic [7:0] rx_data,
    input logic rx_valid,
    output logic [7:0] prog_addr,
    output logic [15:0] prog_data,
    output logic prog_we
);
typedef enum logic [1:0] {
    WAIT_ADDR,
    WAIT_HIGH,
    WAIT_LOW,
    WRITE_MEM
} state_t;
state_t c, n;
assign prog_we = (c == WRITE_MEM);
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        c <= WAIT_ADDR;
    end
    else begin
        c <= n;
    end
end
always_comb begin
    n = c;
    case(c)
    WAIT_ADDR: begin
        if (rx_valid) begin
            n = WAIT_HIGH;
        end
    end
    WAIT_HIGH: begin
        if (rx_valid) begin
            n = WAIT_LOW;
        end
    end
    WAIT_LOW: begin
        if (rx_valid) begin
            n = WRITE_MEM;
        end
    end
    WRITE_MEM: begin
        n = WAIT_ADDR;
    end
    default: n = WAIT_ADDR;
    endcase
end
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        prog_addr <= 8'h00;
        prog_data <= 16'h0000;
    end
    else begin
        if (c == WAIT_ADDR && rx_valid) begin
            prog_addr <= rx_data;
        end
        if (c == WAIT_HIGH && rx_valid) begin
            prog_data[15:8] <= rx_data;
        end
        if (c == WAIT_LOW && rx_valid) begin
            prog_data[7:0] <= rx_data;
        end
    end
end
endmodule //end of program loader
module cpu_core (
    input logic clk,
    input logic rst_n,
    input logic prog_we,
    input logic [7:0] prog_addr,
    input logic [15:0] prog_data,
    input logic prog_mode,
    input logic [7:0] gpio_rdata,
    output logic [7:0] debug_pc,
    output logic [7:0] gpio_wdata,
    output logic gpio_we,
    output logic gpio_sel
);
logic [7:0] alu_result;
logic [15:0] instruction;
logic [7:0] reg_write_data;
logic [7:0] reg_data_a; //8-bit bus for a
logic [7:0] reg_data_b; //8_bit bus for b
logic [1:0] reg_write_address; //which reg recieves given result
logic reg_write_en;
logic [1:0] writeback_sel;
logic [2:0] alu_op; //alu op for cpu mod
logic alu_carry; //alu carry for cpu mod
logic alu_zero; // alu zero for cpu mod
logic [7:0] pc; // current instruction container
logic [7:0] jump_address; // destination of jmp
logic jump_en; // tells pc to jmp
logic pc_en; // pc incrementation
logic z_flag; // zero flag
logic flag_write_en; // if on cpu updates, if off no update
logic gpio_write_decoded;
logic wait_done;
logic wait_en;
logic [7:0] wait_counter;
logic wait_active;
assign wait_done = wait_active && (wait_counter == 8'd1);
assign gpio_wdata = reg_data_a;
assign gpio_we = gpio_write_decoded && !prog_mode;
assign debug_pc = pc;
assign reg_write_address = instruction[11:10];
assign alu_op = instruction[7:5];
assign pc_en = !prog_mode && (
    !wait_en || (wait_en && !wait_active && reg_data_a <= 8'd1) || wait_done
);
assign flag_write_en = (instruction[15:12] == 4'b0001) && !prog_mode;
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        wait_counter <= 8'd0;
        wait_active  <= 1'b0;
    end
    else if (!prog_mode) begin
        if (wait_active) begin
            if (wait_counter > 8'd1) begin
                wait_counter <= wait_counter - 1'b1;
            end
            else begin
                wait_counter <= 8'd0;
                wait_active  <= 1'b0;
            end
        end
        else if (wait_en && reg_data_a > 8'd1) begin
            wait_counter <= reg_data_a - 1'b1;
            wait_active  <= 1'b1;
        end
    end
end
always_comb begin
    case (writeback_sel)
    2'b00: reg_write_data = alu_result;
    2'b01: reg_write_data = instruction[7:0];
    2'b10: reg_write_data = gpio_rdata;
    default: reg_write_data = 8'b0;
    endcase
end
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        z_flag <= 1'b0;
        end
        else if (flag_write_en) begin
            z_flag <= alu_zero;
        end
    end
// insatiating mods into main cpu mod
reg_file u_reg_file (
    .clk(clk),
    .rst_n(rst_n),
    .write_en(reg_write_en & !prog_mode),
    .write_address(reg_write_address),
    .write_data(reg_write_data),
    .read_address_a(instruction[11:10]),
    .read_address_b(instruction[9:8]),
    .read_data_a(reg_data_a),
    .read_data_b(reg_data_b)
);
alu u_alu (
    .a(reg_data_a),
    .b(reg_data_b),
    .result(alu_result),
    .op(alu_op),
    .carry(alu_carry),
    .zero(alu_zero)
);
program_counter u_program_counter (
    .clk(clk),
    .rst_n(rst_n),
    .pc(pc),
    .jump_address(jump_address),
    .jump_en(jump_en),
    .pc_en(pc_en)
);
instruction_memory u_instruction_memory (
    .clk(clk),
    .write_en(prog_we),
    .write_address(prog_addr),
    .write_data(prog_data),
    .address(pc),
    .instruction(instruction)
);
instruction_decoder u_instruction_decoder (
    .instruction(instruction),
    .z_flag(z_flag),
    .jump_en(jump_en),
    .jump_address(jump_address),
    .reg_write_en(reg_write_en),
    .writeback_sel(writeback_sel),
    .gpio_we(gpio_write_decoded),
    .gpio_sel(gpio_sel),
    .wait_en(wait_en)
);
endmodule
//top module
module morph_top (
    input logic clk,
    input logic rst_n,
    input logic rx,
    input logic prog_mode,
    input logic [7:0] gpio_in_pins,
    output logic [7:0] gpio_out_pins,
    output logic [7:0] gpio_oe,
    output logic [7:0] debug_pc
);
logic [7:0] gpio_wdata;
logic gpio_we;
logic gpio_sel;
logic [7:0] gpio_rdata;
logic [7:0] rx_data;
logic rx_valid;
logic [7:0] prog_addr;
logic [15:0] prog_data;
logic prog_we;
uart_rx uart_receiver (
    .clk(clk),
    .rst_n(rst_n),
    .rx(rx),
    .rx_data(rx_data),
    .rx_valid(rx_valid)
);
program_loader loader (
    .clk(clk),
    .rst_n(rst_n),
    .rx_data(rx_data),
    .rx_valid(rx_valid),
    .prog_addr(prog_addr),
    .prog_data(prog_data),
    .prog_we(prog_we)
);
cpu_core cpu (
    .clk(clk),
    .rst_n(rst_n),
    .prog_we(prog_we && prog_mode),
    .prog_addr(prog_addr),
    .prog_data(prog_data),
    .prog_mode(prog_mode),
    .debug_pc(debug_pc),
    .gpio_wdata(gpio_wdata),
    .gpio_we(gpio_we),
    .gpio_sel(gpio_sel),
    .gpio_rdata(gpio_rdata)
);
gpio_controller gpio (
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
endmodule
//GPIO Controller
module gpio_controller (
    input logic clk,
    input logic rst_n,
    input logic [7:0] gpio_wdata,
    input logic gpio_we,
    input logic gpio_sel,
    input logic [7:0] gpio_in_pins,
    output logic [7:0] gpio_out_pins,
    output logic [7:0] gpio_oe,
    output logic [7:0] gpio_rdata
);
logic [7:0] gpio_dir;
logic [7:0] gpio_out;
assign gpio_out_pins = gpio_out;
assign gpio_oe = gpio_dir;
assign gpio_rdata = gpio_in_pins;
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        gpio_out <= 8'b0;
        gpio_dir <= 8'b0;
    end
    else if (gpio_we && !gpio_sel) begin
        gpio_out <= gpio_wdata;
    end
    else if (gpio_we && gpio_sel) begin
        gpio_dir <= gpio_wdata;
    end
end
endmodule