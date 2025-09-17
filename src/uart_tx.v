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
        end
        else if (rst) begin
            state <= ST_IDLE;
            baud_tick_counter <= 0;
            bit_counter <= 0;
            shift_reg <= {10{1'b1}};
            done <= 1'b0;
        end
        else begin
            done <= 1'b0;

            case (state)
                ST_IDLE: begin
                    if (tx_en) begin
                        state <= ST_TRANSMIT;
                        baud_tick_counter <= BAUD_TICK_COUNT;
                        bit_counter <= 0;
                        shift_reg <= {1'b1, data, 1'b0}; // Stop, Data, Start
                    end
                end

                ST_TRANSMIT: begin
                    if (baud_tick_counter > 0) begin
                        baud_tick_counter <= baud_tick_counter - 1;
                    end
                    else begin
                        baud_tick_counter <= BAUD_TICK_COUNT;
                        if (bit_counter < 9) begin
                            bit_counter <= bit_counter + 1;
                            shift_reg <= shift_reg >> 1;
                        end
                        else begin
                            state <= ST_IDLE;
                            done <= 1'b1;
                        end
                    end
                end

            endcase
        end
    end

endmodule
