#ifndef PEDALBOARD_H
#define PEDALBOARD_H

#include <QWidget>
#include <QHBoxLayout>
#include <QVBoxLayout>
#include <QLabel>
#include <QPushButton>
#include <QPainter>
#include "KnobWidget.h"

class SerialManager;

// Single Pedal Widget
class PedalWidget : public QWidget {
    Q_OBJECT
public:
    PedalWidget(int index, const QString &name, const QString &param1Name,
                const QString &param2Name, const QColor &accentColor,
                QWidget *parent = nullptr);

    void setActive(bool active);
    bool isActive() const { return m_active; }
    void setSelected(bool sel);
    int effectIndex() const { return m_index; }
    KnobWidget* knob1() { return m_knob1; }
    KnobWidget* knob2() { return m_knob2; }

signals:
    void toggled(int index, bool active);
    void param1Changed(int index, int value);
    void param2Changed(int index, int value);

protected:
    void paintEvent(QPaintEvent *) override;
    void mousePressEvent(QMouseEvent *) override;

private:
    int m_index;
    QString m_name;
    QColor m_accentColor;
    bool m_active = false;
    bool m_selected = false;
    KnobWidget *m_knob1;
    KnobWidget *m_knob2;
    QLabel *m_ledLabel;
};

// Full Pedalboard (7 pedals)
class PedalBoard : public QWidget {
    Q_OBJECT
public:
    explicit PedalBoard(SerialManager *serial, QWidget *parent = nullptr);

    void updateFromFPGA(quint8 effectEnables, quint8 selectedEffect,
                        quint8 param1, quint8 param2);

signals:
    void effectToggled(int index, bool active);
    void paramChanged(int effect, int param, int value);

private:
    PedalWidget *m_pedals[7];
    SerialManager *m_serial;
};

#endif
