`include "defines.sv"

module controller(

    // Clock and Reset
    input wire clk,
    input wire rst_n,

    // Input Instruction
    input  instruction_t inst,
    input  logic         inst_valid,
    output logic         inst_exec_begins,

    // Output Instructions to PEs/Buffer
    output pe_inst_t     pe_inst,
    output logic         pe_inst_valid,
    output buf_inst_t    buf_inst,
    output logic         buf_inst_valid

);

    // Internal Signals
    instruction_t inst_internal;
    logic [`CONTROLLER_COUNTER_BITWIDTH-1:0] counter;

    // Creating the State Machine
    typedef enum {IDLE, EXECUTING} fsm_t; 
    fsm_t state;

    always_ff @(posedge clk, negedge rst_n) begin
        if (rst_n == 1'b0) begin
            state            <= IDLE;
            pe_inst          <= '0;
            pe_inst_valid    <= '0;
            buf_inst         <= '0;
            buf_inst_valid   <= '0; 
            counter          <= '0;    
            inst_exec_begins <= '0;
            inst_internal    <= '0;
        end else begin
            
            // State Machine
            case(state)
                IDLE : begin
                    
                    // Preparing State Transition
                    if(inst_valid == 1'b1) begin
                        state <= EXECUTING;
                        buf_inst_valid   <= '1;
                        pe_inst_valid    <= '1;
                        inst_exec_begins <= '1;
                    end else begin
                        state <= IDLE;
                        buf_inst_valid   <= '0;
                        pe_inst_valid    <= '0;
                        inst_exec_begins <= '0;
                    end

                    // Registering Inputs
                    pe_inst        <= inst.pe_instruction;
                    buf_inst       <= inst.buf_instruction;
                    inst_internal  <= inst;
                    counter        <= '0;

                end
                EXECUTING : begin

                    // Iterating Through Memory & Switching Back to Idle Once Count is Achieved
                    counter <= counter + 1;
                    if(counter >= inst_internal.count) begin
                        state <= IDLE;
                        buf_inst_valid <= '0;
                        pe_inst_valid  <= '0;
                        pe_inst  <= inst_internal.pe_instruction;
                        buf_inst <= inst_internal.buf_instruction;
                    end else begin
                        state <= EXECUTING;
                        buf_inst_valid <= '1;
                        pe_inst_valid  <= '1;
                        buf_inst.mema_offset <= buf_inst.mema_offset + inst_internal.mema_inc;
                        buf_inst.memb_offset <= buf_inst.memb_offset + inst_internal.memb_inc;
                    end
                    inst_exec_begins <= '0;

                end
            endcase

        end
    end




endmodule

