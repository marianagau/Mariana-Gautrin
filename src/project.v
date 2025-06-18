`default_nettype none

module tt_um_equipo7 (
    input        clk,
    input        rst,
    input  [4:0] cfg,        // {stop_sel, parity_en, parity_even, data_len[1:0]}
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
  reg       tpar, rxv, rerr;

  // Transmisor (TX)
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      ts <= T_IDLE; tshift <= 0; tcnt <= 0; tbit <= 0; tpar <= 0;
    end else begin
      case (ts)
        T_IDLE: begin
          if (tx_req) begin
            tshift <= tx_data;
            tpar <= cfg[3] ? (cfg[2] ? ^tx_data : ~^tx_data) : 1'b0;
            ts <= cfg[3] ? T_P : T_S;
            tcnt <= 0; tbit <= 0;
          end
        end

        T_S: if (clk16) begin
               if (tcnt == 15) begin tcnt <= 0; ts <= T_D; end
               else tcnt <= tcnt + 1;
             end

        T_D: if (clk16) begin
               if (tcnt == 15) begin
                 tcnt <= 0;
                 tshift <= tshift >> 1;
                 tbit <= tbit + 1;
                 if (tbit == (cfg[1:0] + 3))
                   ts <= T_T;
               end else tcnt <= tcnt + 1;
             end

        T_P: if (clk16) begin
               if (tcnt == 15) begin tcnt <= 0; ts <= T_T; end
               else tcnt <= tcnt + 1;
             end

        T_T: if (clk16) begin
               if (tcnt == (cfg[4] ? (cfg[1:0] + 4) : (cfg[1:0] + 2)))
                 ts <= T_IDLE;
               else tcnt <= tcnt + 1;
             end

      endcase
    end
  end

  assign tx_sn   = (ts == T_S) ? 1'b0 : tshift[0];
  assign tx_busy = (ts != T_IDLE);

  // Receptor (RX)
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      tr       <= R_IDLE;
      rshift   <= 0;
      pcnt     <= 0;
      rerr     <= 0;
      rxv      <= 0;
      tcnt     <= 0;
    end else begin
      rxv <= 0;
      case (tr)
        R_IDLE: if (!rx_sn) begin tr <= R_CHK; tcnt <= 7; end

        R_CHK: if (clk16) begin
                 if (tcnt == 0) begin tcnt <= 0; tr <= R_REC; end
                 else tcnt <= tcnt - 1;
               end

        R_REC: if (clk16) begin
                 if (tcnt == 15) begin
                   tcnt <= 0;
                   rshift <= {rx_sn, rshift[7:1]};
                   pcnt <= pcnt + 1;
                   if (pcnt == (cfg[1:0] + 4))
                     tr <= cfg[3] ? R_PAR : R_TST;
                 end else tcnt <= tcnt + 1;
               end

        R_PAR: if (clk16) begin
                 if (tcnt == 15) begin
                   tcnt <= 0;
                   if ((cfg[2] ? ^rshift : ~^rshift) != rx_sn)
                     rerr <= 1;
                   tr <= R_TST;
                 end else tcnt <= tcnt + 1;
               end

        R_TST: if (clk16) begin
                 if (tcnt == 15) begin
                   rdata_reg <= rshift;
                   rxv <= 1;
                   tr <= R_IDLE;
                 end else tcnt <= tcnt + 1;
               end

      endcase
    end
  end

  assign rx_data  = rdata_reg;
  assign rx_valid = rxv;
  assign rx_err   = rerr;

endmodule
