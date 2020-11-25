
analyze -sv09 rast_aqed.sv
elaborate -disable_auto_bbox -top aqed
clock clk
reset -expression rst
prove -bg -property {<embedded>::aqed.assert_qed_match}
