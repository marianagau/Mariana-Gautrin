module tt_um_equipo7 (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable (1:output, 0:input)
    input  wire       ena,      // Enable - high to run design
    input  wire       clk,      // Clock
    input  wire       rst_n     // Reset (active low)
);

    // Eliminar warning de señal no usada
    wire unused_ena = ena;
    
    wire tx_busy, tx_sn, rx_valid, rx_err;
    wire [7:0] rx_data;
    wire [4:0] cfg = {
        ui_in[7],       // CTRL4: stop_sel
        ~ui_in[6],      // CTRL3: parity_en (invertido)
        ui_in[5],       // CTRL2: parity_even
        ui_in[4:3]      // CTRL1-0: data_len[1:0]
    };
    
    reg have_data;
    reg [7:0] hold_rx_data;
    wire rst = ~rst_n;  // Convertir a reset activo-alto

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            have_data <= 0;
            hold_rx_data <= 0;
        end else begin
            if (rx_valid) begin
                have_data <= 1;
                hold_rx_data <= rx_data;
            end else if (ui_in[1]) begin  // TX_START
                have_data <= 0;
            end
        end
    end

    uart_core core_inst (
        .clk(clk),
        .rst(rst),
        .cfg(cfg),
        .tx_data(uio_in),
        .tx_req(ui_in[1]),   // TX_START
        .tx_busy(tx_busy),
        .tx_sn(tx_sn),
        .rx_sn(ui_in[0]),    // RX_IN
        .rx_data(rx_data),
        .rx_valid(rx_valid),
        .rx_err(rx_err),
        .clk16(ui_in[2])     // BAUD_EN
    );

    // Mapeo de salidas
    assign uo_out[0] = tx_sn;        // TX_OUT
    assign uo_out[1] = tx_busy;      // TX_BUSY
    assign uo_out[2] = have_data;    // RX_READY (modificado)
    assign uo_out[3] = rx_err;       // RX_ERROR
    assign uo_out[7:4] = 4'b0;       // Unused

    // Control bus bidireccional
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
  reg       tpar, rxv, rerr;

  // Transmisor (TX)
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      ts <= T_IDLE; 
      tshift <= 0; 
      tcnt <= 0; 
      tbit <= 0; 
      tpar <= 0;
    end else begin
      case (ts)
        T_IDLE: begin
          if (tx_req) begin
            tshift <= tx_data;
            // Calcular paridad solo si está habilitada
            tpar <= cfg[3] ? (cfg[2] ? ^tx_data : ~^tx_data) : 1'b0;
            ts <= cfg[3] ? T_P : T_S;
            tcnt <= 0; 
            tbit <= 0;
          end
        end

        T_S: if (clk16) begin
               if (tcnt == 15) begin 
                 tcnt <= 0; 
                 ts <= T_D; 
               end
               else tcnt <= tcnt + 1;
             end

        T_D: if (clk16) begin
               if (tcnt == 15) begin
                 tcnt <= 0;
                 tshift <= tshift >> 1;
                 tbit <= tbit + 1;
                 // Corregir ancho de bits en la comparación
                 if (tbit == (4'd3 + cfg[1:0]))
                   ts <= T_T;
               end else tcnt <= tcnt + 1;
             end

        T_P: if (clk16) begin
               if (tcnt == 15) begin 
                 tcnt <= 0; 
                 ts <= T_T; 
               end
               else tcnt <= tcnt + 1;
             end

        T_T: if (clk16) begin
               // Corregir ancho de bits en la comparación
               if (tcnt == (cfg[4] ? (4'd4 + cfg[1:0]) : (4'd2 + cfg[1:0])))
                 ts <= T_IDLE;
               else tcnt <= tcnt + 1;
             end

      endcase
    end
  end

  // Asignación de salida TX con soporte para bit de paridad
  assign tx_sn = (ts == T_S) ? 1'b0 : 
                 (ts == T_P) ? tpar : 
                 (ts == T_D) ? tshift[0] : 
                 1'b1;

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
        R_IDLE: if (!rx_sn) begin 
                  tr <= R_CHK; 
                  tcnt <= 7; 
                  pcnt <= 0;  // Inicializar contador
                end

        R_CHK: if (clk16) begin
                 if (tcnt == 0) begin 
                   tcnt <= 0; 
                   tr <= R_REC; 
                 end
                 else tcnt <= tcnt - 1;
               end

        R_REC: if (clk16) begin
                 if (tcnt == 15) begin
                   tcnt <= 0;
                   rshift <= {rx_sn, rshift[7:1]};
                   pcnt <= pcnt + 1;
                   // Corregir ancho de bits en la comparación
                   if (pcnt == (4'd4 + cfg[1:0]))
                     tr <= cfg[3] ? R_PAR : R_TST;
                 end else tcnt <= tcnt + 1;
               end

        R_PAR: if (clk16) begin
                 if (tcnt == 15) begin
                   tcnt <= 0;
                   // Verificar paridad
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
