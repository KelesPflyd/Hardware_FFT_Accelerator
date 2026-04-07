`timescale 1ns / 1ps

module fft_core_tb();

    // Sistem Sinyalleri
    reg clk;
    reg reset_n;
    reg rx_in;
    wire fft_done;

    // Ana FFT Çekirdeğini Masaya Çağır
    fft_core_top uut (
        .clk(clk),
        .reset_n(reset_n),
        .rx_in(rx_in),
        .fft_done(fft_done)
    );

    // 27 MHz Saat Üreteci
    initial begin
        clk = 0;
        forever #18.5 clk = ~clk;
    end

    // UART Baud Rate Süresi (57600 bps için)
    localparam BIT_PERIOD = 17361;

    // --- İŞTE ARADIĞIN FONKSİYON (TASK) BURADA ---
    // Bu task, çağırdığımızda içine yazdığımız 8-bitlik sayıyı
    // UART protokolüyle (Start + 8-bit + Stop) donanıma yedirir.
    task send_uart_byte(input [7:0] data);
        integer i;
        begin
            rx_in = 0; #(BIT_PERIOD); // Start biti
            for(i=0; i<8; i=i+1) begin
                rx_in = data[i]; #(BIT_PERIOD); // Veri bitleri (LSB First)
            end
            rx_in = 1; #(BIT_PERIOD); // Stop biti
        end
    endtask
    // ---------------------------------------------

    // Test Senaryosu
    integer j;
    initial begin
        // 1. Sistemi Sıfırla (Reset)
        reset_n = 0;
        rx_in = 1; // Hat boşta
        #1000;
        reset_n = 1;
        #1000;

        // 2. FIFO'yu Doldur (256 Adet Veri Gönder)
        // Burada bir kare dalga üretiyoruz (çift sayılarda 100, tek sayılarda 0)
        $display("UART veri iletimi basliyor...");
        
        for (j = 0; j < 256; j = j + 1) begin
            if (j % 2 == 0) begin
                send_uart_byte(8'd100); // Üst seviye
            end else begin
                send_uart_byte(8'd0);   // Alt seviye
            end
        end
        
        $display("256 adet veri UART uzerinden gonderildi. FFT bekleniyor...");

        // 3. FFT'nin Bitmesini Bekle
        wait(fft_done == 1'b1);
        
        $display("FFT ISLEMI BASARIYLA TAMAMLANDI!");

        // İşlemleri izlemek için biraz daha bekle ve simülasyonu bitir
        #50000;
        $finish;
    end

endmodule
