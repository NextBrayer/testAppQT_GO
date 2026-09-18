#include "BoardClient.h"

#include <QLocalSocket>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QTimer>

namespace {
QString jsonText(const QJsonValue &value) {
    if (value.isObject())
        return QString::fromUtf8(QJsonDocument(value.toObject()).toJson(QJsonDocument::Indented));
    if (value.isArray())
        return QString::fromUtf8(QJsonDocument(value.toArray()).toJson(QJsonDocument::Indented));
    if (value.isString())
        return value.toString();
    if (value.isBool())
        return value.toBool() ? QStringLiteral("true") : QStringLiteral("false");
    if (value.isDouble())
        return QString::number(value.toDouble());
    return QStringLiteral("null");
}
}

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
        // Each BoardClient request has its own socket and boardd sends one
        // newline-delimited reply. Do not retain a hash-map reference here:
        // handleResponse removes that map entry and would leave it dangling.
        QByteArray buffer = m_buffers.value(socket);
        buffer.append(socket->readAll());
        const int end = buffer.indexOf('\n');
        if (end < 0) {
            m_buffers.insert(socket, buffer);
            return;
        }
        handleResponse(socket, buffer.left(end));
    });
    // errorOccurred was added in newer Qt 5 releases. Use the older signal so
    // the app remains binary-compatible with the board's helperboard Qt 5 SDK.
    connect(socket, static_cast<void (QLocalSocket::*)(QLocalSocket::LocalSocketError)>(&QLocalSocket::error), this, [this, socket](QLocalSocket::LocalSocketError) {
        fail(socket, socket->errorString());
    });

    // boardd permits board commands to run for up to 30 seconds. Give them
    // enough time to return instead of racing a legitimate slow operation
    // such as Wi-Fi scanning or a vendor GPIO utility.
    QTimer::singleShot(45000, socket, [this, socket]() {
        if (m_requestIDs.contains(socket))
            fail(socket, QStringLiteral("boardd request timed out"));
    });

    socket->connectToServer(m_socketPath);
}

void BoardClient::handleResponse(QLocalSocket *socket, const QByteArray &line) {
    // The timeout or an earlier socket error may already have completed this
    // request. A late reply must be ignored rather than touching cleared state.
    if (!m_requestIDs.contains(socket))
        return;

    QJsonParseError parseError;
    const QJsonDocument document = QJsonDocument::fromJson(line, &parseError);
    if (parseError.error != QJsonParseError::NoError || !document.isObject()) {
        fail(socket, QStringLiteral("Invalid boardd response: %1").arg(parseError.errorString()));
        return;
    }

    const QJsonObject response = document.object();
    const qint64 id = response.value(QStringLiteral("id")).toVariant().toLongLong();
    const bool ok = response.value(QStringLiteral("ok")).toBool(false);
    const QString resultText = jsonText(response.value(QStringLiteral("result")));
    const QString error = response.value(QStringLiteral("error")).toString();
    emit responseReceived(id, m_methods.value(socket), ok, resultText, error);

    m_buffers.remove(socket);
    m_requestIDs.remove(socket);
    m_methods.remove(socket);
    socket->disconnectFromServer();
    socket->deleteLater();
}

void BoardClient::fail(QLocalSocket *socket, const QString &message) {
    if (!m_requestIDs.contains(socket))
        return;
    emit responseReceived(m_requestIDs.value(socket), m_methods.value(socket), false, QString(), message);
    m_buffers.remove(socket);
    m_requestIDs.remove(socket);
    m_methods.remove(socket);
    socket->deleteLater();
}
