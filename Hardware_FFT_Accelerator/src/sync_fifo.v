`timescale 1ns / 1ps

module sync_fifo #(
    parameter DATA_WIDTH = 8,  
    parameter FIFO_DEPTH = 256 
)(
    input  wire                  clk,
    input  wire                  reset_n,
    
    input  wire [DATA_WIDTH-1:0] data_in,  
    input  wire                  write_en, 

    output reg  [DATA_WIDTH-1:0] data_out, 
    input  wire                  read_en,  
    
    output wire                  full,     
    output wire                  empty     
);

    reg [DATA_WIDTH-1:0] memory [0:FIFO_DEPTH-1]; 
    reg [7:0] write_ptr; 
    reg [7:0] read_ptr;  
    reg [8:0] count;     

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            write_ptr <= 8'd0;
            read_ptr  <= 8'd0;
            count     <= 9'd0;
            data_out  <= 8'd0;
        end else begin
            if (write_en && !full) begin
                memory[write_ptr] <= data_in; 
                write_ptr <= write_ptr + 8'd1; 
            end
            
            if (read_en && !empty) begin
                data_out <= memory[read_ptr]; 
                read_ptr <= read_ptr + 8'd1;   
            end
            
            if (write_en && !full && (!read_en || empty)) begin
                count <= count + 9'd1;
            end else if (read_en && !empty && (!write_en || full)) begin
                count <= count - 9'd1;
            end
        end
    end
    
    assign empty = (count == 9'd0); 
    assign full  = (count == FIFO_DEPTH); 

endmodule
