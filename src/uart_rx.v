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
            shift_reg <= 0;
            rx_prev <= 1'b1;
            done_pulse <= 1'b0;
            err_pulse <= 1'b0;
        end
        else if (rst) begin
            state <= ST_IDLE;
            baud_counter <= 0;
            bit_counter <= 0;
            shift_reg <= 0;
            rx_prev <= 1'b1;
            done_pulse <= 1'b0;
            err_pulse <= 1'b0;
        end
        else begin
            rx_prev <= RX;
            done_pulse <= 1'b0;
            err_pulse <= 1'b0;
            
            case (state)
                ST_IDLE: begin
                    if (rx_en && rx_prev && ~RX) begin // Falling edge detected
                        state <= ST_SYNC;
                        baud_counter <= BAUD_TICK_HALF - 1;
                    end
                end

                ST_SYNC: begin
                    if (baud_counter > 0) begin
                        baud_counter <= baud_counter - 1;
                    end
                    else begin
                        state <= ST_SAMPLE;
                        baud_counter <= BAUD_TICK_FULL;
                        bit_counter <= 0;
                        shift_reg <= 0; // Clear previous data
                    end
                end

                ST_SAMPLE: begin
                    if (baud_counter > 0) begin
                        baud_counter <= baud_counter - 1;
                    end
                    else begin
                        baud_counter <= BAUD_TICK_FULL;
                        shift_reg <= {RX, shift_reg[9:1]};
                        
                        if (bit_counter < 9) begin
                            bit_counter <= bit_counter + 1;
                        end
                        else begin
                            state <= ST_IDLE;
                            if (RX == 1'b1) begin // Check for valid stop bit
                                done_pulse <= 1'b1;
                            end
                            else begin
                                err_pulse <= 1'b1;
                            end
                        end
                    end
                end
                
            endcase
        end
    end
    
endmodule
