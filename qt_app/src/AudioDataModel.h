#ifndef AUDIODATAMODEL_H
#define AUDIODATAMODEL_H

#include <QObject>
#include <QMutex>
#include <QVector>
#include <cstring>

// Thread-safe ring buffer for audio samples
class AudioRingBuffer {
public:
    AudioRingBuffer(int capacity = 2048)
        : m_capacity(capacity), m_head(0), m_count(0)
    {
        m_buffer.resize(capacity, 0.0);
    }

    void push(double value) {
        QMutexLocker lock(&m_mutex);
        m_buffer[m_head] = value;
        m_head = (m_head + 1) % m_capacity;
        if (m_count < m_capacity) m_count++;
    }

    QVector<double> getLastN(int n) const {
        QMutexLocker lock(&m_mutex);
        QVector<double> result(n, 0.0);
        int available = qMin(n, m_count);
        int start = (m_head - available + m_capacity) % m_capacity;
        for (int i = 0; i < available; i++) {
            result[i] = m_buffer[(start + i) % m_capacity];
        }
        return result;
    }

    int count() const { QMutexLocker lock(&m_mutex); return m_count; }

private:
    QVector<double> m_buffer;
    int m_capacity;
    int m_head;
    int m_count;
    mutable QMutex m_mutex;
};

// Data model holding all state received from FPGA
class AudioDataModel : public QObject {
    Q_OBJECT
public:
    explicit AudioDataModel(QObject *parent = nullptr);

    // Ring buffers for waveform display
    AudioRingBuffer inputBuffer;
    AudioRingBuffer outputBuffer;

    // Current state
    double vuIn() const { return m_vuIn; }
    double vuOut() const { return m_vuOut; }
    quint8 effectEnables() const { return m_effectEnables; }
    quint8 selectedEffect() const { return m_selectedEffect; }
    quint8 param1() const { return m_param1; }
    quint8 param2() const { return m_param2; }
    quint8 masterVolume() const { return m_masterVolume; }
    int packetRate() const { return m_packetRate; }

    // Process incoming packet (16 bytes)
    void processPacket(const QByteArray &packet);

signals:
    void dataUpdated();
    void statusUpdated();

private:
    double m_vuIn = 0;
    double m_vuOut = 0;
    quint8 m_effectEnables = 0;
    quint8 m_selectedEffect = 0;
    quint8 m_param1 = 0;
    quint8 m_param2 = 0;
    quint8 m_masterVolume = 0;

    // Packet rate measurement
    int m_packetCount = 0;
    int m_packetRate = 0;
    qint64 m_lastRateTime = 0;
};

#endif // AUDIODATAMODEL_H
