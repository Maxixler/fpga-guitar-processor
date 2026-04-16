#ifndef SERIALMANAGER_H
#define SERIALMANAGER_H

#include <QObject>
#include <QSerialPort>
#include <QSerialPortInfo>
#include <QByteArray>

class AudioDataModel;

class SerialManager : public QObject {
    Q_OBJECT
public:
    explicit SerialManager(AudioDataModel *model, QObject *parent = nullptr);
    ~SerialManager();

    bool connectPort(const QString &portName, qint32 baudRate = 921600);
    void disconnect();
    bool isConnected() const;
    QString portName() const;

    static QStringList availablePorts();

    // Send command to FPGA
    void sendSetParam(quint8 effectIdx, quint8 paramIdx, quint8 value);
    void sendToggleEffect(quint8 effectIdx);
    void sendSetVolume(quint8 volume);

signals:
    void connected();
    void disconnected();
    void errorOccurred(const QString &error);

private slots:
    void onReadyRead();

private:
    QSerialPort *m_serial;
    AudioDataModel *m_model;
    QByteArray m_rxBuffer;

    static const int PACKET_SIZE = 16;
    static const quint8 SYNC_RX = 0xAA;
    static const quint8 SYNC_TX = 0x55;

    void sendCommand(quint8 cmdType, quint8 effect, quint8 param, quint8 value);
};

#endif // SERIALMANAGER_H
