module forwarding_unit(
    input  [4:0] EX_rs,
    input  [4:0] EX_rt,
    input  [4:0] MEM_write_reg,
    input        MEM_RegWrite,
    input        MEM_MemtoReg,
    output reg [1:0] fwd_A,
    output reg [1:0] fwd_B
);

// 2'b00 = register file (no hazard)
// 2'b01 = forward MEM ALU result
// 2'b10 = forward MEM writeback (covers lw result)

always @(*) begin
    // Forward A (rs)
    if (MEM_RegWrite && (MEM_write_reg != 0) &&
        (MEM_write_reg == EX_rs)) begin
        if (MEM_MemtoReg)
            fwd_A = 2'b10; // lw result
        else
            fwd_A = 2'b01; // ALU result
    end else
        fwd_A = 2'b00;

    // Forward B (rt)
    if (MEM_RegWrite && (MEM_write_reg != 0) &&
        (MEM_write_reg == EX_rt)) begin
        if (MEM_MemtoReg)
            fwd_B = 2'b10; // lw result
        else
            fwd_B = 2'b01; // ALU result
    end else
        fwd_B = 2'b00;
end

endmodule