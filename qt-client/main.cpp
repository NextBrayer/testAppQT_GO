#include <QGuiApplication>
#include <QCoreApplication>
#include <QDir>
#include <QQmlApplicationEngine>
#include <qqml.h>

#include "BoardClient.h"

int main(int argc, char *argv[]) {
    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("boardd-qml-client"));

    qmlRegisterType<BoardClient>("BoarddClient", 1, 0, "BoardClient");

    QQmlApplicationEngine engine;
    QString qmlPath = qEnvironmentVariable("BOARDD_QML_PATH");
    if (qmlPath.isEmpty()) {
        qmlPath = QDir(QCoreApplication::applicationDirPath()).absoluteFilePath("../qml/Main.qml");
    }
    const QUrl url = QUrl::fromLocalFile(qmlPath);
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated, &app, [url](QObject *object, const QUrl &objectURL) {
        if (!object && objectURL == url)
            QCoreApplication::exit(-1);
    }, Qt::QueuedConnection);
    engine.load(url);
    return app.exec();
}
