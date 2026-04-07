`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07.04.2026 18:55:26
// Design Name: 
// Module Name: butterfly_unit
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


module butterfly_unit (
    input  wire                 clk,
    input  wire                 reset_n,
    
    // 32-bit Girişler: [31:16] Reel Kısım, [15:0] İmajiner Kısım
    input  wire signed [31:0]   A,
    input  wire signed [31:0]   B,
    input  wire signed [31:0]   W,  // Twiddle Factor (ROM'dan gelecek)
    
    // 32-bit Çıkışlar
    output reg  signed [31:0]   X,
    output reg  signed [31:0]   Y
);

    // 1. Girişleri 16-bitlik Reel ve İmajiner parçalara (kablolara) ayır
    wire signed [15:0] A_r = A[31:16];
    wire signed [15:0] A_i = A[15:0];
    
    wire signed [15:0] B_r = B[31:16];
    wire signed [15:0] B_i = B[15:0];
    
    wire signed [15:0] W_r = W[31:16];
    wire signed [15:0] W_i = W[15:0];

    // 2. Karmaşık Çarpma İşlemleri (16-bit x 16-bit = 32-bit sonuç)
    wire signed [31:0] mult_rr = B_r * W_r;
    wire signed [31:0] mult_ii = B_i * W_i;
    wire signed [31:0] mult_ri = B_r * W_i;
    wire signed [31:0] mult_ir = B_i * W_r;

    // 3. Bulduğun denklemi uygula ve 15 bit sağa kaydırarak (>>> 15) Q1.15 formatına geri döndür
    wire signed [15:0] BW_r = (mult_rr - mult_ii) >>> 15;
    wire signed [15:0] BW_i = (mult_ri + mult_ir) >>> 15;

    // 4. A sayısı ile topla/çıkar (Kelebek Mantığı) ve sonuçları kaydet
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            X <= 32'd0;
            Y <= 32'd0;
        end else begin
            // Taşmayı (overflow) önlemek için sonucu 1 bit sağa kaydırarak (>>> 1) ikiye bölüyoruz
            X[31:16] <= (A_r + BW_r) >>> 1; // X Reel
            X[15:0]  <= (A_i + BW_i) >>> 1; // X İmajiner
            
            Y[31:16] <= (A_r - BW_r) >>> 1; // Y Reel
            Y[15:0]  <= (A_i - BW_i) >>> 1; // Y İmajiner
        end
    end

endmodule
