module simon_keyschedule(
    input  [63:0]  key,
    output [511:0] rk_flat
);

localparam [61:0] Z0 = 62'h19CFC52247293D3F;

reg [15:0] k [0:31];
integer    ii;

function [15:0] ror16;
    input [15:0] x;
    input integer n;
    begin ror16 = (x >> n) | (x << (16 - n)); end
endfunction

always @(*) begin
    k[0] = key[15:0];
    k[1] = key[31:16];
    k[2] = key[47:32];
    k[3] = key[63:48];

    for (ii = 4; ii < 32; ii = ii + 1) begin
        k[ii] = ~k[ii-4]
                ^ ror16(k[ii-1], 3)
                ^ ror16(k[ii-1], 4)
                ^ {15'd0, Z0[(ii-4) % 62]}
                ^ 16'd3;
    end
end

genvar gi;
generate
    for (gi = 0; gi < 32; gi = gi + 1)
    begin
        assign rk_flat[gi*16 +: 16] = k[gi];
        end
endgenerate

endmodule