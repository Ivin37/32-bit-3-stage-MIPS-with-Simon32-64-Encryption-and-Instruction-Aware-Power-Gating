module instruction_memory(
    input  [31:0] addr,
    output [31:0] instruction
);

reg [31:0] memory [0:255];

initial begin
memory[0]  = 32'h20080005; // addi $8,  $0,  5     | $8  = 5
memory[1]  = 32'h2009000A; // addi $9,  $0,  10    | $9  = 10
memory[2]  = 32'h01095020; // add  $10, $8,  $9    | $10 = $8 + $9 = 15
memory[3]  = 32'hAC0A0000; // sw   $10, 0($0)      | mem[0] = $10
memory[4]  = 32'h8C0B0000; // lw   $11, 0($0)      | $11 = mem[0]
memory[5]  = 32'h116A0001; // beq  $11, $10, +1    | if $11==$10 skip next
memory[6]  = 32'h200C0001; // addi $12, $0,  1     | $12 = 1 (error flag)

// ── TWO SUBTRACT INSTRUCTIONS ─────────────────────────
memory[7]  = 32'h01285822; // sub  $11, $9,  $8    | $11 = $9 - $8 = 5
memory[8]  = 32'h01094022; // sub  $8,  $8,  $9    | $8  = $8 - $9 = -5

// ── JUMP to memory[11] — skips two add instructions ───
memory[9]  = 32'h0800000C; // j    11              | jump → memory[11]

// ── TWO ADD INSTRUCTIONS (skipped by jump) ────────────
memory[10] = 32'h01285820; // add  $11, $9,  $8    | $11 = $9 + $8  (skipped)
memory[11] = 32'h01094020; // add  $8,  $8,  $9    | $8  = $8 + $9  (skipped)

// ── JUMP TARGET ───────────────────────────────────────
memory[12] = 32'h01094820; // add $9, $8, $9 | $9 = $8 + $9 // nop                  | execution continues here
end

assign instruction = memory[addr[9:2]];

endmodule