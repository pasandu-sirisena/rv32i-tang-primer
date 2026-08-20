// Pipelined RV32IM processor core
module rv32im_core (
    // Clock and active-low reset
    input  wire        clk,
    input  wire        rst_n,

    // Instruction memory bus interface
    output wire [12:0] instr_addr,
    output wire        instr_ce,
    input  wire [31:0] instr_rdata,

    // Wishbone data memory master interface
    output wire        wb_cyc_o,
    output wire        wb_stb_o,
    output wire        wb_we_o,
    output wire [31:0] wb_adr_o,
    output wire [31:0] wb_dat_o,
    output wire [3:0]  wb_sel_o,
    input  wire [31:0] wb_dat_i,
    input  wire        wb_ack_i
);

    // ALU operation encoding parameters
    localparam ALU_ADD   = 4'd0,  ALU_SUB  = 4'd1,  ALU_SLL  = 4'd2,
               ALU_SLT  = 4'd3,  ALU_SLTU = 4'd4,  ALU_XOR  = 4'd5,
               ALU_SRL  = 4'd6,  ALU_SRA  = 4'd7,  ALU_OR   = 4'd8,
               ALU_AND  = 4'd9,  ALU_PASSB= 4'd10;

    // Writeback multiplexer source parameters
    localparam WB_ALU = 2'd0, WB_MEM = 2'd1, WB_PC4 = 2'd2;

    // Hazard detection and forwarding control wires
    wire       stall_if, stall_id, stall_ex, stall_mem;
    wire       flush_if_id, flush_id_ex;
    wire       take_branch;
    wire [1:0] fwd_a, fwd_b;

    // Instruction fetch stage registers and program counter
    reg  [31:0] pc;
    reg         if_id_valid;
    reg  [31:0] if_id_pc;

    wire [31:0] pc_plus4 = pc + 32'd4;
    wire [31:0] pc_next;

    assign instr_addr = pc[14:2];
    assign instr_ce   = !stall_if;

    // Program counter update process
    always @(posedge clk) begin
        if (!rst_n) begin
            pc          <= 32'd0;
            if_id_valid <= 1'b0;
            if_id_pc    <= 32'd0;
        end else begin
            if (take_branch && !stall_ex) begin
                pc          <= pc_next;
                if_id_valid <= 1'b0;
                if_id_pc    <= 32'd0;
            end else if (!stall_if) begin
                pc          <= pc_plus4;
                if_id_valid <= 1'b1;
                if_id_pc    <= pc;
            end
        end
    end

    // Instruction word for decode stage
    wire [31:0] if_id_instr = if_id_valid ? instr_rdata : 32'h0000_0013;

    // Instruction fields decoding
    wire [6:0] opcode  = if_id_instr[6:0];
    wire [4:0] rd_id   = if_id_instr[11:7];
    wire [2:0] funct3  = if_id_instr[14:12];
    wire [4:0] rs1_id  = if_id_instr[19:15];
    wire [4:0] rs2_id  = if_id_instr[24:20];
    wire [6:0] funct7  = if_id_instr[31:25];

    // Immediate generation for all instruction formats
    wire [31:0] imm_i = {{20{if_id_instr[31]}}, if_id_instr[31:20]};
    wire [31:0] imm_s = {{20{if_id_instr[31]}}, if_id_instr[31:25], if_id_instr[11:7]};
    wire [31:0] imm_b = {{19{if_id_instr[31]}}, if_id_instr[31], if_id_instr[7],
                          if_id_instr[30:25], if_id_instr[11:8], 1'b0};
    wire [31:0] imm_u = {if_id_instr[31:12], 12'd0};
    wire [31:0] imm_j = {{11{if_id_instr[31]}}, if_id_instr[31], if_id_instr[19:12],
                          if_id_instr[20], if_id_instr[30:21], 1'b0};

    // Immediate selection multiplexer
    reg [31:0] imm_id;
    always @(*) begin
        case (opcode)
            7'b0010011: imm_id = imm_i;
            7'b0000011: imm_id = imm_i;
            7'b1100111: imm_id = imm_i;
            7'b0100011: imm_id = imm_s;
            7'b1100011: imm_id = imm_b;
            7'b0110111: imm_id = imm_u;
            7'b0010111: imm_id = imm_u;
            7'b1101111: imm_id = imm_j;
            default:    imm_id = 32'd0;
        endcase
    end

    // Control signals for pipeline execution
    reg        ctrl_reg_write;
    reg        ctrl_mem_read;
    reg        ctrl_mem_write;
    reg        ctrl_alu_src_b;
    reg        ctrl_alu_src_a;
    reg [3:0]  ctrl_alu_op;
    reg [1:0]  ctrl_wb_sel;
    reg        ctrl_is_branch;
    reg        ctrl_is_jal;
    reg        ctrl_is_jalr;
    reg        ctrl_is_mul;
    reg        ctrl_is_div;

    wire is_mext = (opcode == 7'b0110011) && (funct7 == 7'b0000001);

    // Main instruction control decoder
    always @(*) begin
        ctrl_reg_write = 1'b0;  ctrl_mem_read  = 1'b0;
        ctrl_mem_write = 1'b0;  ctrl_alu_src_b = 1'b0;
        ctrl_alu_src_a = 1'b0;  ctrl_alu_op    = ALU_ADD;
        ctrl_wb_sel    = WB_ALU;
        ctrl_is_branch = 1'b0;  ctrl_is_jal    = 1'b0;
        ctrl_is_jalr   = 1'b0;  ctrl_is_mul    = 1'b0;
        ctrl_is_div    = 1'b0;

        case (opcode)
            // Register-register arithmetic and M-extension
            7'b0110011: begin
                ctrl_reg_write = 1'b1;
                if (is_mext) begin
                    if (funct3[2] == 1'b0) ctrl_is_mul = 1'b1;
                    else                   ctrl_is_div = 1'b1;
                end else begin
                    case (funct3)
                        3'b000: ctrl_alu_op = (funct7[5]) ? ALU_SUB : ALU_ADD;
                        3'b001: ctrl_alu_op = ALU_SLL;
                        3'b010: ctrl_alu_op = ALU_SLT;
                        3'b011: ctrl_alu_op = ALU_SLTU;
                        3'b100: ctrl_alu_op = ALU_XOR;
                        3'b101: ctrl_alu_op = (funct7[5]) ? ALU_SRA : ALU_SRL;
                        3'b110: ctrl_alu_op = ALU_OR;
                        3'b111: ctrl_alu_op = ALU_AND;
                    endcase
                end
            end

            // Immediate arithmetic instructions
            7'b0010011: begin
                ctrl_reg_write = 1'b1;
                ctrl_alu_src_b = 1'b1;
                case (funct3)
                    3'b000: ctrl_alu_op = ALU_ADD;
                    3'b001: ctrl_alu_op = ALU_SLL;
                    3'b010: ctrl_alu_op = ALU_SLT;
                    3'b011: ctrl_alu_op = ALU_SLTU;
                    3'b100: ctrl_alu_op = ALU_XOR;
                    3'b101: ctrl_alu_op = (funct7[5]) ? ALU_SRA : ALU_SRL;
                    3'b110: ctrl_alu_op = ALU_OR;
                    3'b111: ctrl_alu_op = ALU_AND;
                endcase
            end

            // Memory load instructions
            7'b0000011: begin
                ctrl_reg_write = 1'b1;
                ctrl_alu_src_b = 1'b1;
                ctrl_alu_op    = ALU_ADD;
                ctrl_mem_read  = 1'b1;
                ctrl_wb_sel    = WB_MEM;
            end

            // Memory store instructions
            7'b0100011: begin
                ctrl_alu_src_b = 1'b1;
                ctrl_alu_op    = ALU_ADD;
                ctrl_mem_write = 1'b1;
            end

            // Conditional branch instructions
            7'b1100011: begin
                ctrl_is_branch = 1'b1;
                ctrl_alu_op    = ALU_SUB;
            end

            // Load upper immediate instruction
            7'b0110111: begin
                ctrl_reg_write = 1'b1;
                ctrl_alu_src_b = 1'b1;
                ctrl_alu_op    = ALU_PASSB;
            end

            // Add upper immediate to PC instruction
            7'b0010111: begin
                ctrl_reg_write = 1'b1;
                ctrl_alu_src_a = 1'b1;
                ctrl_alu_src_b = 1'b1;
                ctrl_alu_op    = ALU_ADD;
            end

            // Jump and link instruction
            7'b1101111: begin
                ctrl_reg_write = 1'b1;
                ctrl_is_jal    = 1'b1;
                ctrl_wb_sel    = WB_PC4;
            end

            // Jump and link register instruction
            7'b1100111: begin
                ctrl_reg_write = 1'b1;
                ctrl_alu_src_b = 1'b1;
                ctrl_is_jalr   = 1'b1;
                ctrl_alu_op    = ALU_ADD;
                ctrl_wb_sel    = WB_PC4;
            end

            default: begin end
        endcase
    end

    // General purpose register file
    wire [31:0] rf_rs1, rf_rs2;
    wire        wb_rf_wr_en;
    wire [4:0]  wb_rf_wr_addr;
    wire [31:0] wb_rf_wr_data;

    regfile u_regfile (
        .clk      (clk),
        .rs1_addr (rs1_id),
        .rs2_addr (rs2_id),
        .wr_addr  (wb_rf_wr_addr),
        .wr_data  (wb_rf_wr_data),
        .wr_en    (wb_rf_wr_en),
        .rs1_data (rf_rs1),
        .rs2_data (rf_rs2)
    );

    // Pipeline registers between ID and EX stages
    reg [31:0] id_ex_pc, id_ex_pc4;
    reg [31:0] id_ex_rs1, id_ex_rs2;
    reg [31:0] id_ex_imm;
    reg [4:0]  id_ex_rd,  id_ex_rs1_addr, id_ex_rs2_addr;
    reg [2:0]  id_ex_funct3;
    reg        id_ex_reg_write, id_ex_mem_read, id_ex_mem_write;
    reg        id_ex_alu_src_b, id_ex_alu_src_a;
    reg [3:0]  id_ex_alu_op;
    reg [1:0]  id_ex_wb_sel;
    reg        id_ex_is_branch, id_ex_is_jal, id_ex_is_jalr;
    reg        id_ex_is_mul, id_ex_is_div;
    reg        id_ex_valid;

    always @(posedge clk) begin
        if (!rst_n || (flush_id_ex && !stall_ex)) begin
            id_ex_reg_write <= 0;  id_ex_mem_read  <= 0;
            id_ex_mem_write <= 0;  id_ex_is_branch <= 0;
            id_ex_is_jal    <= 0;  id_ex_is_jalr   <= 0;
            id_ex_is_mul    <= 0;  id_ex_is_div    <= 0;
            id_ex_valid     <= 0;  id_ex_rd        <= 5'd0;
            id_ex_alu_op    <= ALU_ADD;
            id_ex_wb_sel    <= WB_ALU;
            id_ex_alu_src_a <= 0;  id_ex_alu_src_b <= 0;
            id_ex_pc        <= 32'd0; id_ex_pc4      <= 32'd0;
            id_ex_rs1       <= 32'd0; id_ex_rs2      <= 32'd0;
            id_ex_imm       <= 32'd0;
            id_ex_rs1_addr  <= 5'd0;  id_ex_rs2_addr <= 5'd0;
            id_ex_funct3    <= 3'd0;
        end else if (!stall_id) begin
            id_ex_pc        <= if_id_pc;
            id_ex_pc4       <= if_id_pc + 32'd4;
            id_ex_rs1       <= rf_rs1;
            id_ex_rs2       <= rf_rs2;
            id_ex_imm       <= imm_id;
            id_ex_rd        <= rd_id;
            id_ex_rs1_addr  <= rs1_id;
            id_ex_rs2_addr  <= rs2_id;
            id_ex_funct3    <= funct3;
            id_ex_reg_write <= ctrl_reg_write;
            id_ex_mem_read  <= ctrl_mem_read;
            id_ex_mem_write <= ctrl_mem_write;
            id_ex_alu_src_b <= ctrl_alu_src_b;
            id_ex_alu_src_a <= ctrl_alu_src_a;
            id_ex_alu_op    <= ctrl_alu_op;
            id_ex_wb_sel    <= ctrl_wb_sel;
            id_ex_is_branch <= ctrl_is_branch;
            id_ex_is_jal    <= ctrl_is_jal;
            id_ex_is_jalr   <= ctrl_is_jalr;
            id_ex_is_mul    <= ctrl_is_mul;
            id_ex_is_div    <= ctrl_is_div;
            id_ex_valid     <= if_id_valid;
        end
    end

    // Operand forwarding multiplexers
    wire [31:0] ex_mem_result;
    wire [31:0] fwd_rs1_data = (fwd_a == 2'b10) ? ex_mem_result  :
                               (fwd_a == 2'b01) ? wb_rf_wr_data  :
                                                   id_ex_rs1;
    wire [31:0] fwd_rs2_data = (fwd_b == 2'b10) ? ex_mem_result  :
                               (fwd_b == 2'b01) ? wb_rf_wr_data  :
                                                   id_ex_rs2;

    // ALU input multiplexers
    wire [31:0] alu_a = id_ex_alu_src_a ? id_ex_pc  : fwd_rs1_data;
    wire [31:0] alu_b = id_ex_alu_src_b ? id_ex_imm : fwd_rs2_data;

    // ALU execution unit
    wire [31:0] alu_result;
    alu u_alu (
        .alu_op (id_ex_alu_op),
        .a      (alu_a),
        .b      (alu_b),
        .result (alu_result)
    );

    // Hardware multiplier unit
    wire [31:0] mul_result;
    multiply u_mul (
        .a      (fwd_rs1_data),
        .b      (fwd_rs2_data),
        .mul_op (id_ex_funct3[1:0]),
        .result (mul_result)
    );

    // Hardware divider unit
    wire [31:0] div_result;
    wire        div_busy, div_done;
    reg         div_started;
    always @(posedge clk) begin
        if (!rst_n)
            div_started <= 1'b0;
        else if (div_done)
            div_started <= 1'b0;
        else if (id_ex_is_div && !div_started && !stall_mem)
            div_started <= 1'b1;
    end
    wire div_start = id_ex_is_div && !div_started && !stall_mem;

    divider u_div (
        .clk       (clk),
        .rst_n     (rst_n),
        .start     (div_start),
        .dividend  (fwd_rs1_data),
        .divisor   (fwd_rs2_data),
        .is_signed (id_ex_funct3[0] == 1'b0),
        .is_rem    (id_ex_funct3[1]),
        .result    (div_result),
        .busy      (div_busy),
        .done      (div_done)
    );

    // Execute stage output multiplexer
    wire [31:0] ex_result = id_ex_is_mul ? mul_result :
                            id_ex_is_div ? div_result :
                            (id_ex_wb_sel == WB_PC4) ? id_ex_pc4 :
                            alu_result;

    // Branch and jump target calculations
    wire [31:0] branch_target = id_ex_pc + id_ex_imm;
    wire [31:0] jalr_target   = (fwd_rs1_data + id_ex_imm) & 32'hFFFF_FFFE;

    // Conditional branch evaluation
    reg branch_cond;
    always @(*) begin
        case (id_ex_funct3)
            3'b000:  branch_cond = (fwd_rs1_data == fwd_rs2_data);
            3'b001:  branch_cond = (fwd_rs1_data != fwd_rs2_data);
            3'b100:  branch_cond = ($signed(fwd_rs1_data) < $signed(fwd_rs2_data));
            3'b101:  branch_cond = ($signed(fwd_rs1_data) >= $signed(fwd_rs2_data));
            3'b110:  branch_cond = (fwd_rs1_data < fwd_rs2_data);
            3'b111:  branch_cond = (fwd_rs1_data >= fwd_rs2_data);
            default: branch_cond = 1'b0;
        endcase
    end

    assign take_branch = ((id_ex_is_branch && branch_cond) || id_ex_is_jal || id_ex_is_jalr)
                        && id_ex_valid;
    assign pc_next = id_ex_is_jalr ? jalr_target : branch_target;

    // Store data formatting and byte mask generation
    wire [31:0] store_data;
    wire [3:0]  store_sel;
    wire [1:0]  byte_off = alu_result[1:0];

    assign store_data = (id_ex_funct3[1:0] == 2'b00) ? {4{fwd_rs2_data[7:0]}}  :
                        (id_ex_funct3[1:0] == 2'b01) ? {2{fwd_rs2_data[15:0]}} :
                                                        fwd_rs2_data;
    assign store_sel  = (id_ex_funct3[1:0] == 2'b00) ? (4'b0001 << byte_off) :
                        (id_ex_funct3[1:0] == 2'b01) ? (byte_off[1] ? 4'b1100 : 4'b0011) :
                                                        4'b1111;

    // Pipeline registers between EX and MEM stages
    reg [31:0] ex_mem_alu;
    reg [31:0] ex_mem_store_data;
    reg [3:0]  ex_mem_store_sel;
    reg [4:0]  ex_mem_rd;
    reg [2:0]  ex_mem_funct3;
    reg        ex_mem_reg_write, ex_mem_mem_read, ex_mem_mem_write;
    reg [1:0]  ex_mem_wb_sel;
    reg [31:0] ex_mem_pc4;
    reg        ex_mem_valid;

    always @(posedge clk) begin
        if (!rst_n) begin
            ex_mem_reg_write <= 0; ex_mem_mem_read <= 0; ex_mem_mem_write <= 0;
            ex_mem_valid <= 0;     ex_mem_rd       <= 5'd0;
            ex_mem_wb_sel    <= WB_ALU;
            ex_mem_alu       <= 32'd0; ex_mem_store_data <= 32'd0;
            ex_mem_store_sel <= 4'd0;  ex_mem_funct3     <= 3'd0;
            ex_mem_pc4       <= 32'd0;
        end else if (!stall_ex) begin
            if (stall_mem) begin
                ex_mem_reg_write <= 0; ex_mem_mem_read <= 0; ex_mem_mem_write <= 0;
                ex_mem_valid <= 0;
            end else begin
                ex_mem_alu        <= ex_result;
                ex_mem_store_data <= store_data;
                ex_mem_store_sel  <= store_sel;
                ex_mem_rd         <= id_ex_rd;
                ex_mem_funct3     <= id_ex_funct3;
                ex_mem_reg_write  <= id_ex_reg_write && id_ex_valid;
                ex_mem_mem_read   <= id_ex_mem_read  && id_ex_valid;
                ex_mem_mem_write  <= id_ex_mem_write && id_ex_valid;
                ex_mem_wb_sel     <= id_ex_wb_sel;
                ex_mem_pc4        <= id_ex_pc4;
                ex_mem_valid      <= id_ex_valid;
            end
        end
    end

    assign ex_mem_result = (ex_mem_wb_sel == WB_PC4) ? ex_mem_pc4 : ex_mem_alu;

    // Memory access and Wishbone bus master control
    wire mem_active = ex_mem_mem_read | ex_mem_mem_write;
    wire wb_wait    = mem_active & ~wb_ack_i;

    assign wb_cyc_o = mem_active;
    assign wb_stb_o = mem_active;
    assign wb_we_o  = ex_mem_mem_write;
    assign wb_adr_o = ex_mem_alu;
    assign wb_dat_o = ex_mem_store_data;
    assign wb_sel_o = ex_mem_mem_write ? ex_mem_store_sel : 4'b1111;

    // Load data alignment and sign extension
    wire [31:0] raw_load = wb_dat_i;
    wire [1:0]  load_off = ex_mem_alu[1:0];

    reg [31:0] load_data;
    always @(*) begin
        case (ex_mem_funct3)
            3'b000: begin
                case (load_off)
                    2'b00: load_data = {{24{raw_load[7]}},  raw_load[7:0]};
                    2'b01: load_data = {{24{raw_load[15]}}, raw_load[15:8]};
                    2'b10: load_data = {{24{raw_load[23]}}, raw_load[23:16]};
                    2'b11: load_data = {{24{raw_load[31]}}, raw_load[31:24]};
                endcase
            end
            3'b001: begin
                load_data = load_off[1] ? {{16{raw_load[31]}}, raw_load[31:16]}
                                        : {{16{raw_load[15]}}, raw_load[15:0]};
            end
            3'b010: load_data = raw_load;
            3'b100: begin
                case (load_off)
                    2'b00: load_data = {24'd0, raw_load[7:0]};
                    2'b01: load_data = {24'd0, raw_load[15:8]};
                    2'b10: load_data = {24'd0, raw_load[23:16]};
                    2'b11: load_data = {24'd0, raw_load[31:24]};
                endcase
            end
            3'b101: begin
                load_data = load_off[1] ? {16'd0, raw_load[31:16]}
                                        : {16'd0, raw_load[15:0]};
            end
            default: load_data = raw_load;
        endcase
    end

    // Pipeline registers between MEM and WB stages
    reg [31:0] mem_wb_alu;
    reg [31:0] mem_wb_load;
    reg [4:0]  mem_wb_rd;
    reg        mem_wb_reg_write;
    reg [1:0]  mem_wb_wb_sel;
    reg [31:0] mem_wb_pc4;

    always @(posedge clk) begin
        if (!rst_n) begin
            mem_wb_reg_write <= 0; mem_wb_rd <= 5'd0;
            mem_wb_wb_sel    <= WB_ALU;
            mem_wb_alu       <= 32'd0; mem_wb_load <= 32'd0;
            mem_wb_pc4       <= 32'd0;
        end else if (!stall_mem) begin
            mem_wb_alu       <= ex_mem_alu;
            mem_wb_load      <= load_data;
            mem_wb_rd        <= ex_mem_rd;
            mem_wb_reg_write <= ex_mem_reg_write && ex_mem_valid;
            mem_wb_wb_sel    <= ex_mem_wb_sel;
            mem_wb_pc4       <= ex_mem_pc4;
        end else begin
            mem_wb_reg_write <= 0;
        end
    end

    // Writeback multiplexer and register file write control
    assign wb_rf_wr_data = (mem_wb_wb_sel == WB_MEM) ? mem_wb_load :
                           (mem_wb_wb_sel == WB_PC4) ? mem_wb_pc4  :
                                                       mem_wb_alu;
    assign wb_rf_wr_addr = mem_wb_rd;
    assign wb_rf_wr_en   = mem_wb_reg_write;

    // Hazard detection unit instantiation
    hazard_unit u_hazard (
        .id_ex_mem_read (id_ex_mem_read && id_ex_valid),
        .id_ex_rd       (id_ex_rd),
        .if_id_rs1      (rs1_id),
        .if_id_rs2      (rs2_id),
        .branch_taken   (id_ex_is_branch && branch_cond && id_ex_valid),
        .jump_taken     ((id_ex_is_jal || id_ex_is_jalr) && id_ex_valid),
        .div_busy       (div_busy),
        .wb_stall       (wb_wait),
        .stall_if       (stall_if),
        .stall_id       (stall_id),
        .stall_ex       (stall_ex),
        .stall_mem      (stall_mem),
        .flush_if_id    (flush_if_id),
        .flush_id_ex    (flush_id_ex)
    );

    // Operand forwarding unit instantiation
    forwarding_unit u_fwd (
        .ex_rs1        (id_ex_rs1_addr),
        .ex_rs2        (id_ex_rs2_addr),
        .mem_rd        (ex_mem_rd),
        .mem_reg_write (ex_mem_reg_write),
        .mem_is_load   (ex_mem_mem_read),
        .wb_rd         (mem_wb_rd),
        .wb_reg_write  (mem_wb_reg_write),
        .forward_a     (fwd_a),
        .forward_b     (fwd_b)
    );

endmodule
