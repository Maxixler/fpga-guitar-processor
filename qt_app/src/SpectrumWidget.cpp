#include "SpectrumWidget.h"
#include <QVBoxLayout>
#include <cmath>
#include "SimpleFFT.h"

SpectrumWidget::SpectrumWidget(AudioDataModel *model, QWidget *parent)
    : QWidget(parent), m_model(model)
{
    m_plot = new QCustomPlot(this);
    auto *layout = new QVBoxLayout(this);
    layout->setContentsMargins(0, 0, 0, 0);
    layout->addWidget(m_plot);
    setupPlot();
}

void SpectrumWidget::setupPlot()
{
    // Dark theme
    m_plot->setBackground(QColor(26, 26, 46));
    m_plot->axisRect()->setBackground(QColor(16, 20, 40));

    // Axes styling
    m_plot->xAxis->setBasePen(QPen(QColor(60, 60, 80)));
    m_plot->yAxis->setBasePen(QPen(QColor(60, 60, 80)));
    m_plot->xAxis->setTickPen(QPen(QColor(60, 60, 80)));
    m_plot->yAxis->setTickPen(QPen(QColor(60, 60, 80)));
    m_plot->xAxis->setSubTickPen(QPen(QColor(40, 40, 60)));
    m_plot->yAxis->setSubTickPen(QPen(QColor(40, 40, 60)));
    m_plot->xAxis->setTickLabelColor(QColor(120, 120, 145));
    m_plot->yAxis->setTickLabelColor(QColor(120, 120, 145));
    m_plot->xAxis->setLabelColor(QColor(150, 150, 170));
    m_plot->yAxis->setLabelColor(QColor(150, 150, 170));

    m_plot->xAxis->grid()->setPen(QPen(QColor(40, 40, 60), 1, Qt::DotLine));
    m_plot->yAxis->grid()->setPen(QPen(QColor(40, 40, 60), 1, Qt::DotLine));

    // Log scale for frequency axis
    m_plot->xAxis->setRange(20, 20000);
    m_plot->xAxis->setScaleType(QCPAxis::stLogarithmic);
    QSharedPointer<QCPAxisTickerLog> logTicker(new QCPAxisTickerLog);
    m_plot->xAxis->setTicker(logTicker);

    m_plot->yAxis->setRange(-80, 0);  // dB scale
    m_plot->xAxis->setLabel("Frequency (Hz)");
    m_plot->yAxis->setLabel("Magnitude (dB)");

    // Title
    m_plot->plotLayout()->insertRow(0);
    QCPTextElement *title = new QCPTextElement(m_plot, "SPECTRUM ANALYZER", QFont("Segoe UI", 11, QFont::Bold));
    title->setTextColor(QColor(200, 200, 220));
    m_plot->plotLayout()->addElement(0, 0, title);

    // Spectrum bars graph with gradient
    m_plot->addGraph();
    QPen specPen(QColor(0, 210, 255));
    specPen.setWidth(1);
    m_plot->graph(0)->setPen(specPen);
    m_plot->graph(0)->setBrush(QBrush(QColor(0, 210, 255, 50)));
    m_plot->graph(0)->setName("Spectrum");
}

void SpectrumWidget::computeFFT(const QVector<double> &input, QVector<double> &magnitude)
{
    int N = FFT_SIZE;
    std::vector<double> inputVec(N, 0.0);
    for (int i = 0; i < N && i < input.size(); i++)
        inputVec[i] = input[i];

    std::vector<double> mag = SimpleFFT::magnitudeDB(inputVec, N);

    magnitude.resize(static_cast<int>(mag.size()));
    for (int i = 0; i < static_cast<int>(mag.size()); i++)
        magnitude[i] = mag[i];
}

void SpectrumWidget::updatePlot()
{
    QVector<double> samples = m_model->outputBuffer.getLastN(FFT_SIZE);
    QVector<double> magnitude;
    computeFFT(samples, magnitude);

    // Create frequency axis (Hz)
    double sampleRate = 1920.0;  // Decimated rate from FPGA
    QVector<double> freqs(magnitude.size());
    for (int i = 0; i < magnitude.size(); i++) {
        freqs[i] = (static_cast<double>(i) * sampleRate) / FFT_SIZE;
        if (freqs[i] < 1.0) freqs[i] = 1.0;  // Avoid log(0)
    }

    m_plot->graph(0)->setData(freqs, magnitude, true);

    // Adjust X range to available frequency range
    m_plot->xAxis->setRange(1, sampleRate / 2.0);
    m_plot->replot(QCustomPlot::rpQueuedReplot);
}
