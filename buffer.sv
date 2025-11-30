`include "defines.sv"

module buffer (
    // Clock and Reset
    input wire clk,
    input wire rst_n,

    // Input Instruction
    input buf_inst_t    buf_inst,
    input logic         buf_inst_valid,

    // Outputs
    output logic [`MEM0_BITWIDTH-1:0] matrix_data,
    output logic [`MEM1_BITWIDTH-1:0] vector_data,
    input  logic [`MEM2_BITWIDTH-1:0] output_data
);

    // Creating the Memories
    array #(
        .DW(`MEM0_BITWIDTH),
        .NW(`MEM0_DEPTH),
        .AW(`MEM0_ADDR_WIDTH)
    ) u_matrix_mem (
        .clk(clk),
        .cen('0),
        .wen('1),
        .gwen('1),
        .a(buf_inst.mema_offset),
        .d('0),
        .q(matrix_data)
    );

    // Vector Data Translation
    logic [`MEM1_BITWIDTH-1:0]     internal_vector_data;
    logic [`MEM1_ADDR_WIDTH-1:0]   internal_vector_addr;
    logic [`BUF_MEMB_OFFSET_BITWIDTH-1:0] memb_offset_reg;
    always @(posedge clk, negedge rst_n) memb_offset_reg <= (rst_n == 1'b0) ? '0 : buf_inst.memb_offset;
    vector_decoder u_vector_decoder (
        .data_from_mem(internal_vector_data),
        .addr_from_controller(buf_inst.memb_offset),
        .addr_from_controller_reg(memb_offset_reg),
        .mode(buf_inst.mode),
        .data_to_pe(vector_data),
        .addr_to_mem(internal_vector_addr)
    );
    array #(
        .DW(`MEM1_BITWIDTH),
        .NW(`MEM1_DEPTH),
        .AW(`MEM1_ADDR_WIDTH)
    ) u_vector_mem (
        .clk(clk),
        .cen('0),
        .wen('1),
        .gwen('1),
        .a(internal_vector_addr),
        .d('0),
        .q(internal_vector_data)
    );


    // Handling Writing Back
    logic write_to_mem;
    assign write_to_mem = ~((buf_inst.opcode == `BUF_WRITE) & buf_inst_valid);
    array #(
        .DW(`MEM2_BITWIDTH),
        .NW(`MEM2_DEPTH),
        .AW(`MEM2_ADDR_WIDTH),
        .INITIALIZE_MEMORY(1)
    ) u_output_mem (
        .clk(clk),
        .cen('0),
        .wen('0),
        .gwen(write_to_mem),
        .a(buf_inst.mema_offset),
        .d(output_data),
        .q() // Leave Output Unconnected
    );





endmodule
