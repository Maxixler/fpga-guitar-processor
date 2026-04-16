#include "MainWindow.h"
#include "AudioDataModel.h"
#include "SerialManager.h"
#include "WaveformWidget.h"
#include "SpectrumWidget.h"
#include "PedalBoard.h"
#include "VuMeterWidget.h"

#include <QVBoxLayout>
#include <QHBoxLayout>
#include <QSplitter>
#include <QGroupBox>
#include <QToolBar>
#include <QStatusBar>
#include <QMessageBox>
#include <QFrame>

MainWindow::MainWindow(QWidget *parent)
    : QMainWindow(parent)
{
    m_model   = new AudioDataModel(this);
    m_serial  = new SerialManager(m_model, this);

    setupUI();
    setupConnections();

    // Display refresh timer (60 FPS for waveform, 30 FPS for spectrum)
    m_displayTimer = new QTimer(this);
    m_displayTimer->setInterval(16);  // ~60 FPS
    connect(m_displayTimer, &QTimer::timeout, this, &MainWindow::onDisplayUpdate);
    m_displayTimer->start();
}

MainWindow::~MainWindow()
{
    m_serial->disconnect();
}

void MainWindow::setupUI()
{
    // ======== Central Widget ========
    QWidget *central = new QWidget(this);
    setCentralWidget(central);
    QVBoxLayout *mainLayout = new QVBoxLayout(central);
    mainLayout->setSpacing(8);
    mainLayout->setContentsMargins(10, 10, 10, 10);

    // ======== Connection Toolbar ========
    QHBoxLayout *toolbarLayout = new QHBoxLayout();

    // Logo / Title
    QLabel *titleLabel = new QLabel("🎸 FPGA Guitar Processor", this);
    titleLabel->setStyleSheet("font-size: 16px; font-weight: bold; color: #00d2ff; padding: 4px;");
    toolbarLayout->addWidget(titleLabel);

    toolbarLayout->addStretch();

    // Port selection
    QLabel *portLabel = new QLabel("COM Port:", this);
    portLabel->setStyleSheet("color: #aaa;");
    toolbarLayout->addWidget(portLabel);

    m_portCombo = new QComboBox(this);
    m_portCombo->setMinimumWidth(200);
    toolbarLayout->addWidget(m_portCombo);

    m_refreshBtn = new QPushButton("⟳", this);
    m_refreshBtn->setFixedSize(30, 30);
    m_refreshBtn->setToolTip("Refresh ports");
    toolbarLayout->addWidget(m_refreshBtn);

    m_connectBtn = new QPushButton("Connect", this);
    m_connectBtn->setFixedWidth(100);
    m_connectBtn->setProperty("class", "connectBtn");
    toolbarLayout->addWidget(m_connectBtn);

    // Status indicator
    m_statusLabel = new QLabel("● Disconnected", this);
    m_statusLabel->setStyleSheet("color: #666; font-weight: bold; padding-left: 10px;");
    toolbarLayout->addWidget(m_statusLabel);

    m_rateLabel = new QLabel("", this);
    m_rateLabel->setStyleSheet("color: #555; padding-left: 10px;");
    toolbarLayout->addWidget(m_rateLabel);

    mainLayout->addLayout(toolbarLayout);

    // ======== Separator ========
    QFrame *sep1 = new QFrame(this);
    sep1->setFrameShape(QFrame::HLine);
    sep1->setStyleSheet("background-color: #2a2a40;");
    mainLayout->addWidget(sep1);

    // ======== Top Section: Waveform + Spectrum + VU ========
    QHBoxLayout *topLayout = new QHBoxLayout();

    // VU In
    m_vuIn = new VuMeterWidget("INPUT", this);
    topLayout->addWidget(m_vuIn);

    // Waveform
    m_waveform = new WaveformWidget(m_model, this);
    topLayout->addWidget(m_waveform, 3);

    // Spectrum
    m_spectrum = new SpectrumWidget(m_model, this);
    topLayout->addWidget(m_spectrum, 3);

    // VU Out
    m_vuOut = new VuMeterWidget("OUTPUT", this);
    topLayout->addWidget(m_vuOut);

    mainLayout->addLayout(topLayout, 3);

    // ======== Separator ========
    QFrame *sep2 = new QFrame(this);
    sep2->setFrameShape(QFrame::HLine);
    sep2->setStyleSheet("background-color: #2a2a40;");
    mainLayout->addWidget(sep2);

    // ======== Pedalboard Section ========
    QLabel *pedalTitle = new QLabel("🎛️ PEDALBOARD", this);
    pedalTitle->setStyleSheet("font-size: 13px; font-weight: bold; color: #888; padding: 4px;");
    mainLayout->addWidget(pedalTitle);

    m_pedalBoard = new PedalBoard(m_serial, this);
    mainLayout->addWidget(m_pedalBoard, 2);

    // ======== Bottom Bar: Volume + Status ========
    QHBoxLayout *bottomLayout = new QHBoxLayout();

    QLabel *volLabel = new QLabel("Master Volume:", this);
    volLabel->setStyleSheet("color: #aaa;");
    bottomLayout->addWidget(volLabel);

    m_volumeSlider = new QSlider(Qt::Horizontal, this);
    m_volumeSlider->setRange(0, 15);
    m_volumeSlider->setValue(12);
    m_volumeSlider->setFixedWidth(200);
    bottomLayout->addWidget(m_volumeSlider);

    m_volumeLabel = new QLabel("12", this);
    m_volumeLabel->setStyleSheet("color: #00d2ff; font-weight: bold; min-width: 30px;");
    bottomLayout->addWidget(m_volumeLabel);

    bottomLayout->addStretch();

    mainLayout->addLayout(bottomLayout);

    // Populate ports
    onRefreshPorts();
}

void MainWindow::setupConnections()
{
    connect(m_connectBtn, &QPushButton::clicked, this, &MainWindow::onConnectClicked);
    connect(m_refreshBtn, &QPushButton::clicked, this, &MainWindow::onRefreshPorts);

    connect(m_serial, &SerialManager::connected, this, &MainWindow::onSerialConnected);
    connect(m_serial, &SerialManager::disconnected, this, &MainWindow::onSerialDisconnected);
    connect(m_serial, &SerialManager::errorOccurred, this, &MainWindow::onSerialError);

    connect(m_model, &AudioDataModel::statusUpdated, this, &MainWindow::onStatusUpdate);

    connect(m_volumeSlider, &QSlider::valueChanged, this, [this](int v) {
        m_volumeLabel->setText(QString::number(v));
        m_serial->sendSetVolume(static_cast<quint8>(v));
    });
}

void MainWindow::onConnectClicked()
{
    if (m_serial->isConnected()) {
        m_serial->disconnect();
    } else {
        QString portText = m_portCombo->currentText();
        QString portName = portText.split(" - ").first().trimmed();
        if (!portName.isEmpty()) {
            m_serial->connectPort(portName);
        }
    }
}

void MainWindow::onRefreshPorts()
{
    m_portCombo->clear();
    m_portCombo->addItems(SerialManager::availablePorts());
}

static int frameCounter = 0;

void MainWindow::onDisplayUpdate()
{
    frameCounter++;

    // Waveform: every frame (~60 FPS)
    m_waveform->updatePlot();

    // VU meters: every frame
    m_vuIn->setLevel(m_model->vuIn());
    m_vuOut->setLevel(m_model->vuOut());

    // Spectrum: every 2nd frame (~30 FPS)
    if (frameCounter % 2 == 0) {
        m_spectrum->updatePlot();
    }

    // Pedalboard state: every 10th frame (~6 Hz)
    if (frameCounter % 10 == 0) {
        m_pedalBoard->updateFromFPGA(
            m_model->effectEnables(),
            m_model->selectedEffect(),
            m_model->param1(),
            m_model->param2()
        );
    }
}

void MainWindow::onStatusUpdate()
{
    m_rateLabel->setText(QString("%1 pkt/s").arg(m_model->packetRate()));
}

void MainWindow::onSerialConnected()
{
    m_statusLabel->setText("● Connected");
    m_statusLabel->setStyleSheet("color: #00ff88; font-weight: bold; padding-left: 10px;");
    m_connectBtn->setText("Disconnect");
    m_connectBtn->setStyleSheet("background-color: #e94560;");
}

void MainWindow::onSerialDisconnected()
{
    m_statusLabel->setText("● Disconnected");
    m_statusLabel->setStyleSheet("color: #666; font-weight: bold; padding-left: 10px;");
    m_connectBtn->setText("Connect");
    m_connectBtn->setStyleSheet("");
    m_rateLabel->clear();
}

void MainWindow::onSerialError(const QString &error)
{
    QMessageBox::warning(this, "Serial Error", error);
}
