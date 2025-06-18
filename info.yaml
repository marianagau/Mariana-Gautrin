# Tiny Tapeout project information
project: 
  title:        "Evidencia 2 Código Verilog"
  author:       "Mariana Gautrin, Arah Rojas, Olín"
  discord:      "NA"
  description:  "Simulación 3D"
  language:     "Verilog"
  clock_hz:     0

  tiles: "1x1"
  top_module:  "tt_um_equipo7"

  source_files:
    - "project.v"
  user_config: "user_config.tcl"   # 👈 Esta línea fue añadida para evitar errores de capas

pinout:
  # Inputs
  ui[0]: "rst_n"       # Reset activo en bajo
  ui[1]: "tx_req"      # TX Start request
  ui[2]: "clk16"       # 16x baud rate clock
  ui[3]: "cfg0"        # Config bit 0 (data_len[0])
  ui[4]: "cfg1"        # Config bit 1 (data_len[1])
  ui[5]: "cfg2"        # Config bit 2 (parity_even)
  ui[6]: "cfg3"        # Config bit 3 (parity_en)
  ui[7]: "rx_sn"       # RX serial input

  # Outputs
  uo[0]: "tx_sn"       # TX serial output
  uo[1]: "tx_busy"     # TX busy flag
  uo[2]: "have_data"   # Flag: se recibió dato
  uo[3]: "rx_err"      # RX error flag
  uo[4]: ""            # Unused
  uo[5]: ""            # Unused
  uo[6]: ""            # Unused
  uo[7]: ""            # Unused

  # Bidirectional pins (TX data input / RX data output)
  uio[0]: "data0"
  uio[1]: "data1"
  uio[2]: "data2"
  uio[3]: "data3"
  uio[4]: "data4"
  uio[5]: "data5"
  uio[6]: "data6"
  uio[7]: "data7"

yaml_version: 6
