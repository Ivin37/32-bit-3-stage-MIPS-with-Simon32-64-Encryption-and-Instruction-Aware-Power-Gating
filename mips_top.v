module mips_top(
    input  clk,
    input  reset,
    output [31:0] result_out
);

parameter [63:0] SIMON_KEY = 64'h1918111009080100;

// ════════════════════════════════
//  STAGE 1 (IF) wires
// ════════════════════════════════
wire [31:0] IF_pc;
wire [31:0] IF_pc_plus4;
wire [31:0] IF_instruction;

// ════════════════════════════════
//  IF/EX pipeline registers
// ════════════════════════════════
reg  [31:0] EX_pc_plus4;
reg  [31:0] EX_instruction;
reg         EX_RegDst, EX_ALUSrc, EX_MemtoReg;
reg         EX_RegWrite, EX_MemRead, EX_MemWrite;
reg         EX_Branch, EX_Jump;
reg  [1:0]  EX_ALUOp;

// ════════════════════════════════
//  STAGE 2 (EX) wires
// ════════════════════════════════
wire [4:0]  EX_rs           = EX_instruction[25:21];
wire [4:0]  EX_rt           = EX_instruction[20:16];
wire [4:0]  EX_rd_field     = EX_instruction[15:11];
wire [5:0]  EX_funct        = EX_instruction[5:0];
wire [31:0] EX_sign_ext_imm = {{16{EX_instruction[15]}},
                                EX_instruction[15:0]};
wire [4:0]  EX_write_reg;
wire [3:0]  EX_ALUControl;
wire [31:0] EX_read_data1_raw, EX_read_data2_raw;
wire [31:0] EX_fwd_data1, EX_fwd_data2;
wire [31:0] EX_alu_src2;
wire [31:0] EX_alu_result;
wire        EX_zero;
wire [31:0] EX_enc_input_iso;
wire [31:0] EX_encrypted_data;
wire [1:0]  fwd_A, fwd_B;
wire        load_use_hazard;

// ════════════════════════════════
//  EX/MEM pipeline registers
// ════════════════════════════════
reg  [31:0] MEM_pc_plus4;
reg  [31:0] MEM_instruction_word;
reg         MEM_MemtoReg, MEM_RegWrite;
reg         MEM_MemRead,  MEM_MemWrite;
reg         MEM_Branch,   MEM_Jump;
reg  [31:0] MEM_alu_result;
reg  [31:0] MEM_encrypted_data;
reg  [4:0]  MEM_write_reg;
reg         MEM_zero;
reg  [31:0] MEM_sign_ext_imm;

// ════════════════════════════════
//  STAGE 3 (MEM/WB) wires
// ════════════════════════════════
wire [31:0] MEM_mem_read_data;
wire [31:0] MEM_dec_input_iso;
wire [31:0] MEM_decrypted_data;
wire [31:0] MEM_write_back_data;
wire [31:0] MEM_branch_address;
wire [31:0] MEM_jump_address;
wire        MEM_pc_src;
wire [31:0] MEM_pc_after_branch;
wire [31:0] IF_pc_next;

// ════════════════════════════════
//  Hazard and flush signals
// ════════════════════════════════
wire flush = MEM_pc_src | MEM_Jump;
wire stall = load_use_hazard;

// ════════════════════════════════
//  Power gating enables
// ════════════════════════════════
wire DMEM_en      = MEM_MemRead | MEM_MemWrite;
wire SIMON_ENC_en = EX_MemWrite;
wire SIMON_DEC_en = MEM_MemRead;

wire clk_dmem;
clock_gate cg_dmem(
    .clk(clk),
    .en(DMEM_en),
    .gated_clk(clk_dmem)
);

// ════════════════════════════════
//  STAGE 1 — IF
// ════════════════════════════════
pc pc_inst(
    .clk(clk),
    .reset(reset),
    .stall(stall),
    .pc_next(IF_pc_next),
    .pc(IF_pc)
);

assign IF_pc_plus4 = IF_pc + 4;

instruction_memory imem(
    .addr(IF_pc),
    .instruction(IF_instruction)
);

// PC next — branch/jump resolved at end of MEM stage
assign MEM_branch_address  = MEM_pc_plus4 + (MEM_sign_ext_imm << 2);
assign MEM_jump_address    = {MEM_pc_plus4[31:28],
                              MEM_instruction_word[25:0], 2'b00};
assign MEM_pc_src          = MEM_Branch & MEM_zero;
assign MEM_pc_after_branch = (MEM_pc_src) ? MEM_branch_address
                                           : IF_pc_plus4;
assign IF_pc_next          = (MEM_Jump)   ? MEM_jump_address
                                           : MEM_pc_after_branch;

// ════════════════════════════════
//  Control unit (decodes IF stage)
// ════════════════════════════════
wire ctrl_RegDst, ctrl_ALUSrc, ctrl_MemtoReg;
wire ctrl_RegWrite, ctrl_MemRead, ctrl_MemWrite;
wire ctrl_Branch, ctrl_Jump;
wire [1:0] ctrl_ALUOp;

control ctrl(
    .opcode(IF_instruction[31:26]),
    .RegDst(ctrl_RegDst),
    .ALUSrc(ctrl_ALUSrc),
    .MemtoReg(ctrl_MemtoReg),
    .RegWrite(ctrl_RegWrite),
    .MemRead(ctrl_MemRead),
    .MemWrite(ctrl_MemWrite),
    .Branch(ctrl_Branch),
    .Jump(ctrl_Jump),
    .ALUOp(ctrl_ALUOp)
);

// ════════════════════════════════
//  Hazard detection unit
// ════════════════════════════════
hazard_unit haz(
    .EX_MemRead(EX_MemRead),
    .EX_write_reg(EX_write_reg),
    .IF_rs(IF_instruction[25:21]),
    .IF_rt(IF_instruction[20:16]),
    .load_use_hazard(load_use_hazard)
);

// ════════════════════════════════
//  IF/EX pipeline register
// ════════════════════════════════
always @(posedge clk or posedge reset) begin
    if (reset || flush || stall) begin
        // Insert NOP / bubble
        EX_pc_plus4    <= 0;
        EX_instruction <= 32'h00000000;
        EX_RegDst      <= 0; EX_ALUSrc   <= 0;
        EX_MemtoReg    <= 0; EX_RegWrite <= 0;
        EX_MemRead     <= 0; EX_MemWrite <= 0;
        EX_Branch      <= 0; EX_Jump     <= 0;
        EX_ALUOp       <= 0;
    end else begin
        EX_pc_plus4    <= IF_pc_plus4;
        EX_instruction <= IF_instruction;
        EX_RegDst      <= ctrl_RegDst;
        EX_ALUSrc      <= ctrl_ALUSrc;
        EX_MemtoReg    <= ctrl_MemtoReg;
        EX_RegWrite    <= ctrl_RegWrite;
        EX_MemRead     <= ctrl_MemRead;
        EX_MemWrite    <= ctrl_MemWrite;
        EX_Branch      <= ctrl_Branch;
        EX_Jump        <= ctrl_Jump;
        EX_ALUOp       <= ctrl_ALUOp;
    end
end

// ════════════════════════════════
//  STAGE 2 — EX
// ════════════════════════════════
assign EX_write_reg = (EX_RegDst) ? EX_rd_field : EX_rt;

// Register file with internal forwarding for same-cycle read/write
register_file rf(
    .clk(clk),
    .RegWrite(MEM_RegWrite),
    .rs(EX_rs),
    .rt(EX_rt),
    .rd(MEM_write_reg),
    .write_data(MEM_write_back_data),
    .read_data1(EX_read_data1_raw),
    .read_data2(EX_read_data2_raw)
);

// Forwarding unit
forwarding_unit fwd_unit(
    .EX_rs(EX_rs),
    .EX_rt(EX_rt),
    .MEM_write_reg(MEM_write_reg),
    .MEM_RegWrite(MEM_RegWrite),
    .MEM_MemtoReg(MEM_MemtoReg),
    .fwd_A(fwd_A),
    .fwd_B(fwd_B)
);

// Forwarding muxes
// 2'b00 = register file, 2'b01 = MEM ALU result, 2'b10 = MEM writeback
assign EX_fwd_data1 = (fwd_A == 2'b10) ? MEM_write_back_data :
                      (fwd_A == 2'b01) ? MEM_alu_result      :
                                         EX_read_data1_raw;

assign EX_fwd_data2 = (fwd_B == 2'b10) ? MEM_write_back_data :
                      (fwd_B == 2'b01) ? MEM_alu_result      :
                                         EX_read_data2_raw;

assign EX_alu_src2 = (EX_ALUSrc) ? EX_sign_ext_imm : EX_fwd_data2;

alu_control alu_ctrl(
    .ALUOp(EX_ALUOp),
    .funct(EX_funct),
    .ALUControl(EX_ALUControl)
);

alu alu_unit(
    .a(EX_fwd_data1),
    .b(EX_alu_src2),
    .alu_control(EX_ALUControl),
    .result(EX_alu_result),
    .zero(EX_zero)
);

// Simon encrypt — operand isolation
assign EX_enc_input_iso = (SIMON_ENC_en) ? EX_fwd_data2 : 32'd0;

simon_encrypt enc(
    .plaintext(EX_enc_input_iso),
    .key(SIMON_KEY),
    .ciphertext(EX_encrypted_data)
);

// ════════════════════════════════
//  EX/MEM pipeline register
// ════════════════════════════════
// EX/MEM pipeline register — add flush condition
always @(posedge clk or posedge reset) begin
    if (reset || flush) begin      // <-- add flush here
        MEM_pc_plus4         <= 0;
        MEM_instruction_word <= 0;
        MEM_MemtoReg         <= 0; MEM_RegWrite <= 0;
        MEM_MemRead          <= 0; MEM_MemWrite <= 0;
        MEM_Branch           <= 0; MEM_Jump     <= 0;
        MEM_alu_result       <= 0;
        MEM_encrypted_data   <= 0;
        MEM_write_reg        <= 0;
        MEM_zero             <= 0;
        MEM_sign_ext_imm     <= 0;
    end else begin
        MEM_pc_plus4         <= EX_pc_plus4;
        MEM_instruction_word <= EX_instruction;
        MEM_MemtoReg         <= EX_MemtoReg;
        MEM_RegWrite         <= EX_RegWrite;
        MEM_MemRead          <= EX_MemRead;
        MEM_MemWrite         <= EX_MemWrite;
        MEM_Branch           <= EX_Branch;
        MEM_Jump             <= EX_Jump;
        MEM_alu_result       <= EX_alu_result;
        MEM_encrypted_data   <= EX_encrypted_data;
        MEM_write_reg        <= EX_write_reg;
        MEM_zero             <= EX_zero;
        MEM_sign_ext_imm     <= EX_sign_ext_imm;
    end
end
// ════════════════════════════════
//  STAGE 3 — MEM/WB
// ════════════════════════════════
assign MEM_dec_input_iso = (SIMON_DEC_en) ? MEM_mem_read_data : 32'd0;

data_memory dmem(
    .clk(clk_dmem),
    .MemRead(MEM_MemRead),
    .MemWrite(MEM_MemWrite),
    .addr(MEM_alu_result),
    .write_data(MEM_encrypted_data),
    .read_data(MEM_mem_read_data)
);

simon_decrypt dec(
    .ciphertext(MEM_dec_input_iso),
    .key(SIMON_KEY),
    .plaintext(MEM_decrypted_data)
);

assign MEM_write_back_data = (MEM_MemtoReg) ? MEM_decrypted_data
                                             : MEM_alu_result;

assign result_out = MEM_write_back_data;

endmodule