`include "defines.sv"

module processing_element(
    input  wire clk,
    input  wire rst_n,

    input  pe_inst_t     pe_inst,
    input  logic         pe_inst_valid,

    input  logic [`PE_INPUT_BITWIDTH-1:0]  vector_input,
    input  logic [`PE_INPUT_BITWIDTH-1:0]  matrix_input,

    // Output Operand
    output logic [`PE_OUTPUT_BITWIDTH-1:0] vector_output
);

    logic signed [63:0] acc, temp_acc;
    logic       pe_valid_first;
    logic       pe_valid_second;
    pe_inst_t   pe_inst_first;
    pe_inst_t   pe_inst_second;

    logic [31:0] output_q, output_d;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pe_valid_first  <= 1'b0;
            pe_valid_second <= 1'b0;
            pe_inst_first   <= '0;
            pe_inst_second  <= '0;
        end else begin
            pe_valid_first  <= pe_inst_valid;
            pe_valid_second <= pe_valid_first;
            pe_inst_first   <= pe_inst;
            pe_inst_second  <= pe_inst_first;
        end
    end

    logic signed [15:0] acc_split_curr [0:3];
    logic signed [15:0] acc_split_next [0:3];

    assign acc_split_curr[0] = acc[15:0];
    assign acc_split_curr[1] = acc[31:16];
    assign acc_split_curr[2] = acc[47:32];
    assign acc_split_curr[3] = acc[63:48];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc      <= '0;
            output_q <= '0;
        end else begin
            acc      <= temp_acc;
            output_q <= output_d;
        end
    end
    
    assign vector_output = output_q;

    always_comb begin
        temp_acc = acc;

        acc_split_next[0] = acc_split_curr[0];
        acc_split_next[1] = acc_split_curr[1];
        acc_split_next[2] = acc_split_curr[2];
        acc_split_next[3] = acc_split_curr[3];

        output_d = output_q;

        if (pe_valid_second) begin

            if (pe_inst_second.opcode == `PE_RND_OPCODE) begin
                case (pe_inst_second.mode)

                    `MODE_INT8: begin
                        acc_split_next[3] = $signed(acc_split_curr[3]) >>> pe_inst_second.value;
                        acc_split_next[2] = $signed(acc_split_curr[2]) >>> pe_inst_second.value;
                        acc_split_next[1] = $signed(acc_split_curr[1]) >>> pe_inst_second.value;
                        acc_split_next[0] = $signed(acc_split_curr[0]) >>> pe_inst_second.value;

                        temp_acc = {acc_split_next[3], acc_split_next[2], acc_split_next[1], acc_split_next[0]};
                    end

                    `MODE_INT16: begin
                        temp_acc[63:32] = $signed(acc[63:32]) >>> pe_inst_second.value;
                        temp_acc[31:0]  = $signed(acc[31:0])  >>> pe_inst_second.value;
                    end

                    `MODE_INT32: begin
                        temp_acc = $signed(acc) >>> pe_inst_second.value;
                    end
                endcase

            end else begin

                case (pe_inst_second.value)

                    `PE_MAC_VALUE: begin
                        case (pe_inst_second.mode)

                            `MODE_INT8: begin
                                acc_split_next[3] = acc_split_curr[3] + $signed(vector_input[31:24]) * $signed(matrix_input[31:24]);
                                acc_split_next[2] = acc_split_curr[2] + $signed(vector_input[23:16]) * $signed(matrix_input[23:16]);
                                acc_split_next[1] = acc_split_curr[1] + $signed(vector_input[15:8])  * $signed(matrix_input[15:8]);
                                acc_split_next[0] = acc_split_curr[0] + $signed(vector_input[7:0])   * $signed(matrix_input[7:0]);

                                temp_acc = {acc_split_next[3], acc_split_next[2], acc_split_next[1],acc_split_next[0]};
                            end

                            `MODE_INT16: begin
                                temp_acc[63:32] = $signed(acc[63:32]) + $signed(vector_input[31:16]) * $signed(matrix_input[31:16]);
                                temp_acc[31:0]  = $signed(acc[31:0]) + $signed(vector_input[15:0])  * $signed(matrix_input[15:0]);
                            end

                            `MODE_INT32: begin
                                temp_acc = acc + $signed(vector_input) * $signed(matrix_input);
                            end
                        endcase
                    end
                    `PE_PASS_VALUE: begin
                        case (pe_inst_second.mode)

                            `MODE_INT8: begin
                                acc_split_next[3] = {{8{vector_input[31]}}, vector_input[31:24]};
                                acc_split_next[2] = {{8{vector_input[23]}}, vector_input[23:16]};
                                acc_split_next[1] = {{8{vector_input[15]}}, vector_input[15:8]};
                                acc_split_next[0] = {{8{vector_input[7]}}, vector_input[7:0]};
                                temp_acc = {acc_split_next[3], acc_split_next[2], acc_split_next[1], acc_split_next[0]
                                };
                            end

                            `MODE_INT16: begin
                                temp_acc[63:32] = {{16{vector_input[31]}}, vector_input[31:16]};
                                temp_acc[31:0]  = {{16{vector_input[15]}}, vector_input[15:0]};
                            end

                            `MODE_INT32: begin
                                temp_acc = {{32{vector_input[31]}}, vector_input};
                            end
                        endcase
                    end
                    `PE_CLR_VALUE: begin
                        temp_acc = '0;
                        output_d = '0;
                    end
                    `PE_OUT_VALUE: begin
                        case (pe_inst_second.mode)

                            `MODE_INT8: begin
                                output_d = {acc[55:48], acc[39:32], acc[23:16], acc[7:0]};
                            end

                            `MODE_INT16: begin
                                output_d = {acc[47:32], acc[15:0]};
                            end

                            `MODE_INT32: begin
                                output_d = acc[31:0];
                            end
                        endcase
                    end

                    default: begin
                    end
                endcase
            end
        end
    end
endmodule