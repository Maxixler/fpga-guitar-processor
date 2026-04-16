#ifndef VUMETERWIDGET_H
#define VUMETERWIDGET_H

#include <QWidget>
#include <QPainter>
#include <QLinearGradient>

class VuMeterWidget : public QWidget {
    Q_OBJECT
public:
    explicit VuMeterWidget(const QString &title = "VU", QWidget *parent = nullptr)
        : QWidget(parent), m_title(title) {
        setMinimumSize(60, 200);
        setMaximumWidth(80);
    }

    void setLevel(double level) {  // 0.0 to 1.0
        m_level = qBound(0.0, level, 1.0);
        // Peak hold
        if (m_level > m_peak) {
            m_peak = m_level;
            m_peakHoldFrames = 60;  // Hold for ~1 second at 60 FPS
        }
        if (m_peakHoldFrames > 0) {
            m_peakHoldFrames--;
        } else {
            m_peak = qMax(m_peak - 0.01, m_level);
        }
        update();
    }

protected:
    void paintEvent(QPaintEvent *) override {
        QPainter p(this);
        p.setRenderHint(QPainter::Antialiasing);

        int barWidth = width() - 20;
        int barHeight = height() - 40;
        int barX = (width() - barWidth) / 2;
        int barY = 20;

        // Background
        p.setBrush(QColor(20, 20, 30));
        p.setPen(QPen(QColor(50, 50, 70), 1));
        p.drawRoundedRect(barX, barY, barWidth, barHeight, 4, 4);

        // Gradient bar (green → yellow → red)
        int fillHeight = static_cast<int>(m_level * barHeight);
        QLinearGradient grad(barX, barY + barHeight, barX, barY);
        grad.setColorAt(0.0, QColor(0, 255, 136));       // Green
        grad.setColorAt(0.6, QColor(0, 255, 136));
        grad.setColorAt(0.75, QColor(255, 215, 0));      // Yellow
        grad.setColorAt(0.85, QColor(255, 165, 0));      // Orange
        grad.setColorAt(1.0, QColor(255, 45, 45));       // Red

        p.setBrush(grad);
        p.setPen(Qt::NoPen);
        p.drawRoundedRect(barX + 2, barY + barHeight - fillHeight + 2,
                          barWidth - 4, fillHeight - 4, 2, 2);

        // Segment lines
        p.setPen(QPen(QColor(20, 20, 30), 1));
        int segments = 16;
        for (int i = 1; i < segments; i++) {
            int y = barY + (barHeight * i / segments);
            p.drawLine(barX + 2, y, barX + barWidth - 2, y);
        }

        // Peak indicator
        int peakY = barY + barHeight - static_cast<int>(m_peak * barHeight);
        p.setPen(QPen(QColor(255, 255, 255), 2));
        p.drawLine(barX + 2, peakY, barX + barWidth - 2, peakY);

        // dB scale markers
        p.setPen(QColor(120, 120, 140));
        QFont f = font();
        f.setPixelSize(8);
        p.setFont(f);

        QStringList dbLabels = {"0", "-3", "-6", "-12", "-20", "-∞"};
        double dbPositions[] = {0.0, 0.15, 0.3, 0.5, 0.75, 1.0};
        for (int i = 0; i < 6; i++) {
            int y = barY + static_cast<int>(dbPositions[i] * barHeight);
            p.drawText(barX + barWidth + 2, y + 3, dbLabels[i]);
        }

        // Title
        p.setPen(QColor(180, 180, 200));
        f.setPixelSize(11);
        f.setBold(true);
        p.setFont(f);
        p.drawText(QRect(0, 2, width(), 16), Qt::AlignHCenter, m_title);

        // Level value
        f.setPixelSize(10);
        f.setBold(false);
        p.setFont(f);
        int dbValue = (m_level > 0.001) ? static_cast<int>(20.0 * log10(m_level)) : -60;
        p.drawText(QRect(0, height() - 18, width(), 16), Qt::AlignHCenter,
                   QString("%1 dB").arg(dbValue));
    }

private:
    double m_level = 0.0;
    double m_peak = 0.0;
    int m_peakHoldFrames = 0;
    QString m_title;
};

#endif // VUMETERWIDGET_H
