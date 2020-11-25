#!/bin/bash

# preserve order
cat aqed.sv ../params/rast_params.sv ../rtl/*.sv ./DW_pl_reg.v > rast_aqed.sv

# Modifications for VERIFIC
# Add //synopsys full_case directives at the end of unique case
sed -i '/unique case/ s/$/ \/\/ synopsys full_case/' rast_aqed.sv

# Convert enum to wire to resolve type error
echo "If enum to wire error, cast the state_t variable into a logic signal"

jg -tcl jasper_Aqed.tcl &
