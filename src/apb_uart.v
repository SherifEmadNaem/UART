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

    transmitter transmitter_UART (
        .tx_en      (ctrl_reg[0]),
        .data       (tx_data_reg[7:0]),
        .arst_n     (PRESETn),
        .rst        (ctrl_reg[1]),
        .clk        (PCLK),
        .TX         (tx_wire),
        .busy       (tx_busy),
        .done       (tx_done)
    );

    receiver receiver_UART (
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
                    32'hDEADBEEF; 

    always @(posedge PCLK or negedge PRESETn) begin
        if (~PRESETn) begin
            state <= S_IDLE;
            ctrl_reg <= 32'b0;
            tx_data_reg <= 32'b0;
        end
        else begin
            case (state)
                S_IDLE: begin
                    if (PSEL) begin
                        state <= S_SETUP;
                    end
                end

                S_SETUP: begin
                    if (PENABLE) begin
                        state <= S_ACCESS;
                    end else if (~PSEL) begin
                        state <= S_IDLE;
                    end
                end

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
