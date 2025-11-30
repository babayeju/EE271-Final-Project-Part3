module processing_element(
    input wire clk,
    input wire rst_n,
    input pe_inst_t     pe_inst,
    input logic         pe_inst_valid,
    input logic [`PE_INPUT_BITWIDTH-1:0] vector_input,
    input logic [`PE_INPUT_BITWIDTH-1:0] matrix_input,
    output logic [`PE_OUTPUT_BITWIDTH-1:0] vector_output
);

    logic [`PE_ACCUMULATION_BITWIDTH-1:0] accumulation_register;

    pe_inst_t     pe_inst_reg;
    logic         pe_inst_valid_reg;

    always @(posedge clk, negedge rst_n) pe_inst_reg <= (rst_n == '0) ? '0 : pe_inst;
    always @(posedge clk, negedge rst_n) pe_inst_valid_reg <= (rst_n == '0) ? '0 : pe_inst_valid;

    logic signed [31:0] vec_lane [0:3];
    logic signed [31:0] mat_lane [0:3];
    logic signed [63:0] prod_lane[0:3];

    always_comb begin
        for (int k = 0; k < 4; k++) begin
            vec_lane[k] = '0;
            mat_lane[k] = '0;
        end
        case (pe_inst_reg.mode)
            `MODE_INT8: begin
                vec_lane[0] = {{24{vector_input[7]}},   vector_input[7:0]};
                vec_lane[1] = {{24{vector_input[15]}},  vector_input[15:8]};
                vec_lane[2] = {{24{vector_input[23]}},  vector_input[23:16]};
                vec_lane[3] = {{24{vector_input[31]}},  vector_input[31:24]};
                mat_lane[0] = {{24{matrix_input[7]}},   matrix_input[7:0]};
                mat_lane[1] = {{24{matrix_input[15]}},  matrix_input[15:8]};
                mat_lane[2] = {{24{matrix_input[23]}},  matrix_input[23:16]};
                mat_lane[3] = {{24{matrix_input[31]}},  matrix_input[31:24]};
            end
            `MODE_INT16: begin
                vec_lane[0] = {{16{vector_input[15]}},  vector_input[15:0]};
                vec_lane[1] = {{16{vector_input[31]}},  vector_input[31:16]};
                mat_lane[0] = {{16{matrix_input[15]}},  matrix_input[15:0]};
                mat_lane[1] = {{16{matrix_input[31]}},  matrix_input[31:16]};
            end
            `MODE_INT32: begin
                vec_lane[0] = vector_input;
                mat_lane[0] = matrix_input;
            end
        endcase
    end

    generate
        genvar k;
        for (k = 0; k < 4; k++) begin : shared_mults
            assign prod_lane[k] = vec_lane[k] * mat_lane[k];
        end
    endgenerate

    always_ff @(posedge clk, negedge rst_n) begin
        if (rst_n == '0) begin
            accumulation_register <= '0;
            vector_output <= '0;
        end else if (pe_inst_valid_reg) begin
            if (pe_inst_reg.opcode == '0) begin
                case (pe_inst_reg.value)
                    `PE_MAC_VALUE: begin
                        case (pe_inst_reg.mode)
                            `MODE_INT8: begin
                                accumulation_register[15:0]   <= accumulation_register[15:0]   + prod_lane[0][15:0];
                                accumulation_register[31:16]  <= accumulation_register[31:16]  + prod_lane[1][15:0];
                                accumulation_register[47:32]  <= accumulation_register[47:32]  + prod_lane[2][15:0];
                                accumulation_register[63:48]  <= accumulation_register[63:48]  + prod_lane[3][15:0];
                            end
                            `MODE_INT16: begin
                                accumulation_register[31:0]   <= accumulation_register[31:0]   + prod_lane[0][31:0];
                                accumulation_register[63:32]  <= accumulation_register[63:32]  + prod_lane[1][31:0];
                            end
                            `MODE_INT32: begin
                                accumulation_register[63:0]   <= accumulation_register[63:0]   + prod_lane[0][63:0];
                            end
                        endcase
                    end
                    `PE_OUT_VALUE: begin
                        case (pe_inst_reg.mode)
                            `MODE_INT8: begin
                                vector_output[7:0]    <= accumulation_register[7:0];
                                vector_output[15:8]   <= accumulation_register[23:16];
                                vector_output[23:16]  <= accumulation_register[39:32];
                                vector_output[31:24]  <= accumulation_register[55:48];
                            end
                            `MODE_INT16: begin
                                vector_output[15:0]   <= accumulation_register[15:0];
                                vector_output[31:16]  <= accumulation_register[47:32];
                            end
                            `MODE_INT32: begin
                                vector_output <= accumulation_register[31:0];
                            end
                        endcase
                    end
                    `PE_PASS_VALUE: begin
                        case (pe_inst_reg.mode)
                            `MODE_INT8: begin
                                accumulation_register[15:0]   <= {{8{vector_input[7]}},  vector_input[7:0]};
                                accumulation_register[31:16]  <= {{8{vector_input[15]}}, vector_input[15:8]};
                                accumulation_register[47:32]  <= {{8{vector_input[23]}}, vector_input[23:16]};
                                accumulation_register[63:48]  <= {{8{vector_input[31]}}, vector_input[31:24]};
                            end
                            `MODE_INT16: begin
                                accumulation_register[31:0]   <= {{16{vector_input[15]}}, vector_input[15:0]};
                                accumulation_register[63:32]  <= {{16{vector_input[31]}}, vector_input[31:16]};
                            end
                            `MODE_INT32: begin
                                accumulation_register[63:0]   <= {{32{vector_input[31]}}, vector_input};
                            end
                        endcase
                    end
                    `PE_CLR_VALUE: accumulation_register <= '0;
                endcase
            end else begin
                case (pe_inst_reg.opcode)
                    `PE_RND_OPCODE: begin
                        case (pe_inst_reg.mode)
                            `MODE_INT8: begin
                                for (int i = 0; i < 4; i++) begin
                                    accumulation_register[(16*i)+:16] <= accumulation_register[(16*i)+:16] >>> pe_inst_reg.value;
                                end
                            end
                            `MODE_INT16: begin
                                for (int i = 0; i < 2; i++) begin
                                    accumulation_register[(32*i)+:32] <= accumulation_register[(32*i)+:32] >>> pe_inst_reg.value;
                                end
                            end
                            `MODE_INT32: begin
                                accumulation_register <= accumulation_register >>> pe_inst_reg.value;
                            end
                        endcase
                    end
                endcase
            end
        end
    end
endmodule

