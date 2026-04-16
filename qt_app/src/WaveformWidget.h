#ifndef WAVEFORMWIDGET_H
#define WAVEFORMWIDGET_H

#include <QWidget>
#include "qcustomplot.h"
#include "AudioDataModel.h"

class WaveformWidget : public QWidget {
    Q_OBJECT
public:
    explicit WaveformWidget(AudioDataModel *model, QWidget *parent = nullptr);
    void updatePlot();

private:
    void setupPlot();
    QCustomPlot *m_plot;
    AudioDataModel *m_model;
    static const int DISPLAY_SAMPLES = 512;
};

#endif
