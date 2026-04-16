#ifndef KNOBWIDGET_H
#define KNOBWIDGET_H

#include <QWidget>
#include <QPainter>
#include <QMouseEvent>
#include <cmath>

class KnobWidget : public QWidget {
    Q_OBJECT
    Q_PROPERTY(int value READ value WRITE setValue NOTIFY valueChanged)
    Q_PROPERTY(QString label READ label WRITE setLabel)

public:
    explicit KnobWidget(QWidget *parent = nullptr)
        : QWidget(parent) {
        setMinimumSize(60, 80);
        setMaximumSize(80, 100);
    }

    int value() const { return m_value; }
    void setValue(int v) {
        v = qBound(0, v, 255);
        if (m_value != v) {
            m_value = v;
            update();
            emit valueChanged(m_value);
        }
    }

    QString label() const { return m_label; }
    void setLabel(const QString &l) { m_label = l; update(); }

    void setColors(const QColor &knob, const QColor &indicator) {
        m_knobColor = knob;
        m_indicatorColor = indicator;
        update();
    }

signals:
    void valueChanged(int value);

protected:
    void paintEvent(QPaintEvent *) override {
        QPainter p(this);
        p.setRenderHint(QPainter::Antialiasing);

        int side = qMin(width(), height() - 20);
        int cx = width() / 2;
        int cy = side / 2 + 2;
        int r = side / 2 - 4;

        // Knob body (dark circle with gradient)
        QRadialGradient grad(cx, cy, r);
        grad.setColorAt(0.0, m_knobColor.lighter(130));
        grad.setColorAt(0.7, m_knobColor);
        grad.setColorAt(1.0, m_knobColor.darker(150));
        p.setBrush(grad);
        p.setPen(QPen(QColor(60, 60, 80), 2));
        p.drawEllipse(QPoint(cx, cy), r, r);

        // Indicator line
        double angle = 225.0 - (m_value / 255.0) * 270.0;  // 225° to -45° (CW)
        double rad = angle * M_PI / 180.0;
        int x1 = cx + static_cast<int>((r * 0.35) * cos(rad));
        int y1 = cy - static_cast<int>((r * 0.35) * sin(rad));
        int x2 = cx + static_cast<int>((r * 0.85) * cos(rad));
        int y2 = cy - static_cast<int>((r * 0.85) * sin(rad));
        p.setPen(QPen(m_indicatorColor, 3, Qt::SolidLine, Qt::RoundCap));
        p.drawLine(x1, y1, x2, y2);

        // Arc track (background)
        p.setPen(QPen(QColor(50, 50, 70), 3));
        QRect arcRect(cx - r + 6, cy - r + 6, 2 * (r - 6), 2 * (r - 6));
        p.drawArc(arcRect, -45 * 16, 270 * 16);

        // Arc value (colored)
        int spanAngle = static_cast<int>((m_value / 255.0) * 270.0) * 16;
        p.setPen(QPen(m_indicatorColor, 3, Qt::SolidLine, Qt::RoundCap));
        p.drawArc(arcRect, 225 * 16, -spanAngle);

        // Label text
        p.setPen(QColor(200, 200, 210));
        QFont f = font();
        f.setPixelSize(10);
        p.setFont(f);
        p.drawText(QRect(0, side + 2, width(), 16), Qt::AlignHCenter, m_label);

        // Value text
        f.setPixelSize(9);
        f.setBold(true);
        p.setFont(f);
        p.setPen(m_indicatorColor);
        p.drawText(QRect(0, cy - 6, width(), 12), Qt::AlignHCenter, QString::number(m_value));
    }

    void mousePressEvent(QMouseEvent *e) override {
        m_dragging = true;
        m_lastY = e->pos().y();
    }

    void mouseMoveEvent(QMouseEvent *e) override {
        if (m_dragging) {
            int delta = m_lastY - e->pos().y();
            setValue(m_value + delta);
            m_lastY = e->pos().y();
        }
    }

    void mouseReleaseEvent(QMouseEvent *) override {
        m_dragging = false;
    }

    void wheelEvent(QWheelEvent *e) override {
        int delta = e->angleDelta().y() > 0 ? 5 : -5;
        setValue(m_value + delta);
    }

private:
    int m_value = 128;
    QString m_label = "Param";
    QColor m_knobColor = QColor(45, 45, 68);
    QColor m_indicatorColor = QColor(0, 210, 255);
    bool m_dragging = false;
    int m_lastY = 0;
};

#endif // KNOBWIDGET_H
