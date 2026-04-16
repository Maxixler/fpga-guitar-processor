#include <QApplication>
#include <QFile>
#include <QFont>
#include <QFontDatabase>
#include "MainWindow.h"

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    app.setApplicationName("FPGA Guitar Processor");
    app.setOrganizationName("FPGAudio");

    // Load dark stylesheet
    QFile styleFile(":/style.qss");
    if (!styleFile.exists()) {
        styleFile.setFileName(app.applicationDirPath() + "/../resources/style.qss");
    }
    if (!styleFile.exists()) {
        styleFile.setFileName("resources/style.qss");
    }
    if (styleFile.open(QFile::ReadOnly | QFile::Text)) {
        app.setStyleSheet(QString::fromUtf8(styleFile.readAll()));
        styleFile.close();
    }

    // Set default font
    QFont defaultFont("Segoe UI", 10);
    app.setFont(defaultFont);

    MainWindow mainWindow;
    mainWindow.setWindowTitle("🎸 FPGA Guitar Processor Control Panel");
    mainWindow.resize(1280, 800);
    mainWindow.show();

    return app.exec();
}
