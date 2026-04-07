`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07.04.2026 23:17:09
// Design Name: 
// Module Name: dual_port_ram
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module dual_port_ram (
    input wire clk,
    
    // --- PORT A ---
    input  wire        we_a,    // Port A Yazma İzni (Write Enable)
    input  wire [7:0]  addr_a,  // Port A Adresi (0-255 arası)
    input  wire [31:0] din_a,   // Port A'dan Yazılacak Veri
    output reg  [31:0] dout_a,  // Port A'dan Okunan Veri
    
    // --- PORT B ---
    input  wire        we_b,    // Port B Yazma İzni
    input  wire [7:0]  addr_b,  // Port B Adresi
    input  wire [31:0] din_b,   // Port B'den Yazılacak Veri
    output reg  [31:0] dout_b   // Port B'den Okunan Veri
);

    // 256 adet 32-bitlik bellek odası (Tam olarak BRAM'e dönüşecek yapı)
    reg [31:0] ram [0:255];

    // Port A için Senkron Okuma/Yazma İşlemi
    always @(posedge clk) begin
        if (we_a) begin
            ram[addr_a] <= din_a;
        end
        // Okuma işlemi her saat vuruşunda otomatik yapılır (Pipeline'ın 1. gecikmesi)
        dout_a <= ram[addr_a]; 
    end

    // Port B için Senkron Okuma/Yazma İşlemi
    always @(posedge clk) begin
        if (we_b) begin
            ram[addr_b] <= din_b;
        end
        dout_b <= ram[addr_b];
    end

endmodule
