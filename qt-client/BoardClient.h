#pragma once

#include <QObject>
#include <QHash>
#include <QVariant>

class QLocalSocket;

class BoardClient : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString socketPath READ socketPath WRITE setSocketPath NOTIFY socketPathChanged)

public:
    explicit BoardClient(QObject *parent = nullptr);

    QString socketPath() const;
    void setSocketPath(const QString &path);

    Q_INVOKABLE void request(const QString &method, const QVariantMap &params = {});

signals:
    void socketPathChanged();
    void responseReceived(qint64 id, const QString &method, bool ok, const QString &resultText, const QString &error);

private:
    void handleResponse(QLocalSocket *socket, const QByteArray &line);
    void fail(QLocalSocket *socket, const QString &message);

    QString m_socketPath = QStringLiteral("/run/boardd/boardd.sock");
    qint64 m_nextID = 1;
    QHash<QLocalSocket *, QByteArray> m_buffers;
    QHash<QLocalSocket *, qint64> m_requestIDs;
    QHash<QLocalSocket *, QString> m_methods;
};
