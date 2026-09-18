#include "BoardClient.h"

#include <QLocalSocket>
#include <QJsonDocument>
#include <QJsonObject>
#include <QTimer>

BoardClient::BoardClient(QObject *parent) : QObject(parent) {
    const QString configuredSocket = qEnvironmentVariable("BOARDD_SOCKET");
    if (!configuredSocket.isEmpty())
        m_socketPath = configuredSocket;
}

QString BoardClient::socketPath() const {
    return m_socketPath;
}

void BoardClient::setSocketPath(const QString &path) {
    if (path.isEmpty() || path == m_socketPath)
        return;
    m_socketPath = path;
    emit socketPathChanged();
}

void BoardClient::request(const QString &method, const QVariantMap &params) {
    if (method.isEmpty())
        return;

    auto *socket = new QLocalSocket(this);
    const qint64 id = m_nextID++;
    m_requestIDs.insert(socket, id);
    m_methods.insert(socket, method);

    connect(socket, &QLocalSocket::connected, this, [this, socket, id, method, params]() {
        // Avoid Qt's newer initializer-list constructor: this client must also
        // run with the older Qt runtime bundled for the board display.
        QJsonObject message;
        message.insert(QStringLiteral("id"), id);
        message.insert(QStringLiteral("method"), method);
        if (!params.isEmpty())
            message.insert(QStringLiteral("params"), QJsonObject::fromVariantMap(params));
        socket->write(QJsonDocument(message).toJson(QJsonDocument::Compact) + '\n');
        socket->flush();
    });
    connect(socket, &QLocalSocket::readyRead, this, [this, socket]() {
        QByteArray &buffer = m_buffers[socket];
        buffer.append(socket->readAll());
        while (true) {
            const int end = buffer.indexOf('\n');
            if (end < 0)
                break;
            const QByteArray line = buffer.left(end);
            buffer.remove(0, end + 1);
            handleResponse(socket, line);
        }
    });
    // errorOccurred was added in newer Qt 5 releases. Use the older signal so
    // the app remains binary-compatible with the board's helperboard Qt 5 SDK.
    connect(socket, static_cast<void (QLocalSocket::*)(QLocalSocket::LocalSocketError)>(&QLocalSocket::error), this, [this, socket](QLocalSocket::LocalSocketError) {
        fail(socket, socket->errorString());
    });

    // A missing/stalled service must not leave the QML UI permanently busy.
    QTimer::singleShot(10000, socket, [this, socket]() {
        if (m_requestIDs.contains(socket))
            fail(socket, QStringLiteral("boardd request timed out"));
    });

    socket->connectToServer(m_socketPath);
}

void BoardClient::handleResponse(QLocalSocket *socket, const QByteArray &line) {
    QJsonParseError parseError;
    const QJsonDocument document = QJsonDocument::fromJson(line, &parseError);
    if (parseError.error != QJsonParseError::NoError || !document.isObject()) {
        fail(socket, QStringLiteral("Invalid boardd response: %1").arg(parseError.errorString()));
        return;
    }

    const QJsonObject response = document.object();
    const qint64 id = response.value(QStringLiteral("id")).toVariant().toLongLong();
    const bool ok = response.value(QStringLiteral("ok")).toBool(false);
    const QVariant result = response.value(QStringLiteral("result")).toVariant();
    const QString error = response.value(QStringLiteral("error")).toString();
    emit responseReceived(id, m_methods.value(socket), ok, result, error);

    m_buffers.remove(socket);
    m_requestIDs.remove(socket);
    m_methods.remove(socket);
    socket->disconnectFromServer();
    socket->deleteLater();
}

void BoardClient::fail(QLocalSocket *socket, const QString &message) {
    if (!m_requestIDs.contains(socket))
        return;
    emit responseReceived(m_requestIDs.value(socket), m_methods.value(socket), false, {}, message);
    m_buffers.remove(socket);
    m_requestIDs.remove(socket);
    m_methods.remove(socket);
    socket->deleteLater();
}
