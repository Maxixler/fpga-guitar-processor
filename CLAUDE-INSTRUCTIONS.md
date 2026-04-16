# CLAUDE-INSTRUCTIONS.md
# FPGA Gitar Efekt Prosesörü — Geliştirici Rehberi

Bu dosya, projenin tüm teknik tasarım kararlarını, mimari seçimlerini ve geliştirme geçmişini belgeleler. Projeye devam eden her geliştirici (veya AI asistan) bu dosyayı okuyarak mevcut yapıyı anlamalıdır.

---

## 1. Proje Tanımı

**Hedef:** Digilent Nexys A7-T100 FPGA kartı (Artix-7 XC7A100T) üzerinde gerçek zamanlı elektro gitar efekt prosesörü.

**Kullanıcı Kısıtlamaları (Orijinal Konuşmadan):**
- Ek modül bulunmuyor (Pmod I2S2, harici codec yok)
- Audio I/O: Onboard XADC (giriş) + Onboard PWM amplifikatör (çıkış)
- Efekt zinciri: Seri bağlama (birden fazla efekt eş zamanlı aktif)
- Geliştirme ortamı: Vivado 2025.1
- Dil: Verilog

---

## 2. Hardware Platformu

### Kart: Digilent Nexys A7-T100
- **FPGA:** Xilinx Artix-7 XC7A100T (csg324-1)
- **Saat:** 100 MHz onboard oscillator (pin E3)
- **ADC:** Onboard XADC (12-bit, max 1 MSPS, kullanılan: 48 kSPS)
- **Audio Çıkış:** Onboard PWM mono amplifier (AUD_PWM: A11, AUD_SD: D12)
- **BRAM:** 135 × 36 Kb = 4,860 Kb toplam
- **DSP48E1:** 240 adet
- **LUT:** 63,400 adet

### XADC Analog Giriş Kısıtlamaları
- Giriş voltaj aralığı: **0V – 1V differential** (kesinlikle aşılmamalı)
- Kullanılan kanal: **Aux Channel 6** (VAUXP6: A13, VAUXN6: A14, JXADC header)
- Gitar sinyali doğrudan bağlanamaz → harici analog ön devre zorunlu

### Harici Analog Ön Devre (Kullanıcı Kurmalı)
- **TL072** JFET op-amp (düşük gürültü, yüksek giriş empedansı)
- Giriş empedansı: 1 MΩ (gitar pickup ile uyumlu)
- DC bias: 0.5V (XADC'nin 0-1V aralığının ortası)
- Anti-aliasing: RC LPF, fc ≈ 20 kHz
- Detaylı şema: `docs/analog_frontend_schematic.md`

---

## 3. Sinyal İşleme Mimarisi

### Tam Sinyal Zinciri

```
[Guitar] → [Analog Frontend] → [XADC] → [DC Block] → [FIR LPF]
         → [Noise Gate] → [Distortion] → [Overdrive]
         → [Delay] → [Reverb] → [Chorus] → [Tremolo]
         → [Volume Scale] → [TPDF Dither] → [Sigma-Delta DAC]
         → [PWM Output] → [Amplifier/Headphone]
```

### Fixed-Point Format
- **Q1.23:** 1 sign bit + 23 fractional bits = 24 bit toplam
- Range: -1.0 to ≈+0.9999999
- Tüm modüller bu formatı kullanır
- Ara hesaplamalar: **48-bit signed** (çarpma taşmasını önlemek için)
- Header: `src/utils/fixed_point_math.vh`

### Örnekleme Hızı
- **48 kHz** (audio standart)
- Üretim: 100 MHz / 2083 = 48.007 kHz (yeterince yakın)
- `sample_clk` adlı 1-cycle strobe sinyali tüm DSP modüllerine beslenir
- Her modül `sample_clk` yüksek geldiğinde bir örnek işler

---

## 4. Dosya Yapısı ve Modül Hiyerarşisi

```
src/
├── top_guitar_processor.v          ← Top-level, tüm bağlantılar burada
├── utils/
│   ├── fixed_point_math.vh         ← Q1.23 makrolar, SATURATE fonksiyonları
│   ├── lfsr.v                      ← 32-bit maximal-length LFSR (PRNG)
│   └── sine_lut.v                  ← 256-entry quarter-wave sine LUT
├── audio_input/
│   ├── xadc_interface.v            ← XADC IP sarmalayıcı + DRP state machine
│   └── dc_blocking_filter.v        ← 1st-order IIR HPF, α=0.995, fc≈3.8Hz
├── audio_output/
│   ├── sigma_delta_dac.v           ← 2nd-order Sigma-Delta modülatör
│   └── dithering.v                 ← TPDF dithering (iki LFSR toplamı)
├── dsp/
│   ├── effects_chain.v             ← Seri yönlendirici, 7 stage
│   ├── noise_gate.v                ← Envelope follower + smooth gain ramp
│   ├── distortion.v                ← Soft/hard clipping + tone IIR LPF
│   ├── overdrive.v                 ← Asymmetric soft-clip + dry/wet mix
│   ├── delay.v                     ← BRAM circular buffer, 65K sample
│   ├── reverb.v                    ← Schroeder: 4 comb + 2 all-pass
│   ├── chorus.v                    ← LFO-modulated delay, 2K BRAM
│   ├── tremolo.v                   ← Amplitude modulation via LFO
│   └── lfo.v                       ← Sine/Triangle/Square waveform generator
├── filters/
│   ├── fir_lowpass.v               ← 31-tap symmetric FIR (input anti-aliasing)
│   ├── biquad_filter.v             ← 2nd-order IIR Direct Form I
│   └── filter_coefficients.vh      ← Q2.14 format katsayılar
└── ui/
    ├── debouncer.v                  ← 10ms debounce + 2-stage sync + edge detect
    ├── seven_seg_controller.v       ← 8-digit multiplexed, ~1kHz refresh
    ├── vu_meter.v                   ← Peak hold 100ms, log-scale 8 LED
    └── parameter_controller.v       ← Buton-tabanlı parametre yönetimi
```

### Top-Level Port Listesi (top_guitar_processor.v)
```verilog
input  CLK100MHZ      // 100MHz sistem saati
input  CPU_RESETN     // Active-low reset
input  vauxp6, vauxn6 // XADC Aux Ch6 (differential analog input)
output AUD_PWM        // PWM audio çıkış → onboard amp
output AUD_SD         // Amp enable (active high, daima 1)
input  SW[15:0]       // SW[6:0]=efekt enable, SW[15:12]=volume
input  BTNC BTNU BTND BTNL BTNR  // Parametre kontrolü
output LED[15:0]      // VU meter (15:8=in, 7:0=out)
output AN[7:0]        // 7-seg anot (common anode, active low)
output SEG[6:0]       // 7-seg segment (active low)
output DP             // 7-seg decimal point
```

---

## 5. Her Modülün Ortak Arayüzü

Tüm DSP efekt modülleri aynı sinyal arayüzünü kullanır:

```verilog
module effect_name (
    input  wire               clk,         // 100 MHz sistem saati
    input  wire               rst,         // Senkron reset (active high)
    input  wire               sample_clk,  // 48 kHz strobe (1 cycle pulse)
    input  wire               bypass,      // 1=bypass (audio_in direkt geçer)
    input  wire signed [23:0] audio_in,    // Q1.23 signed audio input
    input  wire [7:0]         param1,      // Effect parameter 1
    input  wire [7:0]         param2,      // Effect parameter 2
    output reg  signed [23:0] audio_out,   // Q1.23 signed audio output
    output wire               ready        // (çoğunda sabit 1'b1)
);
```

**Kural:** `bypass=1` durumunda `audio_out <= audio_in` (her efekt bunu uygular)

---

## 6. Kritik Tasarım Kararları ve Gerekçeleri

### 6.1 XADC DRP (Dynamic Reconfiguration Port) Kullanımı
**Neden:** XADC'yi doğrudan kontrol etmek için DRP arayüzü seçildi.  
**State Machine:** IDLE → REQUEST → WAIT (drdy_out bekle) → DONE  
**Adres:** 0x16 = Aux Channel 6 veri registerı  
**Önemli:** XADC Wizard IP `xadc_wiz_0` olarak adlandırılmalı (top modülde bu isimle çağrılıyor)

### 6.2 Sigma-Delta DAC (Onboard PWM Amplifier için)
**Neden:** Basit PWM'e göre çok daha iyi SNR — gürültü şekillendirme (noise shaping).  
**Çalışma prensibi:** 2 adet entegratör + 1-bit quantizer. 100 MHz'de çalışır (≈2083x oversampling).  
**Klip:** Basit PWM sadece ~8-bit efektif çözünürlük verirken Sigma-Delta ~14 ENOB sağlar.  
**Kritik:** `pdm_out` sinyali doğrudan AUD_PWM'e gider, harici filtre gerekmez (onboard amp filtreler).

### 6.3 TPDF Dithering
**Neden:** Bit derinliği azaltmada sinyal-korelasyonlu distorsiyonu önler.  
**Implementasyon:** İki ayrı LFSR (farklı seed) çıkışının toplamı → triangular PDF.  
**Yerleşim:** Sigma-Delta DAC'tan ÖNCE uygulanır.

### 6.4 Reverb: Schroeder Algoritması
**Neden:** Klasik, kaynak-verimli RT60 reverb.  
**Yapı:** 4 paralel comb filtre → toplanır (÷4) → 2 seri all-pass filtre  
**Comb gecikmeleri (birbirine asal):** 1687, 1601, 2053, 2251 sample  
**All-pass gecikmeleri:** 347, 113 sample  
**BRAM kullanımı:** ~16 KB (COMB: 4×~1800×3B, AP: ~460×3B)  
**Feedback gain:** 0.5 + decay × 0.45/255 (range: 0.5–0.95, kararsızlık önlendi)

### 6.5 Delay: BRAM Circular Buffer
**Neden:** 65K sample × 24-bit = ~192 KB → BRAM zorunlu (distributed RAM yetersiz)  
**Özellik:** LP-filtered feedback loop (delay'in doğal decay simülasyonu için)  
**Max feedback:** 230/256 ≈ 90% (runaway oscilation önleme)

### 6.6 Asimetrik Clipping (Overdrive)
**Neden:** Tüp amplifikatör karakteri için 2. harmonik baskınlığı.  
**Pozitif yarım:** y = x - x²/4 (daha yumuşak)  
**Negatif yarım:** y = x + x²/2 (daha sert)  
**Sonuç:** Even-order harmonics → "warm" tube sound

### 6.7 Soft Clipping Yaklaşımı (Distortion)
**Transfer fonksiyonu:** y = x - x³/3  
**x³/3 approximation:** x³>>2 + x³>>4 + x³>>6 ≈ 0.328x³ (0.333 yerine, düşük resource)

### 6.8 FIR Filtre Optimizasyonu
**Teknik:** Simetrik FIR (Type I) → pre-add optimizasyonu.  
**Tasarruf:** 31 çarpma yerine 16 çarpma (simetri exploitasyonu)  
**Pipeline:** IDLE → SHIFT → MAC (15 cycle) → CENTER → OUTPUT

### 6.9 DC Blocking Filter
**Transfer:** H(z) = (1 - z⁻¹) / (1 - α·z⁻¹), α = 0.995  
**Uygulama:** y[n] = x[n] - x[n-1] + α·y[n-1]  
**fc:** ~3.8 Hz @ 48 kHz (DC'yi temizler, hiçbir ses frekansını kesmez)  
**Kaynak:** `dc_blocking_filter.v`

### 6.10 LFO Tasarımı
**Phase accumulator:** 24-bit, her sample_clk'ta `increment` eklenir  
**Rate hesabı:** increment = 35 + rate × 20 (rate=0 → 0.1Hz, rate=255 → ~15Hz)  
**Waveform:** phase[23:16] = 8-bit phase → sine_lut → quarter-wave symmetry ile tam sinüs

---

## 7. Gürültü Azaltma Stratejisi (Özet)

| Katman | Teknik | Modül |
|---|---|---|
| Analog | TL072 buffer, 1MΩ impedance match, RC LPF | Harici devre |
| Dijital giriş | DC blocking IIR HPF, FIR anti-aliasing LPF | `dc_blocking_filter.v`, `fir_lowpass.v` |
| DSP | 24-bit Q1.23, 48-bit intermediates, saturation guard | Tüm DSP |
| Gürültü kapısı | Envelope follower, smooth gain ramp | `noise_gate.v` |
| Çıkış | TPDF dithering → 2nd order Sigma-Delta | `dithering.v`, `sigma_delta_dac.v` |
| Meta-kararlılık | 2-stage flip-flop synchronizer (tüm async inputs) | `debouncer.v` |
| Taşma | Her aşamada satürasyon: `SATURATE32()` / `SATURATE48()` makroları | `fixed_point_math.vh` |

---

## 8. Pin Atamaları (Kritik Olanlar)

```xdc
CLK100MHZ    → E3   (100MHz oscillator)
CPU_RESETN   → C12  (active-low reset button)
vauxp6       → A13  (JXADC pin 1, XADC Aux Ch6+)
vauxn6       → A14  (JXADC pin 2, XADC Aux Ch6-)
AUD_PWM      → A11  (Onboard audio amplifier PWM input)
AUD_SD       → D12  (Onboard audio amplifier shutdown, drive HIGH to enable)
```

Tüm pinler `constraints/nexys_a7_100t.xdc` dosyasında tanımlıdır.

---

## 9. XADC IP Üretim Ayarları (Vivado 2025.1)

Sentez yapılmadan önce bu IP Vivado'da elle üretilmeli:

```
IP Catalog → XADC Wizard
  Component Name: xadc_wiz_0     ← Bu isim değiştirilmemeli!
  Interface:      DRP
  Timing Mode:    Continuous
  Channel Sequencer:
    - VAUXP6/VAUXN6: ENABLED
    - Diğerleri: deaktif
  ADC Setup:
    - Averaging: None (latency minimizasyonu)
    - Acquisition: Simultaneous
  Alarms:
    - Tüm alarmlar: DISABLED
```

---

## 10. SW/Button Eşlemesi (run-time kontrol)

```
SW[0]   → Noise Gate enable
SW[1]   → Distortion enable
SW[2]   → Overdrive enable
SW[3]   → Delay enable
SW[4]   → Reverb enable
SW[5]   → Chorus enable
SW[6]   → Tremolo enable
SW[7]   → (Rezerv, bağlı değil)
SW[11:8]→ (Rezerv, genişleme için)
SW[15:12]→ Master Volume (4-bit, 0=mute → 15=max)

BTNC    → Efekt seçimi döngüsü (parametre düzenleme için)
BTNU    → Seçili efekt, Param1++ 
BTND    → Seçili efekt, Param1--
BTNR    → Seçili efekt, Param2++
BTNL    → Seçili efekt, Param2--
```

**Debounce:** Her buton için 2-stage synchronizer + 10ms (1M cycle) debounce sayacı + rising-edge pulse detect uygulanmıştır.

**7-Segment:** Sol 4 hane = efekt adı (GAtE/dISt/oUdr/dELy/rEUb/CHor/trEn), Sağ 3 hane = 0-255 parametre değeri. DP (nokta) = efekt SW ile aktifse yanar.

---

## 11. FPGA Kaynak Tahmini

| Kaynak | Tahmini | Mevcut | Kullanım |
|---|---|---|---|
| LUT6 | 8,000 | 63,400 | ~13% |
| Flip-Flop | 4,000 | 126,800 | ~3% |
| BRAM 36Kb | 20 | 135 | ~15% |
| DSP48E1 | 12 | 240 | ~5% |
| XADC | 1 | 1 | 100% |
| MMCM/PLL | 0 | 6 | 0% |

---

## 12. Gelecekteki Geliştirme Önerileri

### Yüksek Öncelikli
- [ ] **Pmod I2S2 desteği** — Kart alınırsa 24-bit/96kHz kalite sağlar. `xadc_interface.v` yerine yeni `i2s_receiver.v` ve `i2s_transmitter.v` eklenmeli. CS5343 (ADC) + CS4344 (DAC) codec chip'leri için I2S protokolü implement edilmeli.
- [ ] **Wah-Wah efekti** — Biquad bandpass filtre + LFO. `biquad_filter.v` zaten var, sadece yeni `wah.v` modülü gerekli.
- [ ] **Octave efekti** — Sinyal doğrultma (rectify) + LPF ile alt oktav; pitch shift DSP ile üst oktav.

### Orta Öncelikli
- [ ] **Parametrik EQ** — 3 bant (bass/mid/treble) biquad filtre, sweep-able center frequency. `biquad_filter.v` yeniden kullanılabilir.
- [ ] **Compressor/Limiter** — Envelope follower (zaten `noise_gate.v`'de var) + gain reduction.
- [ ] **Flanger** — Chorus gibi ama çok kısa delay (0.5-5ms) + negatif feedback. `chorus.v` base alınabilir.
- [ ] **Pitch Shifter** — FFT tabanlı veya granular synthesis. Karmaşık, BRAM yoğun.
- [ ] **UART/USB MIDI** — Parametreleri MIDI kontrolörden almak için.

### Düşük Öncelikli
- [ ] **Preset sistemi** — Block RAM'e 8 preset kaydedip recall etmek (BTNC long-press ile).
- [ ] **Tap Tempo** — Delay süresini BTNC double-tap ile ayarlamak.
- [ ] **Stereo Çıkış** — Pmod DA2 veya ikinci PWM kanalı ile stereo chorus/reverb.
- [ ] **VGA Spektrum Analizörü** — Onboard VGA konnektörü üzerinden gerçek zamanlı FFT görüntüsü.
- [ ] **AXI SmartConnect + MicroBlaze** — Soft-core CPU ile dinamik parametre yönetimi.

---

## 13. Bilinen Sınırlılıklar ve Hatalar

1. **XADC Gürültüsü:** XADC, audiophile kalitesi için tasarlanmamıştır. 12-bit ADC'nin ENOB'u gerçekte ~9-10 bit düzeyindedir. Pmod I2S2 bu sorunu tamamen çözer.

2. **PWM Amplifier Frekansı:** Onboard amplifiyerin PWM giriş frekansı sınırlıdır. Sigma-Delta modülatör 100 MHz'de çalışır ama amp filtresi bu konusunda kısıt getirebilir.

3. **Reverb BRAM:** Şu anki Schroeder comb filtre boyutları sabit kodlanmış (hardcoded). Değiştirmek istiyorsanız `reverb.v`'deki `localparam` satırlarını düzenleyin:  
   ```verilog
   localparam COMB1_LEN = 1687;  // Birbirine asal olmalı!
   localparam COMB2_LEN = 1601;
   localparam COMB3_LEN = 2053;
   localparam COMB4_LEN = 2251;
   ```

4. **FIR Latency:** 31-tap FIR filtresi pipeline yapısında ~35 clock cycle latency ekler. Gerçek zamanlı kullanım için kabul edilebilir, ama latency-sensitive uygulamalarda bypass eklenebilir.

5. **tek Analog Kanal:** XADC'de sadece Aux Channel 6 kullanılıyor. İkinci kanal eklemek için `xadc_interface.v`'deki state machine ve channel sequencer güncellenmelidir.

---

## 14. Test Prosedürü

### Simülasyon (Vivado Simulator)
```
sim/tb_distortion.v  → Soft/hard clip doğrulama, sine input
sim/tb_delay.v       → Impulse response (echo visible), bypass test
sim/tb_top.v         → Entegrasyon testi, tüm efektler sırayla aktif
```

### Hardware Doğrulama Adımları
1. XADC gümüzşü toprak hattına osilloskop bağla, sessiz input → gürültü ölç
2. Gitar tak, tüm SW=0 (bypass) → çıkış orijinal sinyale yakın mı kontrol et
3. SW[1]=1 (distortion) → dalga şekli clipping görünmeli (osilloskop)
4. SW[3]=1 (delay) → echo duyulmalı, SW[3]=0 anında kayboluyor mu?
5. LED VU meter → gitar çalarken seviyeye göre LED'ler artmalı

---

## 15. Kod Stil Kuralları

- **Modül başlığı:** Her dosyanın en üstünde `//===` blok yorum (name, açıklama, kritik notlar)
- **Sinyal adlandırma:** `snake_case`, input = `in_xxx`, output = `out_xxx` değil → doğrudan `audio_in`/`audio_out`  
- **Parametreler:** `localparam` kullan (genelleme gerektirmedikçe `parameter` değil)
- **Satürasyon:** Tüm çarpma ve toplama sonuçları `SATURATE` / `SATURATE32` / `SATURATE48` ile kontrol edilmeli
- **Reset:** Tüm modüller **senkron** reset kullanır (`if (rst)`)
- **Saat domain:** Tek saat alanı (100 MHz `CLK100MHZ`), `sample_clk` bir enable sinyalidir (clock değil)
- **BRAM inferans:** `(* ram_style = "block" *)` attribute'u büyük belleklerde zorunlu
- **Fixed-point:** Çarpma sonucu her zaman `48-bit signed`, sonra doğru biti alarak scale edilir

---

## 16. Derleme Sırası (Vivado Source Bağımlılıkları)

Vivado kaynak ekleme sırası önemli değil (IP sentez sırasını kendisi çözüyor),
ama mantıksal bağımlılık şöyledir:

```
Level 0 (yaprak):  fixed_point_math.vh, filter_coefficients.vh
Level 1:           lfsr.v, sine_lut.v, biquad_filter.v, fir_lowpass.v
Level 2:           lfo.v (sine_lut bağımlı)
Level 3:           noise_gate.v, distortion.v, overdrive.v, delay.v,
                   reverb.v, chorus.v (lfo bağımlı), tremolo.v (lfo bağımlı)
Level 4:           effects_chain.v (tüm efektler bağımlı)
Level 5:           xadc_interface.v (xadc_wiz_0 IP bağımlı)
                   dc_blocking_filter.v, sigma_delta_dac.v, dithering.v (lfsr bağımlı)
                   debouncer.v, seven_seg_controller.v, vu_meter.v, parameter_controller.v
Level 6 (root):    top_guitar_processor.v (hepsi bağımlı)
```

---

*Son güncelleme: 2026-04-16 — İlk tam implementasyon tamamlandı (30 dosya, 7 efekt, seri zincir)*
