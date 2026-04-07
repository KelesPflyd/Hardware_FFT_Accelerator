% --- 256 Noktalı FFT için Twiddle Factor ROM Üretici ---

N = 256;          % Toplam FFT Nokta Sayısı
N_half = N / 2;   % Sadece N/2 (128) adet katsayı hesaplamamız yeterli

% Çıktı dosyasını oluştur (Vivado ile aynı klasöre koymalısın)
fileID = fopen('twiddle_factors.mem', 'w');

for k = 0:(N_half - 1)
    
    % 1. Adım: Açısal değeri ve Ondalıklı (Floating) değerleri hesapla
    % Formül: W = cos(2*pi*k/N) - j*sin(2*pi*k/N)
    theta = (2 * pi * k) / N;
    real_val = cos(theta);
    imag_val = -sin(theta);  % Eksi işaretine dikkat!
    
    % 2. Adım: Q1.15 Fixed-Point (Sabit Noktalı) Formatına Çevir
    % 32768 (2^15) ile çarpıp tam sayıya yuvarlıyoruz.
    real_q15 = round(real_val * 32768);
    imag_q15 = round(imag_val * 32768);
    
    % --- KRİTİK DONANIM KORUMASI 1: Overflow (Taşma) ---
    % Eğer değer tam 1.0 çıkarsa, 32768 olur. Ancak 16-bit işaretli (signed)
    % sistemlerde pozitif maksimum değer 32767'dir. 32768 yazarsak
    % donanım bunu negatif sayı (-32768) zanneder! Bu yüzden kırpıyoruz.
    if real_q15 == 32768
        real_q15 = 32767;
    end
    if imag_q15 == 32768
        imag_q15 = 32767;
    end
    
    % --- KRİTİK DONANIM KORUMASI 2: 2's Complement (2'ye Tümleyen) ---
    % Verilog'daki '$readmemh' komutu eksi (-) işaretini anlamaz.
    % Hex formatında negatif sayıları, 16-bitin 2'ye tümleyeni olarak 
    % (yani 65536 ekleyerek) yazmalıyız.
    if real_q15 < 0
        real_q15 = real_q15 + 65536;
    end
    if imag_q15 < 0
        imag_q15 = imag_q15 + 65536;
    end
    
    % 3. Adım: Dosyaya yazdır 
    % Format: 16-bit Reel (4 hane hex) yanına 16-bit İmajiner (4 hane hex)
    % Toplamda 32-bitlik (8 hane) tek bir satır oluşacak.
    fprintf(fileID, '%04X%04X\n', real_q15, imag_q15);
end

fclose(fileID);
disp('Başarılı: twiddle_factors.mem dosyası oluşturuldu!');
