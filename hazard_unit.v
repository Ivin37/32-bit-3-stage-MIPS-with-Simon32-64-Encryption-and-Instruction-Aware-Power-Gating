module hazard_unit(
    input        EX_MemRead,
    input  [4:0] EX_write_reg,
    input  [4:0] IF_rs,
    input  [4:0] IF_rt,
    output       load_use_hazard
);

// Load-use hazard: lw in EX stage, next instruction needs result
assign load_use_hazard = EX_MemRead &&
                         ((EX_write_reg == IF_rs) ||
                          (EX_write_reg == IF_rt));

endmodule