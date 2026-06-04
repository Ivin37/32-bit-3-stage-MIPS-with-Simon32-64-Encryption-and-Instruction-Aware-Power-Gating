module alu_control(
    input  [1:0] ALUOp,
    input  [5:0] funct,
    output reg [3:0] ALUControl
);

always @(*) begin
    case (ALUOp)
        2'b00: ALUControl = 4'b0010;
        2'b01: ALUControl = 4'b0110;
        2'b10: begin
            case (funct)
                6'b100000: ALUControl = 4'b0010;
                6'b100010: ALUControl = 4'b0110;
                6'b100100: ALUControl = 4'b0000;
                6'b100101: ALUControl = 4'b0001;
                6'b101010: ALUControl = 4'b0111;
                default:   ALUControl = 4'b0010;
            endcase
        end
        default: ALUControl = 4'b0010;
    endcase
end

endmodule