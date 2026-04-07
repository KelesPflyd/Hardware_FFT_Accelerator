`timescale 1ns / 1ps

module fft_core_top (
    input  wire        clk,
    input  wire        reset_n,
    input  wire        rx_in,       
    output reg         fft_done     
);

    // =========================================================================
    // İÇ SİNYALLER VE KABLOLAR
    // =========================================================================
    wire [7:0]  w_uart_data;
    wire        w_uart_valid;
    wire [7:0]  w_fifo_data_out;
    wire        w_fifo_full;
    wire        w_fifo_empty;
    reg         r_fifo_read_en;

    reg         r_we_a, r_we_b;
    reg  [7:0]  r_addr_a, r_addr_b;
    reg  [31:0] r_din_a, r_din_b;
    wire [31:0] w_dout_a, w_dout_b;

    wire [31:0] w_twiddle_data;
    reg  [6:0]  r_twiddle_addr;

    wire [31:0] w_bfly_X, w_bfly_Y;

    // =========================================================================
    // MODÜL BAĞLANTILARI (LEGO PARÇALARI)
    // =========================================================================
    uart_rx u_uart (
        .clk(clk), .reset_n(reset_n), .rx_in(rx_in),
        .rx_data(w_uart_data), .rx_valid(w_uart_valid)
    );

    sync_fifo u_fifo (
        .clk(clk), .reset_n(reset_n),
        .data_in(w_uart_data), .write_en(w_uart_valid),
        .data_out(w_fifo_data_out), .read_en(r_fifo_read_en),
        .full(w_fifo_full), .empty(w_fifo_empty)
    );

    dual_port_ram u_ram (
        .clk(clk),
        .we_a(r_we_a), .addr_a(r_addr_a), .din_a(r_din_a), .dout_a(w_dout_a),
        .we_b(r_we_b), .addr_b(r_addr_b), .din_b(r_din_b), .dout_b(w_dout_b)
    );

    twiddle_rom u_rom (
        .clk(clk), .addr(r_twiddle_addr), .twiddle_data(w_twiddle_data)
    );

    butterfly_unit u_bfly (
        .clk(clk), .reset_n(reset_n),
        .A(w_dout_a), .B(w_dout_b), .W(w_twiddle_data),
        .X(w_bfly_X), .Y(w_bfly_Y)
    );

    // =========================================================================
    // ANA KONTROLCÜ (FSM) MANTIĞI VE DURUMLARI
    // =========================================================================
    localparam [2:0] WAIT_FIFO  = 3'd0,
                     LOAD_RAM   = 3'd1,
                     FFT_STAGE  = 3'd2,
                     BFLY_READ  = 3'd3,
                     BFLY_WAIT  = 3'd4,
                     BFLY_CALC  = 3'd5,
                     BFLY_WRITE = 3'd6,
                     DONE       = 3'd7;

    reg [2:0] state;
    reg [8:0] load_counter; 
    reg [3:0] stage;        
    reg [7:0] bfly_count;   

    // Adresleme ve Bit-Reversal (Fiziksel Kablolama)
    wire [7:0] bit_reversed_addr = {load_counter[0], load_counter[1], load_counter[2], load_counter[3],
                                    load_counter[4], load_counter[5], load_counter[6], load_counter[7]};

    wire [7:0] offset = 8'd1 << stage; 
    wire [7:0] k_idx  = bfly_count & (offset - 8'd1); 
    wire [7:0] g_shifted = (bfly_count >> stage) << (stage + 8'd1); 
    
    wire [7:0] calc_addr_A = g_shifted | k_idx;
    wire [7:0] calc_addr_B = calc_addr_A + offset;
    wire [6:0] calc_twiddle_addr = k_idx * (8'd128 >> stage);

    // Adresleri okuma anından yazma anına kadar hafızada tutmak için cep register'ları
    reg [7:0] saved_addr_A, saved_addr_B;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state          <= WAIT_FIFO;
            r_fifo_read_en <= 1'b0;
            fft_done       <= 1'b0;
            r_we_a         <= 1'b0;
            r_we_b         <= 1'b0;
            load_counter   <= 9'd0;
            stage          <= 4'd0;
            bfly_count     <= 8'd0;
        end else begin
            case (state)
                WAIT_FIFO: begin
                    fft_done <= 1'b0;
                    r_we_a   <= 1'b0;
                    r_we_b   <= 1'b0;
                    if (w_fifo_full) begin 
                        state          <= LOAD_RAM;
                        load_counter   <= 9'd0;
                        r_fifo_read_en <= 1'b1; 
                    end
                end
                
                LOAD_RAM: begin
                    if (load_counter < 256) begin
                        // Q1.15 formata uydur ve sinyali güçlendir. 
                        // Reel kısmın en üst bitlerine yerleştiriyoruz, İmajiner kısım 16'd0 kalıyor.
                        r_din_a  <= {w_fifo_data_out, 8'd0, 16'd0}; 
                        r_addr_a <= bit_reversed_addr; 
                        r_we_a   <= 1'b1;
                        load_counter <= load_counter + 9'd1;
                    end else begin
                        r_we_a         <= 1'b0;
                        r_fifo_read_en <= 1'b0;
                        state          <= FFT_STAGE;
                        stage          <= 4'd0;
                    end
                end
                
                FFT_STAGE: begin
                    r_we_a <= 1'b0;
                    r_we_b <= 1'b0;
                    if (stage == 4'd8) begin 
                        state <= DONE; // 8 aşama bitti!
                    end else begin
                        state      <= BFLY_READ;
                        bfly_count <= 8'd0;
                    end
                end
                
                BFLY_READ: begin
                    // 1. ADIM: Güvenli Okuma İsteği
                    r_we_a <= 1'b0;
                    r_we_b <= 1'b0;
                    r_addr_a <= calc_addr_A;
                    r_addr_b <= calc_addr_B;
                    r_twiddle_addr <= calc_twiddle_addr;
                    
                    // Adresleri kaybolmasın diye cebe atıyoruz
                    saved_addr_A <= calc_addr_A;
                    saved_addr_B <= calc_addr_B;
                    
                    state <= BFLY_WAIT;
                end
                
                BFLY_WAIT: begin
                    // 2. ADIM: RAM 1 clock gecikmeli olduğu için verilerin Kelebek kapısına gelmesini bekle
                    state <= BFLY_CALC;
                end
                
                BFLY_CALC: begin
                    // 3. ADIM: Kelebek ünitesi de 1 clock gecikmeli çalıştığı için sonucun çıkmasını bekle
                    state <= BFLY_WRITE;
                end
                
                BFLY_WRITE: begin
                    // 4. ADIM: Çıkan sonuçları (X ve Y) cebimizdeki adreslere güvenle geri yaz!
                    r_we_a <= 1'b1;
                    r_we_b <= 1'b1;
                    r_addr_a <= saved_addr_A;
                    r_addr_b <= saved_addr_B;
                    r_din_a  <= w_bfly_X;
                    r_din_b  <= w_bfly_Y;
                    
                    // O aşamadaki 128 adet işlem bitti mi kontrol et
                    if (bfly_count == 127) begin
                        stage <= stage + 4'd1;
                        state <= FFT_STAGE;
                    end else begin
                        bfly_count <= bfly_count + 8'd1;
                        state <= BFLY_READ; 
                    end
                end
                
                DONE: begin
                    fft_done <= 1'b1; // Analiz Bitti bayrağını kaldır
                    r_we_a   <= 1'b0;
                    r_we_b   <= 1'b0;
                end
            endcase
        end
    end
endmodule
