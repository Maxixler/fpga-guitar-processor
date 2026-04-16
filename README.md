# FPGA Gitar Efekt Prosesörü — Nexys A7-T100

<p align="center">
  <strong>Gerçek zamanlı, düşük gecikmeli, minimum gürültülü dijital gitar efekt prosesörü</strong>
</p>

---

## 🎸 Proje Özeti

Bu proje, Digilent Nexys A7-T100 (Artix-7 XC7A100T) FPGA kartı üzerinde çalışan bir elektro gitar efekt prosesörüdür. Gitar sinyali XADC ile dijitalleştirilir, FPGA içinde gerçek zamanlı olarak işlenir ve PWM çıkış üzerinden ampli veya kulaklığa gönderilir.

### Özellikler

| Özellik | Değer |
|---|---|
| Dahili İşleme | 24-bit sabit nokta (Q1.23) |
| Örnekleme Hızı | 48 kHz |
| Gecikme | < 1 ms (uçtan uca) |
| Efekt Sayısı | 7 efekt + Noise Gate |
| Efekt Zinciri | Seri bağlama (eş zamanlı) |
| Kontrol | 16 switch + 5 buton + 7-segment display |
| Ses Çıkışı | Sigma-Delta DAC (~14-bit ENOB) |

### Efektler

| # | Efekt | Açıklama | Parametre 1 | Parametre 2 |
|---|---|---|---|---|
| 0 | **Noise Gate** | Gürültü kapısı | Eşik (Threshold) | - |
| 1 | **Distortion** | Hard/Soft clipping | Gain | Tone |
| 2 | **Overdrive** | Tüp amfi emülasyonu | Drive | Mix |
| 3 | **Delay** | Dijital echo (~1.36s max) | Time | Feedback |
| 4 | **Reverb** | Schroeder reverberatör | Decay | Mix |
| 5 | **Chorus** | LFO modülasyonlu | Rate | Depth |
| 6 | **Tremolo** | Amplitüd modülasyonu | Rate | Depth |

---

## 🔧 Donanım Gereksinimleri

### Ana Kart
- **Digilent Nexys A7-T100** (veya Nexys A7-T50)

### Harici Devre (Analog Ön Devre)
Gitar sinyalini XADC girişine uygun hale getirmek için basit bir analog devre gereklidir:

| Bileşen | Değer | Amaç |
|---|---|---|
| TL072 Op-Amp | DIP-8 | Empedans tamponu |
| 1 MΩ direnç | 1/4W | Gitar empedans eşleşme |
| 10 kΩ dirençler (×2) | 1/4W | DC bias voltaj bölücü |
| 680 pF kapasitörler (×2) | Seramik | Anti-aliasing filtre |
| 100 µF kapasitör | Elektrolitik | Bias stabilizasyon |
| 10 nF kapasitör | Seramik | DC blokaj |
| Breadboard | - | Prototipleme |
| 6.35mm Jack | Mono | Gitar girişi |

> 📋 Detaylı devre şeması: [`docs/analog_frontend_schematic.md`](docs/analog_frontend_schematic.md)

### Ek Gerekenler
- 6.35mm → 3.5mm jack adaptörü (veya direkt bağlantı)
- Kulaklık veya küçük amplifikatör (çıkış için)
- Jumper kablolar (JXADC header bağlantısı için)

---

## 📁 Proje Yapısı

```
Prosesör/
├── src/
│   ├── top_guitar_processor.v          # Üst seviye modül
│   ├── audio_input/
│   │   ├── xadc_interface.v            # XADC sürücüsü
│   │   └── dc_blocking_filter.v        # DC bloklama filtresi
│   ├── audio_output/
│   │   ├── sigma_delta_dac.v           # Sigma-Delta DAC
│   │   └── dithering.v                 # TPDF dithering
│   ├── dsp/
│   │   ├── effects_chain.v             # Seri efekt zinciri
│   │   ├── noise_gate.v                # Gürültü kapısı
│   │   ├── distortion.v                # Distortion
│   │   ├── overdrive.v                 # Overdrive
│   │   ├── delay.v                     # Delay/Echo
│   │   ├── reverb.v                    # Reverb
│   │   ├── chorus.v                    # Chorus
│   │   ├── tremolo.v                   # Tremolo
│   │   └── lfo.v                       # LFO osilatör
│   ├── filters/
│   │   ├── fir_lowpass.v               # FIR alçak geçiren
│   │   ├── biquad_filter.v             # IIR biquad filtre
│   │   └── filter_coefficients.vh      # Filtre katsayıları
│   ├── ui/
│   │   ├── debouncer.v                 # Buton debounce
│   │   ├── seven_seg_controller.v      # 7-segment sürücü
│   │   ├── vu_meter.v                  # LED VU meter
│   │   └── parameter_controller.v      # Parametre kontrolü
│   └── utils/
│       ├── fixed_point_math.vh         # Sabit nokta makrolar
│       ├── lfsr.v                      # PRNG
│       └── sine_lut.v                  # Sinüs tablosu
├── constraints/
│   └── nexys_a7_100t.xdc              # Pin atamaları
├── sim/
│   ├── tb_top.v                        # Üst seviye testbench
│   ├── tb_distortion.v                 # Distortion testbench
│   └── tb_delay.v                      # Delay testbench
├── docs/
│   └── analog_frontend_schematic.md    # Ön devre şeması
└── README.md
```

---

## 🚀 Kurulum ve Derleme

### Gereksinimler
- **AMD Vivado 2025.1** (veya uyumlu sürüm)
- **Nexys A7-T100** FPGA kartı
- USB kablosu (programlama için)

### Adım 1: Vivado Projesi Oluşturma

1. Vivado'yu açın
2. **Create Project** → Proje adı: `guitar_processor`
3. Proje konumu: Bu dizin
4. **RTL Project** seçin
5. **Add Sources**: `src/` altındaki tüm `.v` ve `.vh` dosyalarını ekleyin
6. **Add Constraints**: `constraints/nexys_a7_100t.xdc` dosyasını ekleyin
7. **Default Part**: `xc7a100tcsg324-1` seçin (Nexys A7-100T)

### Adım 2: XADC IP Çekirdeği Oluşturma

1. **IP Catalog** → "XADC Wizard" arayın
2. Ayarlar:
   - **Component Name**: `xadc_wiz_0`
   - **Interface**: DRP
   - **Timing Mode**: Continuous
   - **Startup Channel**: Channel Sequencer
   - **Channel Sequencer**: Aux Channel 6 (VAUXP6/VAUXN6) etkinleştirin
   - **ADC Setup**: Averaging = None
   - **Alarms**: Tüm alarmları devre dışı bırakın
3. **Generate** butonuna tıklayın

### Adım 3: Sentez ve Uygulama

```
1. Run Synthesis
2. Run Implementation
3. Generate Bitstream
4. Program Device (Hardware Manager)
```

### Adım 4: Donanım Bağlantıları

1. Analog ön devreyi kurun ([şema](docs/analog_frontend_schematic.md))
2. Devre çıkışını JXADC header'a bağlayın (VAUXP6, VAUXN6, GND)
3. Kulaklık veya ampliyi audio jack çıkışına bağlayın
4. Gitarı analog devre girişine bağlayın

---

## 🎛️ Kullanım Kılavuzu

### Switch Eşlemesi (SW[15:0])

| Switch | Fonksiyon |
|---|---|
| SW[0] | Noise Gate ON/OFF |
| SW[1] | Distortion ON/OFF |
| SW[2] | Overdrive ON/OFF |
| SW[3] | Delay ON/OFF |
| SW[4] | Reverb ON/OFF |
| SW[5] | Chorus ON/OFF |
| SW[6] | Tremolo ON/OFF |
| SW[7] | Rezerv |
| SW[11:8] | (Kullanılmıyor, genişleme için) |
| SW[15:12] | Master Volume (0=sessiz, 15=maks) |

### Buton Kontrolleri

| Buton | Fonksiyon |
|---|---|
| BTNC | Efekt seçimi (parametre düzenleme için) |
| BTNU | Parametre 1 artır |
| BTND | Parametre 1 azalt |
| BTNR | Parametre 2 artır |
| BTNL | Parametre 2 azalt |

### 7-Segment Display
- **Sol 4 hane**: Seçili efekt adı (GAtE, dISt, oUdr, dELy, rEUb, CHor, trEn)
- **Sağ 3 hane**: Parametre değeri (0-255)
- **Nokta (DP)**: Efekt aktifse yanar

### LED VU Meter
- **LED[15:8]**: Giriş seviyesi (8 LED bar)
- **LED[7:0]**: Çıkış seviyesi (8 LED bar)

---

## 🔇 Gürültü Azaltma Teknikleri

Bu projede minimum gürültü için uygulanan teknikler:

1. **24-bit dahili işleme** — 12-bit ADC çıkışı 24-bit'e genişletilir, tüm ara hesaplamalar 48-bit'e kadar çıkar
2. **TPDF Dithering** — Bit derinliği azaltmada sinyal-korelasyonlu distorsiyonu önler
3. **Sigma-Delta DAC** — 100 MHz'de çalışan 2. derece modülatör, gürültüyü ses bandı dışına atar
4. **DC Blocking Filter** — ADC bias kaynaklı DC offset'i temizler (3.8 Hz yüksek geçiren)
5. **Noise Gate** — Sinyal yokken gürültüyü tamamen susturur (yumuşak geçişle)
6. **FIR Anti-Aliasing** — 31 basamaklı dijital alçak geçiren filtre
7. **Sabit nokta taşma koruması** — Her aritmetik işlemde satürasyon kontrolü
8. **Geri besleme sınırlama** — Delay/Reverb feedback ≤ %90 (kararsızlık önleme)
9. **Saat senkronizasyonu** — Tüm switch/buton girişlerinde 2-aşamalı senkronizör
10. **Analog ön devre** — Empedans eşleşme, anti-aliasing, DC bias

---

## 📊 FPGA Kaynak Kullanımı (Tahmini)

| Kaynak | Kullanım | Mevcut (XC7A100T) | Oran |
|---|---|---|---|
| LUT | ~8,000 | 63,400 | ~13% |
| FF | ~4,000 | 126,800 | ~3% |
| BRAM (36Kb) | ~20 | 135 | ~15% |
| DSP48 | ~12 | 240 | ~5% |
| XADC | 1 | 1 | 100% |

---

## 📜 Lisans

Bu proje eğitim amaçlıdır. Kişisel kullanım ve modifikasyon serbesttir.

---

## 🙏 Referanslar

- [Digilent Nexys A7 Reference Manual](https://digilent.com/reference/programmable-logic/nexys-a7/start)
- [Xilinx 7 Series XADC User Guide (UG480)](https://docs.amd.com/v/u/en-US/ug480_7Series_XADC)
- [Schroeder Reverberator Algorithm](https://ccrma.stanford.edu/~jos/pasp/Schroeder_Reverberators.html)
- [FPGA Guitar Pedal Projects](https://github.com/carsonrobles/fpga-guitar-pedal)
