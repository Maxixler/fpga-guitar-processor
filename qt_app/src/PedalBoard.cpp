#include "PedalBoard.h"
#include "SerialManager.h"
#include <QGraphicsDropShadowEffect>

// ============================================================================
// PedalWidget
// ============================================================================

PedalWidget::PedalWidget(int index, const QString &name,
                         const QString &param1Name, const QString &param2Name,
                         const QColor &accentColor, QWidget *parent)
    : QWidget(parent)
    , m_index(index)
    , m_name(name)
    , m_accentColor(accentColor)
{
    setMinimumSize(140, 240);
    setMaximumSize(160, 280);
    setCursor(Qt::PointingHandCursor);

    auto *layout = new QVBoxLayout(this);
    layout->setSpacing(4);
    layout->setContentsMargins(8, 30, 8, 8);

    // LED indicator
    m_ledLabel = new QLabel("●", this);
    m_ledLabel->setAlignment(Qt::AlignCenter);
    m_ledLabel->setStyleSheet("color: #333; font-size: 18px;");
    layout->addWidget(m_ledLabel);

    // Knob 1
    m_knob1 = new KnobWidget(this);
    m_knob1->setLabel(param1Name);
    m_knob1->setColors(QColor(45, 45, 68), accentColor);
    layout->addWidget(m_knob1, 0, Qt::AlignHCenter);

    // Knob 2
    if (!param2Name.isEmpty()) {
        m_knob2 = new KnobWidget(this);
        m_knob2->setLabel(param2Name);
        m_knob2->setColors(QColor(45, 45, 68), accentColor.lighter(130));
        layout->addWidget(m_knob2, 0, Qt::AlignHCenter);
    } else {
        m_knob2 = nullptr;
        layout->addStretch();
    }

    // Connect knob signals
    connect(m_knob1, &KnobWidget::valueChanged, this, [this](int v) {
        emit param1Changed(m_index, v);
    });
    if (m_knob2) {
        connect(m_knob2, &KnobWidget::valueChanged, this, [this](int v) {
            emit param2Changed(m_index, v);
        });
    }

    // Drop shadow effect
    auto *shadow = new QGraphicsDropShadowEffect(this);
    shadow->setBlurRadius(15);
    shadow->setColor(QColor(0, 0, 0, 100));
    shadow->setOffset(3, 3);
    setGraphicsEffect(shadow);
}

void PedalWidget::setActive(bool active)
{
    m_active = active;
    m_ledLabel->setStyleSheet(active
        ? QString("color: %1; font-size: 18px;").arg(m_accentColor.name())
        : "color: #333; font-size: 18px;");
    update();
}

void PedalWidget::setSelected(bool sel)
{
    m_selected = sel;
    update();
}

void PedalWidget::paintEvent(QPaintEvent *)
{
    QPainter p(this);
    p.setRenderHint(QPainter::Antialiasing);

    // Pedal body
    QLinearGradient grad(0, 0, 0, height());
    grad.setColorAt(0.0, QColor(35, 35, 55));
    grad.setColorAt(0.5, QColor(28, 28, 45));
    grad.setColorAt(1.0, QColor(22, 22, 38));
    p.setBrush(grad);

    QPen borderPen(m_selected ? m_accentColor : QColor(55, 55, 75), m_selected ? 2 : 1);
    p.setPen(borderPen);
    p.drawRoundedRect(rect().adjusted(1, 1, -1, -1), 10, 10);

    // Pedal name
    QFont f("Segoe UI", 11, QFont::Bold);
    p.setFont(f);
    p.setPen(m_active ? m_accentColor : QColor(100, 100, 120));
    p.drawText(QRect(0, 6, width(), 22), Qt::AlignHCenter, m_name);

    // Active glow
    if (m_active) {
        p.setPen(Qt::NoPen);
        QRadialGradient glow(width() / 2, 18, 40);
        glow.setColorAt(0.0, QColor(m_accentColor.red(), m_accentColor.green(), m_accentColor.blue(), 40));
        glow.setColorAt(1.0, QColor(m_accentColor.red(), m_accentColor.green(), m_accentColor.blue(), 0));
        p.setBrush(glow);
        p.drawEllipse(QPoint(width() / 2, 18), 40, 20);
    }
}

void PedalWidget::mousePressEvent(QMouseEvent *)
{
    m_active = !m_active;
    setActive(m_active);
    emit toggled(m_index, m_active);
}

// ============================================================================
// PedalBoard
// ============================================================================

PedalBoard::PedalBoard(SerialManager *serial, QWidget *parent)
    : QWidget(parent), m_serial(serial)
{
    auto *layout = new QHBoxLayout(this);
    layout->setSpacing(10);
    layout->setContentsMargins(10, 10, 10, 10);

    // Pedal definitions: name, param1, param2, color
    struct PedalDef {
        const char *name, *p1, *p2;
        QColor color;
    };
    PedalDef defs[] = {
        {"GATE",     "Threshold", "",         QColor(0, 200, 120)},      // Green
        {"DISTORT",  "Gain",      "Tone",     QColor(255, 45, 45)},      // Red
        {"OVERDRIVE","Drive",     "Mix",      QColor(255, 165, 0)},      // Orange
        {"DELAY",    "Time",      "Feedback", QColor(0, 150, 255)},      // Blue
        {"REVERB",   "Decay",     "Mix",      QColor(148, 103, 255)},    // Purple
        {"CHORUS",   "Rate",      "Depth",    QColor(0, 210, 255)},      // Cyan
        {"TREMOLO",  "Rate",      "Depth",    QColor(255, 215, 0)},      // Gold
    };

    for (int i = 0; i < 7; i++) {
        m_pedals[i] = new PedalWidget(i, defs[i].name, defs[i].p1, defs[i].p2, defs[i].color, this);
        layout->addWidget(m_pedals[i]);

        // Connect toggle
        connect(m_pedals[i], &PedalWidget::toggled, this, [this](int idx, bool active) {
            emit effectToggled(idx, active);
            if (m_serial) m_serial->sendToggleEffect(static_cast<quint8>(idx));
        });

        // Connect param changes
        connect(m_pedals[i], &PedalWidget::param1Changed, this, [this](int idx, int val) {
            emit paramChanged(idx, 0, val);
            if (m_serial) m_serial->sendSetParam(static_cast<quint8>(idx), 0, static_cast<quint8>(val));
        });
        connect(m_pedals[i], &PedalWidget::param2Changed, this, [this](int idx, int val) {
            emit paramChanged(idx, 1, val);
            if (m_serial) m_serial->sendSetParam(static_cast<quint8>(idx), 1, static_cast<quint8>(val));
        });
    }
}

void PedalBoard::updateFromFPGA(quint8 effectEnables, quint8 selectedEffect,
                                 quint8 param1, quint8 param2)
{
    for (int i = 0; i < 7; i++) {
        m_pedals[i]->setActive(effectEnables & (1 << i));
        m_pedals[i]->setSelected(i == selectedEffect);
    }

    // Update knobs of selected effect
    if (selectedEffect < 7) {
        m_pedals[selectedEffect]->knob1()->setValue(param1);
        if (m_pedals[selectedEffect]->knob2())
            m_pedals[selectedEffect]->knob2()->setValue(param2);
    }
}
