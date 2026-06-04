module data_memory(
    input  clk,
    input  MemRead, MemWrite,
    input  [31:0] addr,
    input  [31:0] write_data,
    output reg [31:0] read_data
);

reg [31:0] memory [0:255];

always @(posedge clk) begin
    if (MemWrite)
        memory[addr[9:2]] <= write_data;
end

always @(*) begin
    if (MemRead) read_data = memory[addr[9:2]];
    else         read_data = 32'd0;
end

endmodule