#ifndef MAINWINDOW_H
#define MAINWINDOW_H

#include <QMainWindow>
#include <QTimer>
#include <QComboBox>
#include <QLabel>
#include <QPushButton>
#include <QSlider>

class AudioDataModel;
class SerialManager;
class WaveformWidget;
class SpectrumWidget;
class PedalBoard;
class VuMeterWidget;

class MainWindow : public QMainWindow {
    Q_OBJECT
public:
    explicit MainWindow(QWidget *parent = nullptr);
    ~MainWindow();

private slots:
    void onConnectClicked();
    void onRefreshPorts();
    void onDisplayUpdate();
    void onStatusUpdate();
    void onSerialConnected();
    void onSerialDisconnected();
    void onSerialError(const QString &error);

private:
    void setupUI();
    void setupConnections();

    // Core
    AudioDataModel *m_model;
    SerialManager  *m_serial;
    QTimer         *m_displayTimer;

    // Widgets
    WaveformWidget *m_waveform;
    SpectrumWidget *m_spectrum;
    PedalBoard     *m_pedalBoard;
    VuMeterWidget  *m_vuIn;
    VuMeterWidget  *m_vuOut;

    // Toolbar
    QComboBox      *m_portCombo;
    QPushButton    *m_connectBtn;
    QPushButton    *m_refreshBtn;
    QLabel         *m_statusLabel;
    QLabel         *m_rateLabel;
    QSlider        *m_volumeSlider;
    QLabel         *m_volumeLabel;
};

#endif // MAINWINDOW_H
