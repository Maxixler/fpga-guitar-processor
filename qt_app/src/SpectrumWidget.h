#ifndef SPECTRUMWIDGET_H
#define SPECTRUMWIDGET_H

#include <QWidget>
#include "qcustomplot.h"
#include "AudioDataModel.h"

class SpectrumWidget : public QWidget {
    Q_OBJECT
public:
    explicit SpectrumWidget(AudioDataModel *model, QWidget *parent = nullptr);
    void updatePlot();

private:
    void setupPlot();
    void computeFFT(const QVector<double> &input, QVector<double> &magnitude);

    QCustomPlot *m_plot;
    AudioDataModel *m_model;
    static const int FFT_SIZE = 512;
};

#endif
