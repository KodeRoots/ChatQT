/*
    SPDX-FileCopyrightText: 2026 Denys Madureira <denys@koderoots.org>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

#include "mcpprocessmanager.h"

#include <QDir>
#include <QStandardPaths>

McpProcess::McpProcess(const QString &serverId, const QString &command,
                       const QStringList &args, const QVariantMap &env,
                       QObject *parent)
    : QObject(parent)
    , m_serverId(serverId)
    , m_command(command)
    , m_args(args)
    , m_env(env)
    , m_process(new QProcess(this))
    , m_status(QStringLiteral("disconnected"))
    , m_toolCount(0)
    , m_initialized(false)
{
    connect(m_process, &QProcess::started, this, &McpProcess::onProcessStarted);
    connect(m_process, &QProcess::finished, this, &McpProcess::onProcessFinished);
    connect(m_process, &QProcess::errorOccurred, this, &McpProcess::onProcessError);
    connect(m_process, &QProcess::readyReadStandardOutput, this, &McpProcess::onReadyReadStandardOutput);
    connect(m_process, &QProcess::readyReadStandardError, this, &McpProcess::onReadyReadStandardError);
}

McpProcess::~McpProcess()
{
    stop();
}

QString McpProcess::serverId() const { return m_serverId; }
QString McpProcess::command() const { return m_command; }
QStringList McpProcess::args() const { return m_args; }
QString McpProcess::status() const { return m_status; }
QString McpProcess::serverName() const { return m_serverName; }
int McpProcess::toolCount() const { return m_toolCount; }

void McpProcess::setStatus(const QString &status)
{
    if (m_status != status) {
        m_status = status;
        Q_EMIT statusChanged(m_status);
    }
}

void McpProcess::start()
{
    if (m_process->state() != QProcess::NotRunning) {
        return;
    }

    QProcessEnvironment procEnv = QProcessEnvironment::systemEnvironment();
    for (auto it = m_env.constBegin(); it != m_env.constEnd(); ++it) {
        procEnv.insert(it.key(), it.value().toString());
    }
    m_process->setProcessEnvironment(procEnv);

    m_buffer.clear();
    m_initialized = false;
    setStatus(QStringLiteral("connecting"));

    m_process->start(m_command, m_args);
}

void McpProcess::stop()
{
    if (m_process->state() == QProcess::NotRunning) {
        return;
    }

    m_process->closeWriteChannel();

    if (!m_process->waitForFinished(3000)) {
        m_process->terminate();
        if (!m_process->waitForFinished(2000)) {
            m_process->kill();
            m_process->waitForFinished(1000);
        }
    }

    m_initialized = false;
    setStatus(QStringLiteral("disconnected"));
}

void McpProcess::sendMessage(const QString &jsonMessage, int requestId)
{
    if (m_process->state() != QProcess::Running) {
        Q_EMIT errorOccurred(m_serverId, QStringLiteral("Process is not running"));
        return;
    }

    QByteArray data = (jsonMessage + QStringLiteral("\n")).toUtf8();
    m_process->write(data);

    if (requestId > 0) {
        m_pendingRequests[requestId] = jsonMessage;
    }
}

QString McpProcess::getToolsJson() const
{
    return m_toolsJson;
}

void McpProcess::onProcessStarted()
{
    setStatus(QStringLiteral("connecting"));

    QJsonObject initRequest;
    initRequest[QStringLiteral("jsonrpc")] = QStringLiteral("2.0");
    initRequest[QStringLiteral("id")] = 1;
    initRequest[QStringLiteral("method")] = QStringLiteral("initialize");

    QJsonObject params;
    params[QStringLiteral("protocolVersion")] = QStringLiteral("2025-03-26");

    QJsonObject capabilities;
    QJsonObject roots;
    roots[QStringLiteral("listChanged")] = true;
    capabilities[QStringLiteral("roots")] = roots;
    capabilities[QStringLiteral("sampling")] = QJsonObject();
    params[QStringLiteral("capabilities")] = capabilities;

    QJsonObject clientInfo;
    clientInfo[QStringLiteral("name")] = QStringLiteral("ChatQT");
    clientInfo[QStringLiteral("version")] = QStringLiteral("1.0.0");
    params[QStringLiteral("clientInfo")] = clientInfo;

    initRequest[QStringLiteral("params")] = params;

    QJsonDocument doc(initRequest);
    QByteArray data = doc.toJson(QJsonDocument::Compact) + QByteArray("\n");
    m_process->write(data);
}

void McpProcess::sendInitializedNotification()
{
    QJsonObject notification;
    notification[QStringLiteral("jsonrpc")] = QStringLiteral("2.0");
    notification[QStringLiteral("method")] = QStringLiteral("notifications/initialized");

    QJsonDocument doc(notification);
    QByteArray data = doc.toJson(QJsonDocument::Compact) + QByteArray("\n");
    m_process->write(data);
}

void McpProcess::onProcessFinished(int exitCode, QProcess::ExitStatus exitStatus)
{
    Q_UNUSED(exitCode)
    Q_UNUSED(exitStatus)
    m_initialized = false;
    setStatus(QStringLiteral("disconnected"));
}

void McpProcess::onProcessError(QProcess::ProcessError error)
{
    QString msg;
    switch (error) {
    case QProcess::FailedToStart:
        msg = QStringLiteral("Failed to start process: %1").arg(m_command);
        break;
    case QProcess::Crashed:
        msg = QStringLiteral("Process crashed");
        break;
    case QProcess::Timedout:
        msg = QStringLiteral("Process timed out");
        break;
    case QProcess::WriteError:
        msg = QStringLiteral("Write error");
        break;
    case QProcess::ReadError:
        msg = QStringLiteral("Read error");
        break;
    default:
        msg = QStringLiteral("Unknown error");
        break;
    }
    setStatus(QStringLiteral("error"));
    Q_EMIT errorOccurred(m_serverId, msg);
}

void McpProcess::onReadyReadStandardOutput()
{
    QByteArray newData = m_process->readAllStandardOutput();
    m_buffer += QString::fromUtf8(newData);
    processBuffer();
}

void McpProcess::onReadyReadStandardError()
{
    QByteArray stderrData = m_process->readAllStandardError();
    Q_UNUSED(stderrData)
}

void McpProcess::processBuffer()
{
    while (true) {
        int newlinePos = m_buffer.indexOf(QLatin1Char('\n'));
        if (newlinePos < 0) break;

        QString line = m_buffer.left(newlinePos).trimmed();
        m_buffer = m_buffer.mid(newlinePos + 1);

        if (line.isEmpty()) continue;

        QJsonParseError parseError;
        QJsonDocument doc = QJsonDocument::fromJson(line.toUtf8(), &parseError);
        if (parseError.error != QJsonParseError::NoError) {
            continue;
        }

        QJsonObject response = doc.object();

        if (!m_initialized && response.contains(QStringLiteral("result"))) {
            QJsonObject result = response[QStringLiteral("result")].toObject();
            QJsonObject serverInfo = result[QStringLiteral("serverInfo")].toObject();
            m_serverName = serverInfo[QStringLiteral("name")].toString();
            Q_EMIT serverNameChanged(m_serverName);

            m_initialized = true;
            setStatus(QStringLiteral("connected"));

            sendInitializedNotification();

            requestToolsList();
        }

        Q_EMIT messageReceived(m_serverId, line);
    }
}

void McpProcess::requestToolsList()
{
    QJsonObject request;
    request[QStringLiteral("jsonrpc")] = QStringLiteral("2.0");
    request[QStringLiteral("id")] = 2;
    request[QStringLiteral("method")] = QStringLiteral("tools/list");

    QJsonDocument doc(request);
    QByteArray data = doc.toJson(QJsonDocument::Compact) + QByteArray("\n");
    m_process->write(data);
}

// --- McpProcessManager ---

McpProcessManager* McpProcessManager::s_instance = nullptr;

McpProcessManager* McpProcessManager::instance()
{
    if (!s_instance) {
        s_instance = new McpProcessManager();
    }
    return s_instance;
}

McpProcessManager::McpProcessManager(QObject *parent)
    : QObject(parent)
{
}

McpProcessManager::~McpProcessManager()
{
    stopAll();
}

QString McpProcessManager::startProcess(const QString &serverId, const QString &command,
                                          const QStringList &args, const QVariantMap &env)
{
    if (m_processes.contains(serverId)) {
        stopProcess(serverId);
    }

    auto *process = new McpProcess(serverId, command, args, env, this);
    m_processes[serverId] = process;

    connect(process, &McpProcess::messageReceived, this, &McpProcessManager::messageReceived);
    connect(process, &McpProcess::statusChanged, this, [this, serverId](const QString &status) {
        Q_EMIT processStatusChanged(serverId, status);
    });
    connect(process, &McpProcess::errorOccurred, this, &McpProcessManager::processError);

    process->start();

    return serverId;
}

void McpProcessManager::stopProcess(const QString &serverId)
{
    if (m_processes.contains(serverId)) {
        auto *process = m_processes.take(serverId);
        process->stop();
        process->deleteLater();
    }
}

void McpProcessManager::stopAll()
{
    auto keys = m_processes.keys();
    for (const QString &id : keys) {
        stopProcess(id);
    }
}

void McpProcessManager::sendMessage(const QString &serverId, const QString &jsonMessage, int requestId)
{
    if (m_processes.contains(serverId)) {
        m_processes[serverId]->sendMessage(jsonMessage, requestId);
    }
}

QString McpProcessManager::getProcessStatus(const QString &serverId) const
{
    if (m_processes.contains(serverId)) {
        return m_processes[serverId]->status();
    }
    return QStringLiteral("disconnected");
}

int McpProcessManager::getToolCount(const QString &serverId) const
{
    if (m_processes.contains(serverId)) {
        return m_processes[serverId]->toolCount();
    }
    return 0;
}

QString McpProcessManager::getToolsJson(const QString &serverId) const
{
    if (m_processes.contains(serverId)) {
        return m_processes[serverId]->getToolsJson();
    }
    return QStringLiteral("[]");
}

bool McpProcessManager::hasProcess(const QString &serverId) const
{
    return m_processes.contains(serverId);
}