module control(
    input  [5:0] opcode,
    output reg RegDst, ALUSrc, MemtoReg,
    output reg RegWrite, MemRead, MemWrite,
    output reg Branch, Jump,
    output reg [1:0] ALUOp
);

always @(*) begin
    RegDst=0; ALUSrc=0; MemtoReg=0;
    RegWrite=0; MemRead=0; MemWrite=0;
    Branch=0; Jump=0; ALUOp=2'b00;

    case (opcode)
        6'b000000: begin
            RegDst=1; RegWrite=1; ALUOp=2'b10;
        end
        6'b100011: begin
            ALUSrc=1; MemtoReg=1;
            RegWrite=1; MemRead=1;
        end
        6'b101011: begin
            ALUSrc=1; MemWrite=1;
        end
        6'b000100: begin
            Branch=1; ALUOp=2'b01;
        end
        6'b000010: begin
            Jump=1;
        end
        6'b001000: begin
            ALUSrc=1; RegWrite=1;
        end
    endcase
end

endmodule