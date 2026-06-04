`timescale 1ns/1ps

module tb_mips_top;

reg clk, reset;

mips_top dut(
    .clk(clk),
    .reset(reset),
    .result_out()
);

initial clk = 0;
always #5 clk = ~clk;

initial begin
  

    reset = 1;
    repeat(3) @(posedge clk);
    @(negedge clk);
    reset = 0;

    #250;

    $finish;
end

endmodule