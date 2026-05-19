/*
    SPDX-FileCopyrightText: 2024 Denys Madureira <denysmb@zoho.com>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

#include "processmanager.h"

#include <QStandardPaths>
#include <QFileInfo>
#include <QCoreApplication>
#include <QDateTime>
#include <KLocalizedString>
#include <QNetworkRequest>
#include <QJsonDocument>
#include <QJsonObject>
#include "flatpakutils.h"

ProcessManager* ProcessManager::instance()
{
    static ProcessManager* s_instance = nullptr;
    if (!s_instance) {
        s_instance = new ProcessManager();
    }
    return s_instance;
}

ProcessManager::ProcessManager(QObject *parent)
    : QObject(parent)
    , m_process(new QProcess(this))
    , m_healthCheckTimer(new QTimer(this))
    , m_running(false)
    , m_autoStart(false)
    , m_autoRestart(true)
    , m_restartAttempts(0)
    , m_isShuttingDown(false)
    , m_host(QStringLiteral("127.0.0.1"))
    , m_port(4096)
    , m_networkManager(new QNetworkAccessManager(this))
    , m_pendingHealthCheck(nullptr)
    , m_externalServer(false)
    , m_launchOnCheckFail(false)
{
    loadSettings();

    connect(m_process, &QProcess::started, this, &ProcessManager::onProcessStarted);
    connect(m_process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, &ProcessManager::onProcessFinished);
    connect(m_process, &QProcess::errorOccurred, this, &ProcessManager::onProcessError);
    connect(m_process, &QProcess::readyReadStandardOutput, this, &ProcessManager::onReadyReadStandardOutput);
    connect(m_process, &QProcess::readyReadStandardError, this, &ProcessManager::onReadyReadStandardError);
    connect(m_healthCheckTimer, &QTimer::timeout, this, &ProcessManager::onHealthCheckTimeout);

    // Generate password if not set
    if (m_password.isEmpty()) {
        regeneratePassword();
    }

    // Auto-detect binary path if not set
    if (m_binaryPath.isEmpty()) {
        autoDetectBinary();
    }

    setStatus(QStringLiteral("stopped"));

    QTimer::singleShot(500, this, [this]() {
        m_launchOnCheckFail = false;
        setStatus(QStringLiteral("starting"));
        addLog(QStringLiteral("Checking for existing OpenCode server at %1:%2...").arg(m_host).arg(m_port));
        performHttpHealthCheck();
    });
}

ProcessManager::~ProcessManager()
{
    saveSettings();
}

bool ProcessManager::running() const
{
    return m_running;
}

QString ProcessManager::status() const
{
    return m_status;
}

QString ProcessManager::binaryPath() const
{
    return m_binaryPath;
}

void ProcessManager::setBinaryPath(const QString &path)
{
    if (m_binaryPath != path) {
        m_binaryPath = path;
        Q_EMIT binaryPathChanged(path);
        saveSettings();
    }
}

QString ProcessManager::password() const
{
    return m_password;
}

void ProcessManager::setPassword(const QString &password)
{
    if (m_password != password) {
        m_password = password;
        Q_EMIT passwordChanged(password);
        saveSettings();
    }
}

QString ProcessManager::lastError() const
{
    return m_lastError;
}

bool ProcessManager::autoStart() const
{
    return m_autoStart;
}

void ProcessManager::setAutoStart(bool enabled)
{
    if (m_autoStart != enabled) {
        m_autoStart = enabled;
        Q_EMIT autoStartChanged(enabled);
        saveSettings();
    }
}

bool ProcessManager::autoRestart() const
{
    return m_autoRestart;
}

void ProcessManager::setAutoRestart(bool enabled)
{
    if (m_autoRestart != enabled) {
        m_autoRestart = enabled;
        Q_EMIT autoRestartChanged(enabled);
        saveSettings();
    }
}

int ProcessManager::restartAttempts() const
{
    return m_restartAttempts;
}

QString ProcessManager::host() const
{
    return m_host;
}

void ProcessManager::setHost(const QString &host)
{
    if (m_host != host) {
        m_host = host;
        Q_EMIT hostChanged(host);
        Q_EMIT serverUrlChanged(serverUrl());
        saveSettings();
    }
}

int ProcessManager::port() const
{
    return m_port;
}

void ProcessManager::setPort(int port)
{
    if (m_port != port) {
        m_port = port;
        Q_EMIT portChanged(port);
        Q_EMIT serverUrlChanged(serverUrl());
        saveSettings();
    }
}

QString ProcessManager::serverUrl() const
{
    return QStringLiteral("http://%1:%2").arg(m_host).arg(m_port);
}

QStringList ProcessManager::logs() const
{
    return m_logBuffer;
}

void ProcessManager::start()
{
    if (m_running) {
        addLog(QStringLiteral("Server is already running"));
        return;
    }

    if (m_binaryPath.isEmpty()) {
        setLastError(i18n("OpenCode binary path is not configured. Please set it in settings."));
        return;
    }

    if (!FlatpakUtils::isHostBinaryValid(m_binaryPath)) {
        if (FlatpakUtils::isInsideFlatpak()) {
            setLastError(i18n("OpenCode binary path must be an absolute path. Current: %1").arg(m_binaryPath));
        } else {
            QFileInfo binaryInfo(m_binaryPath);
            if (!binaryInfo.exists()) {
                setLastError(i18n("OpenCode binary not found at: %1").arg(m_binaryPath));
            } else {
                setLastError(i18n("OpenCode binary is not executable: %1").arg(m_binaryPath));
            }
        }
        return;
    }

    if (m_password.isEmpty()) {
        regeneratePassword();
    }

    m_isShuttingDown = false;
    m_launchOnCheckFail = true;
    setStatus(QStringLiteral("starting"));
    addLog(QStringLiteral("Starting OpenCode server..."));
    addLog(QStringLiteral("Checking if server is already running at %1:%2...").arg(m_host).arg(m_port));

    performHttpHealthCheck();
}

void ProcessManager::stop()
{
    if (!m_running) {
        addLog(QStringLiteral("Server is not running"));
        return;
    }

    m_isShuttingDown = true;
    stopHealthCheck();

    if (m_externalServer) {
        setRunning(false);
        setStatus(QStringLiteral("stopped"));
        addLog(QStringLiteral("Disconnected from external server"));
        resetRestartAttempts();
        m_externalServer = false;
        Q_EMIT serverStopped();
        return;
    }

    setStatus(QStringLiteral("stopping"));
    addLog(QStringLiteral("Stopping OpenCode server..."));

    m_process->terminate();

    if (!m_process->waitForFinished(GRACEFUL_SHUTDOWN_TIMEOUT_MS)) {
        addLog(QStringLiteral("Server did not stop gracefully, forcing..."));
        m_process->kill();
        m_process->waitForFinished(1000);
    }

    setRunning(false);
    setStatus(QStringLiteral("stopped"));
    addLog(QStringLiteral("Server stopped"));
    resetRestartAttempts();
    Q_EMIT serverStopped();
}

void ProcessManager::launchProcess()
{
    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    env.insert(QStringLiteral("OPENCODE_SERVER_PASSWORD"), m_password);

    m_process->setProcessEnvironment(env);
    m_process->setWorkingDirectory(QDir::homePath());

    QString program = m_binaryPath;
    QStringList args = {QStringLiteral("serve"),
        QStringLiteral("--hostname"), m_host,
        QStringLiteral("--port"), QString::number(m_port)};

    FlatpakUtils::prepareHostCommand(program, args);

    m_process->setProgram(program);
    m_process->setArguments(args);

    m_process->start();
}

void ProcessManager::restart()
{
    if (m_running) {
        m_isShuttingDown = true; // Prevent auto-restart during manual restart
        stop();
    }

    // Small delay to ensure clean shutdown
    QTimer::singleShot(500, this, [this]() {
        m_isShuttingDown = false;
        start();
    });
}

bool ProcessManager::autoDetectBinary()
{
    QStringList searchPaths = {
        QDir::homePath() + QStringLiteral("/.opencode/bin/opencode"),
        QDir::homePath() + QStringLiteral("/.local/bin/opencode"),
        QStringLiteral("/usr/bin/opencode"),
        QStringLiteral("/usr/local/bin/opencode"),
        QStringLiteral("/opt/opencode/opencode")
    };

    if (FlatpakUtils::isInsideFlatpak()) {
        QStringList resolved = FlatpakUtils::hostAutoDetect(searchPaths);
        for (const QString &path : resolved) {
            setBinaryPath(path);
            addLog(QStringLiteral("Auto-detected OpenCode binary on host at: %1").arg(path));
            return true;
        }
        addLog(QStringLiteral("Could not auto-detect OpenCode binary on host"));
        return false;
    }

    for (const QString &path : searchPaths) {
        QFileInfo info(path);
        if (info.exists() && info.isExecutable()) {
            setBinaryPath(path);
            addLog(QStringLiteral("Auto-detected OpenCode binary at: %1").arg(path));
            return true;
        }
    }

    addLog(QStringLiteral("Could not auto-detect OpenCode binary"));
    return false;
}

QStringList ProcessManager::recentLogs(int count) const
{
    QStringList result;
    int start = qMax(0, m_logBuffer.size() - count);
    for (int i = start; i < m_logBuffer.size(); ++i) {
        result.append(m_logBuffer.at(i));
    }
    return result;
}

void ProcessManager::regeneratePassword()
{
    QString newPassword = QUuid::createUuid().toString(QUuid::WithoutBraces);
    setPassword(newPassword);
    addLog(QStringLiteral("Generated new server password"));
}

bool ProcessManager::isBinaryValid() const
{
    return FlatpakUtils::isHostBinaryValid(m_binaryPath);
}

bool ProcessManager::validateBinaryPath(const QString &path) const
{
    return FlatpakUtils::isHostBinaryValid(path);
}

void ProcessManager::onProcessStarted()
{
    setRunning(true);
    setStatus(QStringLiteral("running"));
    addLog(QStringLiteral("Server started successfully"));
    startHealthCheck();
    Q_EMIT serverStarted();
}

void ProcessManager::onProcessFinished(int exitCode, QProcess::ExitStatus exitStatus)
{
    stopHealthCheck();
    setRunning(false);
    m_externalServer = false;

    QString exitReason;
    if (exitStatus == QProcess::CrashExit) {
        exitReason = QStringLiteral("crashed (signal)");
        setStatus(QStringLiteral("crashed"));
    } else {
        exitReason = QStringLiteral("exited with code %1").arg(exitCode);
        setStatus(QStringLiteral("stopped"));
    }

    addLog(QStringLiteral("Server %1").arg(exitReason));

    if (!m_isShuttingDown) {
        tryAutoRestart();
        Q_EMIT serverStopped();
    }
}

void ProcessManager::onProcessError(QProcess::ProcessError error)
{
    QString errorMsg;

    switch (error) {
    case QProcess::FailedToStart:
        errorMsg = i18n("Failed to start OpenCode server. Check if the binary path is correct.");
        break;
    case QProcess::Crashed:
        errorMsg = i18n("OpenCode server crashed unexpectedly.");
        break;
    case QProcess::Timedout:
        errorMsg = i18n("OpenCode server operation timed out.");
        break;
    case QProcess::WriteError:
        errorMsg = i18n("Error writing to OpenCode server process.");
        break;
    case QProcess::ReadError:
        errorMsg = i18n("Error reading from OpenCode server process.");
        break;
    default:
        errorMsg = i18n("Unknown error occurred with OpenCode server.");
        break;
    }

    setLastError(errorMsg);
    addLog(QStringLiteral("Error: %1").arg(errorMsg));
    
    // Reset state when process fails to start
    setRunning(false);
    setStatus(QStringLiteral("stopped"));
}

void ProcessManager::onReadyReadStandardOutput()
{
    QByteArray data = m_process->readAllStandardOutput();
    QString output = QString::fromUtf8(data).trimmed();
    if (!output.isEmpty()) {
        addLog(output);
    }
}

void ProcessManager::onReadyReadStandardError()
{
    QByteArray data = m_process->readAllStandardError();
    QString output = QString::fromUtf8(data).trimmed();
    if (!output.isEmpty()) {
        addLog(QStringLiteral("[ERROR] %1").arg(output));
    }
}

void ProcessManager::onHealthCheckTimeout()
{
    if (!m_running) {
        return;
    }

    performHttpHealthCheck();
}

void ProcessManager::onHealthCheckReply()
{
    QNetworkReply *reply = m_pendingHealthCheck;
    m_pendingHealthCheck = nullptr;

    if (!reply) return;

    bool serverHealthy = false;

    if (reply->error() == QNetworkReply::NoError) {
        QByteArray data = reply->readAll();
        QJsonDocument doc = QJsonDocument::fromJson(data);
        if (!doc.isNull() && doc.object().value(QStringLiteral("healthy")).toBool()) {
            serverHealthy = true;
        }
    }

    reply->deleteLater();

    if (serverHealthy) {
        if (m_status == QStringLiteral("starting")) {
            m_externalServer = (m_process->state() != QProcess::Running);
            setRunning(true);
            setStatus(QStringLiteral("running"));
            if (m_externalServer) {
                addLog(QStringLiteral("Detected already-running OpenCode server at %1:%2").arg(m_host).arg(m_port));
            } else {
                addLog(QStringLiteral("Server is healthy"));
            }
            startHealthCheck();
            Q_EMIT serverStarted();
        }
    } else {
        if (m_status == QStringLiteral("starting")) {
            if (m_launchOnCheckFail) {
                addLog(QStringLiteral("No existing server found, launching new instance..."));
                m_launchOnCheckFail = false;
                launchProcess();
            } else {
                setStatus(QStringLiteral("stopped"));
                addLog(QStringLiteral("No existing server found"));
            }
        } else if (m_running) {
            if (m_externalServer) {
                addLog(QStringLiteral("External server no longer responding"));
                setRunning(false);
                setStatus(QStringLiteral("stopped"));
                m_externalServer = false;
                stopHealthCheck();
                Q_EMIT serverStopped();
            } else {
                addLog(QStringLiteral("Health check failed: server unresponsive"));
                setRunning(false);
                setStatus(QStringLiteral("crashed"));
                tryAutoRestart();
            }
        }
    }
}

void ProcessManager::performHttpHealthCheck()
{
    if (m_pendingHealthCheck) {
        m_pendingHealthCheck->abort();
        m_pendingHealthCheck->deleteLater();
        m_pendingHealthCheck = nullptr;
    }

    QNetworkRequest request = buildHealthCheckRequest();
    m_pendingHealthCheck = m_networkManager->get(request);

    connect(m_pendingHealthCheck, &QNetworkReply::finished,
            this, &ProcessManager::onHealthCheckReply);
}

QNetworkRequest ProcessManager::buildHealthCheckRequest() const
{
    QUrl url(QStringLiteral("http://%1:%2/global/health").arg(m_host).arg(m_port));
    QNetworkRequest request(url);
    request.setTransferTimeout(HEALTH_CHECK_HTTP_TIMEOUT_MS);
    request.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));

    if (!m_password.isEmpty()) {
        QString credentials = QStringLiteral("opencode:") + m_password;
        QByteArray authHeader = "Basic " + credentials.toUtf8().toBase64();
        request.setRawHeader("Authorization", authHeader);
    }

    return request;
}

void ProcessManager::cleanShutdown()
{
    m_isShuttingDown = true;
    stopHealthCheck();

    if (m_pendingHealthCheck) {
        m_pendingHealthCheck->abort();
        m_pendingHealthCheck->deleteLater();
        m_pendingHealthCheck = nullptr;
    }

    if (m_externalServer) {
        if (m_running) {
            setRunning(false);
        }
        setStatus(QStringLiteral("stopped"));
        m_externalServer = false;
        Q_EMIT serverStopped();
        return;
    }

    if (m_process->state() == QProcess::Running) {
        m_process->terminate();
        if (!m_process->waitForFinished(GRACEFUL_SHUTDOWN_TIMEOUT_MS)) {
            m_process->kill();
            m_process->waitForFinished(1000);
        }
    }

    if (m_running) {
        setRunning(false);
        setStatus(QStringLiteral("stopped"));
        Q_EMIT serverStopped();
    } else if (m_status != QStringLiteral("stopped")) {
        setStatus(QStringLiteral("stopped"));
    }
}

void ProcessManager::loadSettings()
{
    QSettings settings;
    settings.beginGroup(QStringLiteral("OpenCodeServer"));

    m_binaryPath = settings.value(QStringLiteral("binaryPath")).toString();
    m_password = settings.value(QStringLiteral("password")).toString();
    m_autoStart = settings.value(QStringLiteral("autoStart"), false).toBool();
    m_autoRestart = settings.value(QStringLiteral("autoRestart"), true).toBool();
    m_host = settings.value(QStringLiteral("host"), QStringLiteral("127.0.0.1")).toString();
    m_port = settings.value(QStringLiteral("port"), 4096).toInt();

    settings.endGroup();
}

void ProcessManager::saveSettings()
{
    QSettings settings;
    settings.beginGroup(QStringLiteral("OpenCodeServer"));

    settings.setValue(QStringLiteral("binaryPath"), m_binaryPath);
    settings.setValue(QStringLiteral("password"), m_password);
    settings.setValue(QStringLiteral("autoStart"), m_autoStart);
    settings.setValue(QStringLiteral("autoRestart"), m_autoRestart);
    settings.setValue(QStringLiteral("host"), m_host);
    settings.setValue(QStringLiteral("port"), m_port);

    settings.endGroup();
    settings.sync();
}

void ProcessManager::addLog(const QString &log)
{
    QString timestamp = QDateTime::currentDateTime().toString(QStringLiteral("hh:mm:ss"));
    QString formattedLog = QStringLiteral("[%1] %2").arg(timestamp, log);

    m_logBuffer.append(formattedLog);

    // Keep buffer size limited
    while (m_logBuffer.size() > MAX_LOG_LINES) {
        m_logBuffer.removeFirst();
    }

    Q_EMIT logReceived(formattedLog);
    Q_EMIT logsChanged();
}

void ProcessManager::setLastError(const QString &error)
{
    if (m_lastError != error) {
        m_lastError = error;
        Q_EMIT lastErrorChanged(error);
        Q_EMIT errorOccurred(error);
    }
}

void ProcessManager::setStatus(const QString &status)
{
    if (m_status != status) {
        m_status = status;
        Q_EMIT statusChanged(status);
    }
}

void ProcessManager::setRunning(bool running)
{
    if (m_running != running) {
        m_running = running;
        Q_EMIT runningChanged(running);
    }
}

void ProcessManager::tryAutoRestart()
{
    if (!m_autoRestart || m_isShuttingDown) {
        return;
    }

    if (m_restartAttempts >= MAX_RESTART_ATTEMPTS) {
        setLastError(i18n("Maximum restart attempts reached. Please check the server logs."));
        addLog(QStringLiteral("Max restart attempts reached (%1)").arg(MAX_RESTART_ATTEMPTS));
        resetRestartAttempts();
        return;
    }

    m_restartAttempts++;
    Q_EMIT restartAttemptsChanged(m_restartAttempts);

    // Exponential backoff: 1s, 2s, 4s
    int delay = RESTART_BACKOFF_BASE_MS * (1 << (m_restartAttempts - 1));

    addLog(QStringLiteral("Auto-restarting in %1ms (attempt %2/%3)")
           .arg(QString::number(delay), QString::number(m_restartAttempts), QString::number(MAX_RESTART_ATTEMPTS)));

    QTimer::singleShot(delay, this, [this]() {
        if (!m_running && !m_isShuttingDown) {
            start();
        }
    });
}

void ProcessManager::resetRestartAttempts()
{
    m_restartAttempts = 0;
    Q_EMIT restartAttemptsChanged(m_restartAttempts);
}

void ProcessManager::startHealthCheck()
{
    m_healthCheckTimer->start(HEALTH_CHECK_INTERVAL_MS);
}

void ProcessManager::stopHealthCheck()
{
    m_healthCheckTimer->stop();
}