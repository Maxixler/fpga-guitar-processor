# Analog Ön Devre Şeması — Gitar → XADC Arayüzü

Elektro gitar sinyalini Nexys A7-T100 FPGA kartının XADC girişine güvenli şekilde bağlamak için gereken analog ön devre.

## ⚠️ Önemli Uyarılar

> XADC girişi **0V – 1V** aralığında çalışır. Bu aralığın dışına çıkmak FPGA'yı kalıcı olarak hasar verebilir!

> Gitar sinyalini **asla doğrudan** XADC'ye bağlamayın.

---

## Devre Blok Diyagramı

```
┌─────────┐    ┌──────────────┐    ┌──────────┐    ┌────────────┐    ┌──────────┐
│  Gitar  │───→│ Empedans     │───→│ DC Bias  │───→│ Anti-Alias │───→│  XADC    │
│  Jack   │    │ Tamponu      │    │ 0.5V     │    │ LPF 20kHz  │    │ Aux Ch6  │
│         │    │ (Op-Amp)     │    │ Offset   │    │ (2.derece) │    │ (JXADC)  │
└─────────┘    └──────────────┘    └──────────┘    └────────────┘    └──────────┘
```

---

## Detaylı Devre Şeması

```
                    +5V (VCC)
                      │
                      ├──[10kΩ]──┐
                      │          │      TL072 (A)
    Gitar          [100kΩ]     VBIAS    ┌────────┐
    Jack             │          │    ┌──┤2  -    │
     ○──[10nF]──┬────┘      ┌──┴────┤  │    1   ├──┬──[1kΩ]──┬──→ VAUXP6
     │   (C1)   │           │  │    └──┤3  +    │  │         │    (JXADC)
     │       [1MΩ]  (R1)    │  │       └────────┘  │     [680pF]
   [GND]        │           │ [10kΩ]    (U1A)      │     (C3)  ├──→ VAUXN6
                ├───────────┘    │                  │         │    (JXADC)
              [GND]            [GND]             [3.3kΩ]    [GND]
                                                   │
                                                [680pF]
                                                (C4)  │
                                                   │
                                                 [GND]

    ┌─── Sanal Toprak (VBIAS = 0.5V) ───┐
    │                                     │
    │  +5V ──[10kΩ]──┬──[10kΩ]── GND    │
    │                │                    │
    │             [100µF]                 │
    │                │                    │
    │              [GND]                  │
    │         VBIAS = 0.5V                │
    └─────────────────────────────────────┘
```

---

## Malzeme Listesi (BOM)

| No | Bileşen | Değer | Paket | Açıklama |
|---|---|---|---|---|
| U1 | TL072 | - | DIP-8 | Düşük gürültü JFET op-amp |
| R1 | Direnç | 1 MΩ | 1/4W | Gitar empedans eşleşme |
| R2, R3 | Direnç | 10 kΩ | 1/4W | DC bias voltaj bölücü |
| R4 | Direnç | 100 kΩ | 1/4W | Giriş akım sınırlama |
| R5 | Direnç | 1 kΩ | 1/4W | Anti-aliasing filtre (LPF) |
| R6 | Direnç | 3.3 kΩ | 1/4W | 2. kademe LPF |
| C1 | Kapasitör | 10 nF | Seramik | Giriş DC blokaj |
| C2 | Kapasitör | 100 µF | Elektrolitik | Bias stabilizasyon |
| C3, C4 | Kapasitör | 680 pF | Seramik | Anti-aliasing (fc ≈ 20 kHz) |

### Güç Kaynağı
| Bileşen | Açıklama |
|---|---|
| 9V Pil veya 5V USB | Ana güç kaynağı |
| 7805 Regülatör | 5V regülasyon (9V pil kullanılıyorsa) |

---

## Hesaplamalar

### 1. Empedans Tamponu
- **Giriş empedansı**: 1 MΩ (R1) — Gitar pickupları genellikle 5-15 kΩ, bu yüzden 1 MΩ yeterli
- **Op-amp**: TL072 JFET girişli, giriş akımı < 50 pA
- **Kazanç**: 1x (unity gain, voltage follower)

### 2. DC Bias (0.5V)
- **Voltaj bölücü**: R2 = R3 = 10 kΩ → VBIAS = VCC/2 = 2.5V (5V ile) 
- **Amaç**: Kartın XADC'si 0-1V aralığında çalışır
- **Ölçekleme** Op-amp çıkışı ±500mV civarında salınır, 0.5V DC bias ile 0V-1V aralığına oturur
- **Not**: VCC = 1V kullanarak VBIAS = 0.5V elde edilir VEYA harici referans

> **Önemli**: XADC 0-1V aralığında çalıştığı için, voltaj bölücüyü 0.5V'a ayarlamanız gerekir. Bunun için:
> - 5V beslemeden 10kΩ + 10kΩ yerine daha hassas bir bölücü kullanın
> - VEYA bir voltaj referans IC kullanın (örn: TL431 0.5V'a ayarlanmış)

### 3. Anti-Aliasing Filtresi
- **Kesim frekansı**: fc = 1 / (2π × RC)
- R5 = 1 kΩ, C3 = 680 pF → fc = 1 / (2π × 1000 × 680e-12) ≈ **234 kHz** (1. kademe)
- R6 = 3.3 kΩ, C4 = 680 pF → fc = 1 / (2π × 3300 × 680e-12) ≈ **71 kHz** (2. kademe)
- **Aktif filtre tercih edilebilir**: 2. derece Sallen-Key LPF, fc = 20 kHz

### Alternatif: Sallen-Key 20 kHz LPF

```
                R=3.9kΩ     R=3.9kΩ
Op-amp çıkışı ──[R]────┬───[R]────┬──→ XADC
                        │          │
                     [2.2nF]    [2.2nF]
                        │          │
                      [GND]    Op-amp (+)
                                   │
                               Op-amp çıkış ──→ XADC
```

fc = 1 / (2π × R × C) = 1 / (2π × 3900 × 2.2e-9) ≈ **18.6 kHz** ✓

---

## JXADC Header Bağlantısı (Nexys A7)

```
JXADC Header Pinout:
┌─────────────────┐
│ Pin 1 (VAUXP6)  │ ←── Analog sinyal (+)
│ Pin 2 (VAUXN6)  │ ←── GND (single-ended için)
│ Pin 3 (GND)     │ ←── Toprak
│ Pin 4 (VCC)     │ ←── (Kullanılmıyor)
│ ...              │
└─────────────────┘
```

> **Single-ended mod**: VAUXN6'yı GND'ye bağlayın, sinyali VAUXP6'ya verin.

---

## Gürültü Azaltma İpuçları

1. **Kısa kablolar kullanın** — Analog sinyal hatları mümkün olduğunca kısa olmalı
2. **Korumalı kablo** — Gitar kablosu ve analog devre arası bağlantıda korumalı kablo kullanın
3. **Toprak döngüsünden kaçının** — Tek nokta topraklama (star ground) uygulayın
4. **Bypass kapasitörleri** — Op-amp güç pinlerine 100 nF seramik kapasitör koyun
5. **Ayrı güç kaynağı** — Analog devre için ayrı, temiz güç kaynağı kullanın (9V pil ideal)
6. **Ferrite bead** — FPGA ve analog devre arası güç hattına ferrite bead koyun
