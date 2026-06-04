module simon_decrypt(
    input  [31:0] ciphertext,
    input  [63:0] key,
    output [31:0] plaintext
);

wire [511:0] rk_flat;
simon_keyschedule ks(.key(key), .rk_flat(rk_flat));

function [15:0] rk;
    input [511:0] flat;
    input integer i;
    begin rk = flat[i*16 +: 16]; end
endfunction

function [15:0] rol16;
    input [15:0] x;
    input integer n;
    begin rol16 = (x << n) | (x >> (16 - n)); end
endfunction

reg [15:0] L [0:32];
reg [15:0] R [0:32];
integer    i;

always @(*) begin
    L[32] = ciphertext[31:16];
    R[32] = ciphertext[15:0];
    for (i = 31; i >= 0; i = i - 1) begin
        R[i] = L[i+1];
        L[i] = R[i+1]
               ^ ((rol16(L[i+1], 1) & rol16(L[i+1], 8)) ^ rol16(L[i+1], 2))
               ^ rk(rk_flat, i);
    end
end

assign plaintext = {L[0], R[0]};

endmodule