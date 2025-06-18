`default_nettype none

module tt_um_equipo7 (
    /* verilator lint_off UNUSED */
    input  wire [7:0] ui_in,
    input  wire       ena,
    /* verilator lint_on UNUSED */
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       clk,
    input  wire       rst_n   // requerido por la plantilla Tiny Tapeout
);

    wire tx_busy, tx_sn, rx_valid, rx_err;
    wire [7:0] rx_data;

    wire [4:0] cfg = {
        ui_in[6],        // stop_sel
        ~ui_in[5],       // parity_en (inverted)
        ui_in[4],        // parity_even
        ui_in[3:2]       // data_len[1:0]
    };

    reg have_data;
    reg [7:0] hold_rx_data;
    wire rst = ~rst_n;  // reset activo en bajo

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            have_data <= 0;
            hold_rx_data <= 0;
        end else begin
            if (rx_valid) begin
                have_data <= 1;
                hold_rx_data <= rx_data;
            end else if (ui_in[1]) begin  // tx_req
                have_data <= 0;
            end
        end
    end

    uart_core core_inst (
        .clk(clk),
        .rst(rst),
        .cfg(cfg),
        .tx_data(uio_in),
        .tx_req(ui_in[1]),
        .tx_busy(tx_busy),
        .tx_sn(tx_sn),
        .rx_sn(ui_in[7]),
        .rx_data(rx_data),
        .rx_valid(rx_valid),
        .rx_err(rx_err),
        .clk16(ui_in[2])
    );

    assign uo_out[0] = tx_sn;
    assign uo_out[1] = tx_busy;
    assign uo_out[2] = have_data;
    assign uo_out[3] = rx_err;
    assign uo_out[7:4] = 4'b0;

    assign uio_out = hold_rx_data;
    assign uio_oe = have_data ? 8'hFF : 8'h00;

endmodule
