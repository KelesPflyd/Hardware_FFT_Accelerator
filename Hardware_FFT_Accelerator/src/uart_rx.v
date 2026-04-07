`timescale 1ns / 1ps

module uart_rx(
    input  wire       clk,        
    input  wire       reset_n,    
    input  wire       rx_in,      
    output reg  [7:0] rx_data,    
    output reg        rx_valid    
);
    parameter CLK_FREQ   = 27000000; 
    parameter BAUD_RATE  = 57600;
    parameter OVERSAMPLE = 16;
    parameter TICK_LIMIT = CLK_FREQ / (BAUD_RATE * OVERSAMPLE); 

    reg [4:0] tick_counter; 
    reg       tick;         

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            tick_counter <= 5'd0;
            tick         <= 1'b0;
        end else begin
            if (tick_counter == TICK_LIMIT - 1) begin
                tick_counter <= 5'd0;    
                tick         <= 1'b1;    
            end else begin
                tick_counter <= tick_counter + 5'd1;
                tick         <= 1'b0;    
            end
        end
    end
    
    localparam [1:0] 
        IDLE  = 2'b00,
        START = 2'b01,
        DATA  = 2'b10,
        STOP  = 2'b11;

    reg [1:0] state;       
    reg [3:0] s_tick;      
    reg [2:0] n_bits;      
    reg [7:0] shift_reg;   

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state    <= IDLE;
            s_tick   <= 0;
            n_bits   <= 0;
            rx_data  <= 0;
            rx_valid <= 0;
        end else begin
            rx_valid <= 1'b0; 

            if (tick) begin
                case (state)
                    IDLE: begin
                        if (rx_in == 1'b0) begin 
                            state  <= START;
                            s_tick <= 0;
                        end
                    end
                    START: begin
                        if (s_tick == 7) begin 
                            if (rx_in == 1'b0) begin 
                                state  <= DATA;
                                s_tick <= 0;
                                n_bits <= 0;
                            end else begin
                                state <= IDLE; 
                            end
                        end else begin
                            s_tick <= s_tick + 1;
                        end
                    end
                    DATA: begin
                        if (s_tick == 15) begin 
                            s_tick    <= 0;
                            shift_reg <= {rx_in, shift_reg[7:1]}; 
                            
                            if (n_bits == 7) begin 
                                state <= STOP;
                            end else begin
                                n_bits <= n_bits + 1;
                            end
                        end else begin
                            s_tick <= s_tick + 1;
                        end
                    end
                    STOP: begin
                        if (s_tick == 15) begin 
                            state    <= IDLE;
                            rx_data  <= shift_reg; 
                            rx_valid <= 1'b1;      
                        end else begin
                            s_tick <= s_tick + 1;
                        end
                    end
                endcase
            end
        end
    end
endmodule
