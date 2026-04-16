#include "AudioDataModel.h"
#include <QDateTime>

AudioDataModel::AudioDataModel(QObject *parent)
    : QObject(parent)
    , inputBuffer(2048)
    , outputBuffer(2048)
    , m_lastRateTime(QDateTime::currentMSecsSinceEpoch())
{
}

void AudioDataModel::processPacket(const QByteArray &packet)
{
    if (packet.size() < 16) return;

    const quint8 *data = reinterpret_cast<const quint8*>(packet.constData());

    // Verify sync byte
    if (data[0] != 0xAA) return;

    // Verify checksum
    quint8 checksum = 0;
    for (int i = 0; i < 15; i++)
        checksum ^= data[i];
    if (checksum != data[15]) return;

    // Parse audio samples (24-bit signed → double -1.0 to 1.0)
    int32_t rawIn  = (static_cast<int32_t>(data[2]) << 16) | 
                     (static_cast<int32_t>(data[3]) << 8)  | 
                      static_cast<int32_t>(data[4]);
    int32_t rawOut = (static_cast<int32_t>(data[5]) << 16) | 
                     (static_cast<int32_t>(data[6]) << 8)  | 
                      static_cast<int32_t>(data[7]);

    // Sign extension for 24-bit signed values
    if (rawIn  & 0x800000) rawIn  |= 0xFF000000;
    if (rawOut & 0x800000) rawOut |= 0xFF000000;

    double audioIn  = static_cast<double>(rawIn)  / 8388608.0;  // 2^23
    double audioOut = static_cast<double>(rawOut) / 8388608.0;

    inputBuffer.push(audioIn);
    outputBuffer.push(audioOut);

    // Parse status
    m_vuIn           = static_cast<double>(data[8])  / 255.0;
    m_vuOut          = static_cast<double>(data[9])  / 255.0;
    m_effectEnables  = data[10];
    m_selectedEffect = data[11];
    m_param1         = data[12];
    m_param2         = data[13];
    m_masterVolume   = data[14];

    // Packet rate measurement
    m_packetCount++;
    qint64 now = QDateTime::currentMSecsSinceEpoch();
    if (now - m_lastRateTime >= 1000) {
        m_packetRate = m_packetCount;
        m_packetCount = 0;
        m_lastRateTime = now;
        emit statusUpdated();
    }

    emit dataUpdated();
}
