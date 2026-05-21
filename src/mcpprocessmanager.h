/*
    SPDX-FileCopyrightText: 2026 Denys Madureira <denys@koderoots.org>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

#ifndef MCPPROCESSMANAGER_H
#define MCPPROCESSMANAGER_H

#include <QObject>
#include <QProcess>
#include <QString>
#include <QStringList>
#include <QJsonObject>
#include <QJsonDocument>
#include <QMap>
#include <QVariantMap>

class McpProcess : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QString serverId READ serverId CONSTANT)
    Q_PROPERTY(QString command READ command CONSTANT)
    Q_PROPERTY(QStringList args READ args CONSTANT)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
    Q_PROPERTY(QString serverName READ serverName NOTIFY serverNameChanged)
    Q_PROPERTY(int toolCount READ toolCount NOTIFY toolCountChanged)

public:
    explicit McpProcess(const QString &serverId, const QString &command,
                       const QStringList &args, const QVariantMap &env,
                       QObject *parent = nullptr);
    ~McpProcess();

    QString serverId() const;
    QString command() const;
    QStringList args() const;
    QString status() const;
    QString serverName() const;
    int toolCount() const;

    Q_INVOKABLE void start();
    Q_INVOKABLE void stop();
    Q_INVOKABLE void sendMessage(const QString &jsonMessage, int requestId);

Q_SIGNALS:
    void statusChanged(const QString &status);
    void serverNameChanged(const QString &name);
    void toolCountChanged(int count);
    void messageReceived(const QString &serverId, const QString &jsonMessage);
    void errorOccurred(const QString &serverId, const QString &errorMessage);

private Q_SLOTS:
    void onProcessStarted();
    void onProcessFinished(int exitCode, QProcess::ExitStatus exitStatus);
    void onProcessError(QProcess::ProcessError error);
    void onReadyReadStandardOutput();
    void onReadyReadStandardError();

private:
    void setStatus(const QString &status);
    void processBuffer();
    void sendInitializedNotification();
    void requestToolsList();

    QString m_serverId;
    QString m_command;
    QStringList m_args;
    QVariantMap m_env;
    QProcess *m_process;
    QString m_status;
    QString m_serverName;
    int m_toolCount;
    QString m_buffer;
    bool m_initialized;
};

class McpProcessManager : public QObject
{
    Q_OBJECT

public:
    static McpProcessManager* instance();

    Q_INVOKABLE QString startProcess(const QString &serverId, const QString &command,
                                      const QStringList &args, const QVariantMap &env);
    Q_INVOKABLE void stopProcess(const QString &serverId);
    Q_INVOKABLE void stopAll();
    Q_INVOKABLE void sendMessage(const QString &serverId, const QString &jsonMessage, int requestId);
    Q_INVOKABLE QString getProcessStatus(const QString &serverId) const;
    Q_INVOKABLE int getToolCount(const QString &serverId) const;
    Q_INVOKABLE bool hasProcess(const QString &serverId) const;

Q_SIGNALS:
    void messageReceived(const QString &serverId, const QString &jsonMessage);
    void processStatusChanged(const QString &serverId, const QString &status);
    void processError(const QString &serverId, const QString &errorMessage);

private:
    explicit McpProcessManager(QObject *parent = nullptr);
    ~McpProcessManager();
    Q_DISABLE_COPY(McpProcessManager)

    QMap<QString, McpProcess*> m_processes;
    static McpProcessManager *s_instance;
};

#endif // MCPPROCESSMANAGER_H