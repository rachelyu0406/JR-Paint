-makelib ies_lib/xpm -sv \
  "C:/Xilinx/Vivado/2021.1/data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv" \
-endlib
-makelib ies_lib/xpm \
  "C:/Xilinx/Vivado/2021.1/data/ip/xpm/xpm_VCOMP.vhd" \
-endlib
-makelib ies_lib/xil_defaultlib \
  "../../../../ECE350_processor.gen/sources_1/ip/clk_wiz_5/clk_wiz_5_clk_wiz.v" \
  "../../../../ECE350_processor.gen/sources_1/ip/clk_wiz_5/clk_wiz_5.v" \
-endlib
-makelib ies_lib/xil_defaultlib \
  glbl.v
-endlib

