// Internal forwarding added for same-cycle read/write
module register_file(
    input  clk,
    input  RegWrite,
    input  [4:0]  rs, rt, rd,
    input  [31:0] write_data,
    output [31:0] read_data1, read_data2
);

reg [31:0] registers [0:31];
integer i;

initial begin
    for (i = 0; i < 32; i = i+1)
        registers[i] = 0;
end

// Internal forwarding — if reading and writing same register
// in same cycle, return the new write value immediately
assign read_data1 = (RegWrite && rd == rs && rd != 0) ?
                     write_data : registers[rs];
assign read_data2 = (RegWrite && rd == rt && rd != 0) ?
                     write_data : registers[rt];

always @(posedge clk) begin
    if (RegWrite && rd != 0)
        registers[rd] <= write_data;
    registers[0] <= 0;
end

endmodule