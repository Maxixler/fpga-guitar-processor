/*
 * Minimal FFT implementation for audio spectrum analysis.
 * Radix-2 Decimation-In-Time (DIT) FFT.
 * Only power-of-2 sizes supported.
 */
#ifndef SIMPLE_FFT_H
#define SIMPLE_FFT_H

#include <cmath>
#include <complex>
#include <vector>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

namespace SimpleFFT {

using Complex = std::complex<double>;

inline void fft(std::vector<Complex>& data) {
    int N = static_cast<int>(data.size());
    if (N <= 1) return;

    // Bit-reversal permutation
    for (int i = 1, j = 0; i < N; i++) {
        int bit = N >> 1;
        for (; j & bit; bit >>= 1) {
            j ^= bit;
        }
        j ^= bit;
        if (i < j) std::swap(data[i], data[j]);
    }

    // Cooley-Tukey butterfly
    for (int len = 2; len <= N; len <<= 1) {
        double angle = -2.0 * M_PI / len;
        Complex wlen(cos(angle), sin(angle));
        for (int i = 0; i < N; i += len) {
            Complex w(1.0, 0.0);
            for (int j = 0; j < len / 2; j++) {
                Complex u = data[i + j];
                Complex v = data[i + j + len / 2] * w;
                data[i + j] = u + v;
                data[i + j + len / 2] = u - v;
                w *= wlen;
            }
        }
    }
}

// Compute magnitude spectrum in dB from real input
inline std::vector<double> magnitudeDB(const std::vector<double>& input, int fftSize) {
    std::vector<Complex> data(fftSize);

    // Apply Hann window
    for (int i = 0; i < fftSize && i < static_cast<int>(input.size()); i++) {
        double window = 0.5 * (1.0 - cos(2.0 * M_PI * i / (fftSize - 1)));
        data[i] = Complex(input[i] * window, 0.0);
    }

    fft(data);

    // Only positive frequencies
    int halfN = fftSize / 2;
    std::vector<double> mag(halfN);
    for (int i = 0; i < halfN; i++) {
        double m = std::abs(data[i]) / fftSize;
        mag[i] = (m > 1e-10) ? 20.0 * log10(m) : -100.0;
    }
    return mag;
}

} // namespace SimpleFFT

#endif // SIMPLE_FFT_H
