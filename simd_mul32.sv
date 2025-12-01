// simd_mul32.sv
`include "defines.sv"

module simd_mul32 (
    input  logic [`PE_INPUT_BITWIDTH-1:0] a,   // 32-bit signed lanes
    input  logic [`PE_INPUT_BITWIDTH-1:0] b,   // 32-bit signed lanes
    input  logic [`PE_MODE_BITWIDTH-1:0]  mode,
    output logic [63:0]                   lanes_prod // packed lane products (no gaps): 
                                                    // INT8 : 4×16b  = [lan3|lan2|lan1|lan0]
                                                    // INT16: 2×32b  = [lan1|lan0]
                                                    // INT32: 1×64b
);

    logic [31:0] a_spaced, b_spaced;     // operands with zeros between lanes
    logic signed [31:0] a_s, b_s;
    logic signed [63:0] p64;

    // Build spaced operands so cross-lane partial products cannot overlap
    always_comb begin
        a_spaced = '0;
        b_spaced = '0;

        unique case (mode)
            `MODE_INT8: begin
                // 4 lanes. Put each signed 8b value into a signed 16b slot and space by 16 bits.
                for (int i = 0; i < 4; i++) begin
                    logic signed [15:0] ai = {{8{a[(8*i)+7]}}, a[(8*i)+:8]};
                    logic signed [15:0] bi = {{8{b[(8*i)+7]}}, b[(8*i)+:8]};
                    a_spaced |= (32'(ai) << (16*i));
                    b_spaced |= (32'(bi) << (16*i));
                end
            end
            `MODE_INT16: begin
                // 2 lanes. Put each signed 16b into a signed 32b slot and space by 32 bits.
                for (int i = 0; i < 2; i++) begin
                    logic signed [31:0] ai = {{16{a[(16*i)+15]}}, a[(16*i)+:16]};
                    logic signed [31:0] bi = {{16{b[(16*i)+15]}}, b[(16*i)+:16]};
                    a_spaced |= (ai << (32*i));
                    b_spaced |= (bi << (32*i));
                end
            end
            default: begin // `MODE_INT32
                a_spaced = a;
                b_spaced = b;
            end
        endcase
    end

    // Single 32x32 signed multiply
    assign a_s = a_spaced;
    assign b_s = b_spaced;
    assign p64 = a_s * b_s;

    // Repack lane products densely (no gaps) for the PE to consume
    always_comb begin
        lanes_prod = '0;
        unique case (mode)
            `MODE_INT8: begin
                for (int i = 0; i < 4; i++) begin
                    // Each 8x8 product lives in the lower 16 bits of the 32-bit chunk starting at 32*i
                    lanes_prod[(16*i)+:16] = p64[(32*i)+:16];
                end
            end
            `MODE_INT16: begin
                // Each 16x16 product is 32 bits at [31:0] and [63:32]
                lanes_prod[31:0]  = p64[31:0];
                lanes_prod[63:32] = p64[63:32];
            end
            default: begin // `MODE_INT32
                lanes_prod = p64;
            end
        endcase
    end

endmodule
