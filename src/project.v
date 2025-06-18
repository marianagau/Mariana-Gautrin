`default_nettype none

module tt_um_equipo7 (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       clk,
    input  wire       ena,
    input  wire       rst_n   // requerido por la plantilla Tiny Tapeout
);
    wire rst = ~rst_n;
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
    wire rst = ~ui_in[0];  // reset activo en bajo

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


module uart_core (
    input        clk,
    input        rst,
    input  [4:0] cfg,
    input  [7:0] tx_data,
    input        tx_req,
    output       tx_busy,
    output       tx_sn,
    input        rx_sn,
    output [7:0] rx_data,
    output       rx_valid,
    output       rx_err,
    input        clk16
);

  localparam T_IDLE=0, T_S=1, T_D=2, T_P=3, T_T=4;
  localparam R_IDLE=0, R_CHK=1, R_REC=2, R_PAR=3, R_TST=4;

  reg [2:0] ts, tr;
  reg [3:0] tcnt, tbit, pcnt;
  reg [7:0] tshift, rshift, rdata_reg;
  reg       rxv, rerr;

  // TX FSM
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      ts <= T_IDLE;
      tshift <= 0;
      tcnt <= 0;
      tbit <= 0;
    end else begin
      case (ts)
        T_IDLE: if (tx_req) begin
                  tshift <= tx_data;
                  ts <= cfg[3] ? T_P : T_S;
                  tcnt <= 0; tbit <= 0;
                end
        T_S: if (clk16)
                if (tcnt == 15) begin tcnt <= 0; ts <= T_D; end
                else tcnt <= tcnt + 1;

        T_D: if (clk16)
                if (tcnt == 15) begin
                  tcnt <= 0;
                  tshift <= tshift >> 1;
                  tbit <= tbit + 1;
                  if (tbit == ({2'b00, cfg[1:0]} + 3)) ts <= T_T;
                end else tcnt <= tcnt + 1;

        T_P: if (clk16)
                if (tcnt == 15) begin tcnt <= 0; ts <= T_T; end
                else tcnt <= tcnt + 1;

        T_T: if (clk16)
                if (tcnt == (cfg[4] ? ({2'b00, cfg[1:0]} + 4) : ({2'b00, cfg[1:0]} + 2)))
                  ts <= T_IDLE;
                else tcnt <= tcnt + 1;
      endcase
    end
  end

  assign tx_sn   = (ts == T_S) ? 1'b0 : tshift[0];
  assign tx_busy = (ts != T_IDLE);

  // RX FSM
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      tr <= R_IDLE;
      rshift <= 0;
      pcnt <= 0;
      rerr <= 0;
      rxv <= 0;
      tcnt <= 0;
    end else begin
      rxv <= 0;
      case (tr)
        R_IDLE: if (!rx_sn) begin tr <= R_CHK; tcnt <= 7; end

        R_CHK: if (clk16)
                 if (tcnt == 0) begin tcnt <= 0; tr <= R_REC; end
                 else tcnt <= tcnt - 1;

        R_REC: if (clk16)
                 if (tcnt == 15) begin
                   tcnt <= 0;
                   rshift <= {rx_sn, rshift[7:1]};
                   pcnt <= pcnt + 1;
                   if (pcnt == ({2'b00, cfg[1:0]} + 4))
                     tr <= cfg[3] ? R_PAR : R_TST;
                 end else tcnt <= tcnt + 1;

        R_PAR: if (clk16)
                 if (tcnt == 15) begin
                   tcnt <= 0;
                   if ((cfg[2] ? ^rshift : ~^rshift) != rx_sn)
                     rerr <= 1;
                   tr <= R_TST;
                 end else tcnt <= tcnt + 1;

        R_TST: if (clk16)
                 if (tcnt == 15) begin
                   rdata_reg <= rshift;
                   rxv <= 1;
                   tr <= R_IDLE;
                 end else tcnt <= tcnt + 1;
      endcase
    end
  end

  assign rx_data  = rdata_reg;
  assign rx_valid = rxv;
  assign rx_err   = rerr;

endmodule
