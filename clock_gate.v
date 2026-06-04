module clock_gate(
    input  clk,
    input  en,
    output gated_clk
);

reg en_latched;

always @(*) begin
    if (!clk) en_latched = en;
end

assign gated_clk = clk & en_latched;

endmodule