#include "SerialManager.h"
#include "AudioDataModel.h"
#include <QDebug>

SerialManager::SerialManager(AudioDataModel *model, QObject *parent)
    : QObject(parent), m_model(model)
{
    m_serial = new QSerialPort(this);
    connect(m_serial, &QSerialPort::readyRead, this, &SerialManager::onReadyRead);
}

SerialManager::~SerialManager()
{
    disconnect();
}

bool SerialManager::connectPort(const QString &portName, qint32 baudRate)
{
    if (m_serial->isOpen())
        m_serial->close();

    m_serial->setPortName(portName);
    m_serial->setBaudRate(baudRate);
    m_serial->setDataBits(QSerialPort::Data8);
    m_serial->setParity(QSerialPort::NoParity);
    m_serial->setStopBits(QSerialPort::OneStop);
    m_serial->setFlowControl(QSerialPort::NoFlowControl);

    if (m_serial->open(QIODevice::ReadWrite)) {
        m_rxBuffer.clear();
        emit connected();
        qDebug() << "Connected to" << portName << "at" << baudRate << "baud";
        return true;
    } else {
        emit errorOccurred(m_serial->errorString());
        return false;
    }
}

void SerialManager::disconnect()
{
    if (m_serial->isOpen()) {
        m_serial->close();
        emit disconnected();
    }
}

bool SerialManager::isConnected() const
{
    return m_serial->isOpen();
}

QString SerialManager::portName() const
{
    return m_serial->portName();
}

QStringList SerialManager::availablePorts()
{
    QStringList ports;
    for (const auto &info : QSerialPortInfo::availablePorts()) {
        ports << QString("%1 - %2").arg(info.portName(), info.description());
    }
    return ports;
}

void SerialManager::onReadyRead()
{
    m_rxBuffer.append(m_serial->readAll());

    // Search for sync bytes and extract packets
    while (m_rxBuffer.size() >= PACKET_SIZE) {
        // Find sync byte
        int syncIdx = m_rxBuffer.indexOf(static_cast<char>(SYNC_RX));
        if (syncIdx < 0) {
            m_rxBuffer.clear();
            return;
        }

        // Discard bytes before sync
        if (syncIdx > 0)
            m_rxBuffer.remove(0, syncIdx);

        // Check if we have a full packet
        if (m_rxBuffer.size() < PACKET_SIZE)
            return;

        // Extract and process packet
        QByteArray packet = m_rxBuffer.left(PACKET_SIZE);
        m_rxBuffer.remove(0, PACKET_SIZE);

        m_model->processPacket(packet);
    }
}

// Send command to FPGA
void SerialManager::sendCommand(quint8 cmdType, quint8 effect, quint8 param, quint8 value)
{
    if (!m_serial->isOpen()) return;

    QByteArray cmd(6, 0);
    cmd[0] = static_cast<char>(SYNC_TX);
    cmd[1] = static_cast<char>(cmdType);
    cmd[2] = static_cast<char>(effect);
    cmd[3] = static_cast<char>(param);
    cmd[4] = static_cast<char>(value);

    // Checksum: XOR of bytes 0-4
    quint8 checksum = 0;
    for (int i = 0; i < 5; i++)
        checksum ^= static_cast<quint8>(cmd[i]);
    cmd[5] = static_cast<char>(checksum);

    m_serial->write(cmd);
}

void SerialManager::sendSetParam(quint8 effectIdx, quint8 paramIdx, quint8 value)
{
    sendCommand(0x01, effectIdx, paramIdx, value);
}

void SerialManager::sendToggleEffect(quint8 effectIdx)
{
    sendCommand(0x02, effectIdx, 0, 0);
}

void SerialManager::sendSetVolume(quint8 volume)
{
    sendCommand(0x03, 0, 0, volume);
}
