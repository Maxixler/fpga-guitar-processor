#include "WaveformWidget.h"
#include <QVBoxLayout>

WaveformWidget::WaveformWidget(AudioDataModel *model, QWidget *parent)
    : QWidget(parent), m_model(model)
{
    m_plot = new QCustomPlot(this);
    auto *layout = new QVBoxLayout(this);
    layout->setContentsMargins(0, 0, 0, 0);
    layout->addWidget(m_plot);
    setupPlot();
}

void WaveformWidget::setupPlot()
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

    // Grid
    m_plot->xAxis->grid()->setPen(QPen(QColor(40, 40, 60), 1, Qt::DotLine));
    m_plot->yAxis->grid()->setPen(QPen(QColor(40, 40, 60), 1, Qt::DotLine));

    // Range
    m_plot->xAxis->setRange(0, DISPLAY_SAMPLES);
    m_plot->yAxis->setRange(-1.0, 1.0);
    m_plot->xAxis->setLabel("Sample");
    m_plot->yAxis->setLabel("Amplitude");

    // Title
    m_plot->plotLayout()->insertRow(0);
    QCPTextElement *title = new QCPTextElement(m_plot, "WAVEFORM", QFont("Segoe UI", 11, QFont::Bold));
    title->setTextColor(QColor(200, 200, 220));
    m_plot->plotLayout()->addElement(0, 0, title);

    // Input graph (cyan)
    m_plot->addGraph();
    m_plot->graph(0)->setPen(QPen(QColor(0, 210, 255), 1.5));
    m_plot->graph(0)->setName("Input");

    // Output graph (orange)
    m_plot->addGraph();
    m_plot->graph(1)->setPen(QPen(QColor(255, 107, 53), 1.5));
    m_plot->graph(1)->setName("Output");

    // Legend
    m_plot->legend->setVisible(true);
    m_plot->legend->setBrush(QColor(26, 26, 46, 180));
    m_plot->legend->setTextColor(QColor(180, 180, 200));
    m_plot->legend->setBorderPen(QPen(QColor(60, 60, 80)));
    QFont legendFont = font();
    legendFont.setPointSize(8);
    m_plot->legend->setFont(legendFont);
    m_plot->axisRect()->insetLayout()->setInsetAlignment(0, Qt::AlignTop | Qt::AlignRight);
}

void WaveformWidget::updatePlot()
{
    QVector<double> keys(DISPLAY_SAMPLES);
    for (int i = 0; i < DISPLAY_SAMPLES; i++)
        keys[i] = i;

    QVector<double> inData = m_model->inputBuffer.getLastN(DISPLAY_SAMPLES);
    QVector<double> outData = m_model->outputBuffer.getLastN(DISPLAY_SAMPLES);

    m_plot->graph(0)->setData(keys, inData, true);
    m_plot->graph(1)->setData(keys, outData, true);
    m_plot->replot(QCustomPlot::rpQueuedReplot);
}
