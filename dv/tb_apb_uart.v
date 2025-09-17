`timescale 1ns/1ps

//////////////////////////////////////////////////////////////////////////////////
//
// Module: Project Testbench
//
//////////////////////////////////////////////////////////////////////////////////
module Project_TB();

    // Parameters for easy configuration
    localparam CLK_PERIOD   = 10; // 10ns -> 100MHz clock
    localparam BAUD_PERIOD  = 10417 * CLK_PERIOD; // Time for one bit

    // APB Address Map
    localparam ADDR_CTRL    = 32'h00;
    localparam ADDR_STATS   = 32'h04;
    localparam ADDR_TX      = 32'h08;
    localparam ADDR_RX      = 32'h0C;
    
    // Testbench Signals
    reg PCLK, PRESETn;
    reg [31:0] PADDR, PWDATA;
    reg PSEL, PENABLE, PWRITE;
    wire [31:0] PRDATA;
    wire PREADY;

        reg [31:0] read_data;
        integer poll_count;
        reg done_flag;
    
    // Instantiate the complete APB-UART system
    APB dut (
        .PCLK(PCLK), .PRESETn(PRESETn), .PADDR(PADDR), .PSEL(PSEL),
        .PENABLE(PENABLE), .PWRITE(PWRITE), .PWDATA(PWDATA),
        .PRDATA(PRDATA), .PREADY(PREADY)
    );

    // Clock Generator
    initial begin
        PCLK = 0;
        forever #(CLK_PERIOD/2) PCLK = ~PCLK;
    end

    // Task for a complete APB write transaction
    task apb_write(input [31:0] addr, input [31:0] data);
        begin
            @(posedge PCLK);
            PSEL    = 1'b1;
            PWRITE  = 1'b1;
            PENABLE = 1'b0;
            PADDR   = addr;
            PWDATA  = data;
            @(posedge PCLK);
            PENABLE = 1'b1;
            wait (PREADY);
            @(posedge PCLK);
            PSEL    = 1'b0;
            PENABLE = 1'b0;
            $display("[%0t ns] APB Write: Addr=0x%h, Data=0x%h", $time, addr, data);
        end
    endtask

    // Task for a complete APB read transaction
    task apb_read(input [31:0] addr, output [31:0] data);
        begin
            @(posedge PCLK);
            PSEL    = 1'b1;
            PWRITE  = 1'b0;
            PENABLE = 1'b0;
            PADDR   = addr;
            @(posedge PCLK);
            PENABLE = 1'b1;
            wait (PREADY);
            data = PRDATA;
            @(posedge PCLK);
            PSEL    = 1'b0;
            PENABLE = 1'b0;
            $display("[%0t ns] APB Read:  Addr=0x%h, Data=0x%h", $time, addr, data);
        end
    endtask

    // Main Test Sequence
    initial begin

        // 1. Initial State & Reset
        PSEL = 0; PENABLE = 0; PWRITE = 0; PADDR = 0; PWDATA = 0;
        PRESETn = 1'b0;
        repeat(5) @(posedge PCLK);
        PRESETn = 1'b1;
        $display("[%0t ns] === DUT Reset Done ===", $time);

        // 2. Loopback Test: Send 0xA5 and verify reception
        $display("\n[%0t ns] --- Test 1: Loopback for 0xA5 ---", $time);
        
        // Correct Order: Write data FIRST, then enable transmission
        apb_write(ADDR_TX,   32'h0000_00A5); // 1. Write data to be sent
        apb_write(ADDR_CTRL, 32'h0000_0005); // 2. Enable TX and RX to start transmission
        
        // Wait for reception to finish by polling the status register
        begin
            // Initialize variables for the loop
            poll_count = 0;
            done_flag = 0;
            while(poll_count < 20 && !done_flag) begin
                apb_read(ADDR_STATS, read_data);
                if (read_data[3]) begin // Check rx_done bit
                    done_flag = 1;
                end else begin
                    #(BAUD_PERIOD);
                    poll_count = poll_count + 1;
                end
            end
        end

        // Verify results
        apb_read(ADDR_RX, read_data);
        if (read_data[7:0] == 8'hA5)
            $display("SUCCESS: Loopback test passed. Received 0x%h.", read_data[7:0]);
        else
            $error("FAILURE: Loopback test failed. Expected 0xA5, got 0x%h.", read_data[7:0]);
        
        // 3. Second Loopback Test: Send 0x34
        $display("\n[%0t ns] --- Test 2: Loopback for 0x34 ---", $time);
        
        // Correct Order: Write data FIRST, then enable transmission
        apb_write(ADDR_TX,   32'h0000_0034); // 1. Write data to be sent
        apb_write(ADDR_CTRL, 32'h0000_0005); // 2. Enable TX and RX to start transmission
        
        begin
            // Re-initialize the same variables for the next loop
            poll_count = 0;
            done_flag = 0;
            while(poll_count < 20 && !done_flag) begin
                apb_read(ADDR_STATS, read_data);
                if (read_data[3]) begin // Check rx_done bit
                    done_flag = 1;
                end else begin
                    // use BAUD_PERIOD here as well (consistent)
                    #(BAUD_PERIOD);
                    poll_count = poll_count + 1;
                end
            end
        end

        apb_read(ADDR_RX, read_data);
        if (read_data[7:0] == 8'h34)
            $display("SUCCESS: Loopback test passed. Received 0x%h.", read_data[7:0]);
        else
            $error("FAILURE: Loopback test failed. Expected 0x34, got 0x%h.", read_data[7:0]);

        $display("\n[%0t ns] === All tests complete. ===", $time);
        $finish;
    end

endmodule

//////////////////////////////////////////////////////////////////////////////////
//
// Module: APB Slave Bridge for UART
//
//////////////////////////////////////////////////////////////////////////////////
module APB
(
    input               PCLK,
    input               PRESETn,
    input       [31:0]  PADDR,
    input               PSEL,
    input               PENABLE,
    input               PWRITE,
    input       [31:0]  PWDATA,
    output      [31:0]  PRDATA,
    output              PREADY
);

    localparam ADDR_CTRL   = 32'h00;
    localparam ADDR_STATS  = 32'h04;
    localparam ADDR_TX     = 32'h08;
    localparam ADDR_RX     = 32'h0C;
    
    wire sel_ctrl  = (PADDR == ADDR_CTRL);
    wire sel_stats = (PADDR == ADDR_STATS);
    wire sel_tx    = (PADDR == ADDR_TX);
    wire sel_rx    = (PADDR == ADDR_RX);

    localparam S_IDLE   = 2'b00;
    localparam S_SETUP  = 2'b01;
    localparam S_ACCESS = 2'b10;
    reg [1:0] state;
    
    reg [31:0] ctrl_reg;
    reg [31:0] tx_data_reg;
    
    wire [31:0] stats_reg;
    wire [31:0] rx_data_reg;

    wire tx_wire;
    wire tx_busy, tx_done;
    wire rx_busy, rx_done, rx_err;
    wire [7:0] rx_data_wire;

    transmitter tx_inst (
        .tx_en      (ctrl_reg[0]),
        .data       (tx_data_reg[7:0]),
        .arst_n     (PRESETn),
        .rst        (ctrl_reg[1]),
        .clk        (PCLK),
        .TX         (tx_wire),
        .busy       (tx_busy),
        .done       (tx_done)
    );

    receiver rx_inst (
        .clk        (PCLK),
        .rst        (ctrl_reg[3]),
        .arst_n     (PRESETn),
        .rx_en      (ctrl_reg[2]),
        .RX         (tx_wire),
        .busy       (rx_busy),
        .done       (rx_done),
        .err        (rx_err),
        .data       (rx_data_wire)
    );

    assign stats_reg = {27'b0, rx_err, rx_done, rx_busy, tx_done, tx_busy};
    assign rx_data_reg = {24'b0, rx_data_wire};
    assign PREADY = (state == S_ACCESS);
    assign PRDATA = sel_ctrl  ? ctrl_reg    :
                    sel_stats ? stats_reg   :
                    sel_tx    ? tx_data_reg :
                    sel_rx    ? rx_data_reg :
                    32'h0;

    always @(posedge PCLK or negedge PRESETn) begin
        if (~PRESETn) begin
            state <= S_IDLE;
            ctrl_reg <= 32'b0;
            tx_data_reg <= 32'b0;
        end else begin
            case (state)
                S_IDLE: if (PSEL) state <= S_SETUP;
                S_SETUP: if (PENABLE) state <= S_ACCESS; else if (~PSEL) state <= S_IDLE;
                S_ACCESS: begin
                    state <= S_IDLE;
                    if (PWRITE) begin
                        if (sel_ctrl) ctrl_reg <= PWDATA;
                        if (sel_tx)   tx_data_reg <= PWDATA;
                    end
                end
                default: state <= S_IDLE;
            endcase
        end
    end
endmodule

//////////////////////////////////////////////////////////////////////////////////
//
// Module: UART Transmitter
//
//////////////////////////////////////////////////////////////////////////////////
module transmitter
(
    input               tx_en,
    input       [7:0]   data,
    input               arst_n,
    input               rst,
    input               clk,
    output              TX,
    output              busy,
    output  reg         done
);
    localparam BAUD_TICK_COUNT = 16'd10416;
    localparam ST_IDLE      = 1'b0;
    localparam ST_TRANSMIT  = 1'b1;

    reg             state;
    reg [15:0]      baud_tick_counter;
    reg [3:0]       bit_counter;
    reg [9:0]       shift_reg;

    assign TX = (state == ST_IDLE) ? 1'b1 : shift_reg[0];
    assign busy = (state != ST_IDLE);

    always @(posedge clk or negedge arst_n) begin
        if (~arst_n) begin
            state <= ST_IDLE;
            baud_tick_counter <= 0;
            bit_counter <= 0;
            shift_reg <= {10{1'b1}};
            done <= 1'b0;
        end else if (rst) begin
            state <= ST_IDLE;
            baud_tick_counter <= 0;
            bit_counter <= 0;
            shift_reg <= {10{1'b1}};
            done <= 1'b0;
        end else begin
            done <= 1'b0;
            case (state)
                ST_IDLE: begin
                    if (tx_en) begin
                        state <= ST_TRANSMIT;
                        baud_tick_counter <= BAUD_TICK_COUNT;
                        bit_counter <= 0;
                        // transmit: start (0) -> d0..d7 (LSB first) -> stop (1)
                        // shift_reg[0] is first out, so place bits: {stop, data[7:0], start}
                        shift_reg <= {1'b1, data, 1'b0};
                    end
                end
                ST_TRANSMIT: begin
                    if (baud_tick_counter > 0) begin
                        baud_tick_counter <= baud_tick_counter - 1;
                    end else begin
                        baud_tick_counter <= BAUD_TICK_COUNT;
                        if (bit_counter < 9) begin
                            bit_counter <= bit_counter + 1;
                            shift_reg <= shift_reg >> 1;
                        end else begin
                            state <= ST_IDLE;
                            done <= 1'b1;
                        end
                    end
                end
            endcase
        end
    end
endmodule

//////////////////////////////////////////////////////////////////////////////////
//
// Module: UART Receiver  
//
//////////////////////////////////////////////////////////////////////////////////
module receiver
(
    input               clk,
    input               rst,
    input               arst_n,
    input               rx_en,
    input               RX,
    output              busy,
    output              done,
    output              err,
    output      [7:0]   data
);
    localparam BAUD_TICK_FULL = 14'd10416;
    localparam BAUD_TICK_HALF = 14'd5208;
    localparam ST_IDLE   = 2'b00;
    localparam ST_SYNC   = 2'b01;
    localparam ST_SAMPLE = 2'b10;

    reg [1:0]   state;
    reg [13:0]  baud_counter;
    reg [3:0]   bit_counter;
    reg [9:0]   shift_reg;
    reg         rx_prev;
    reg         done_pulse;
    reg         err_pulse;

    assign busy = (state != ST_IDLE);
    assign data = shift_reg[8:1];
    assign done = done_pulse;
    assign err  = err_pulse;

    always @(posedge clk or negedge arst_n) begin
        if (~arst_n) begin
            state <= ST_IDLE;
            baud_counter <= 0;
            bit_counter <= 0;
            // initialize to idle high
            shift_reg <= {10{1'b1}};
            rx_prev <= 1'b1;
            done_pulse <= 1'b0;
            err_pulse <= 1'b0;
        end else if (rst) begin
            state <= ST_IDLE;
            baud_counter <= 0;
            bit_counter <= 0;
            shift_reg <= {10{1'b1}};
            rx_prev <= 1'b1;
            done_pulse <= 1'b0;
            err_pulse <= 1'b0;
        end else begin
            rx_prev <= RX;
            done_pulse <= 1'b0;
            err_pulse <= 1'b0;
            case (state)
                ST_IDLE: begin
                    if (rx_en && rx_prev && ~RX) begin
                        state <= ST_SYNC;
                        baud_counter <= BAUD_TICK_HALF - 1;
                    end
                end
                ST_SYNC: begin
                    if (baud_counter > 0) begin
                        baud_counter <= baud_counter - 1;
                    end else begin
                        state <= ST_SAMPLE;
                        baud_counter <= BAUD_TICK_FULL;
                        bit_counter <= 0;
                        shift_reg <= {10{1'b1}}; // clear/idle pattern before sampling
                    end
                end
                ST_SAMPLE: begin
                    if (baud_counter > 0) begin
                        baud_counter <= baud_counter - 1;
                    end else begin
                        baud_counter <= BAUD_TICK_FULL;
                        // FIX: append new sample into LSB and shift older bits up
                        // this ensures LSB-first reception ends up in shift_reg[8:1] = {d7..d0}
                        shift_reg <= {shift_reg[8:0], RX};    // <-- CORRECT SHIFT DIRECTION
                        if (bit_counter < 9) begin
                            bit_counter <= bit_counter + 1;
                        end else begin
                            state <= ST_IDLE;
                            if (RX == 1'b1) done_pulse <= 1'b1;
                            else err_pulse <= 1'b1;
                        end
                    end
                end
            endcase
        end
    end
endmodule
