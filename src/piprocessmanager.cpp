/*
    SPDX-FileCopyrightText: 2026 Denys Madureira <denys@koderoots.org>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

#include "piprocessmanager.h"

#include <QStandardPaths>
#include <QDateTime>
#include <KLocalizedString>

PiProcessManager* PiProcessManager::instance()
{
    static PiProcessManager* s_instance = nullptr;
    if (!s_instance) {
        s_instance = new PiProcessManager();
    }
    return s_instance;
}

PiProcessManager::PiProcessManager(QObject *parent)
    : QObject(parent)
    , m_process(new QProcess(this))
    , m_running(false)
    , m_autoStart(false)
    , m_isStreaming(false)
{
    loadSettings();

    connect(m_process, &QProcess::started, this, &PiProcessManager::onProcessStarted);
    connect(m_process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, &PiProcessManager::onProcessFinished);
    connect(m_process, &QProcess::errorOccurred, this, &PiProcessManager::onProcessError);
    connect(m_process, &QProcess::readyReadStandardOutput, this, &PiProcessManager::onReadyReadStandardOutput);
    connect(m_process, &QProcess::readyReadStandardError, this, &PiProcessManager::onReadyReadStandardError);

    if (m_binaryPath.isEmpty()) {
        autoDetectBinary();
    }

    setStatus(QStringLiteral("stopped"));
}

PiProcessManager::~PiProcessManager()
{
    saveSettings();
    if (m_process->state() == QProcess::Running) {
        m_process->terminate();
        m_process->waitForFinished(3000);
    }
}

bool PiProcessManager::running() const
{
    return m_running;
}

QString PiProcessManager::status() const
{
    return m_status;
}

QString PiProcessManager::binaryPath() const
{
    return m_binaryPath;
}

void PiProcessManager::setBinaryPath(const QString &path)
{
    if (m_binaryPath != path) {
        m_binaryPath = path;
        Q_EMIT binaryPathChanged(path);
        saveSettings();
    }
}

QString PiProcessManager::lastError() const
{
    return m_lastError;
}

bool PiProcessManager::autoStart() const
{
    return m_autoStart;
}

void PiProcessManager::setAutoStart(bool enabled)
{
    if (m_autoStart != enabled) {
        m_autoStart = enabled;
        Q_EMIT autoStartChanged(enabled);
        saveSettings();
    }
}

bool PiProcessManager::isStreaming() const
{
    return m_isStreaming;
}

void PiProcessManager::start()
{
    if (m_running) {
        addLog(QStringLiteral("Pi is already running"));
        return;
    }

    if (m_binaryPath.isEmpty()) {
        setLastError(i18n("Pi binary path is not configured. Please set it in settings."));
        return;
    }

    QFileInfo binaryInfo(m_binaryPath);
    if (!binaryInfo.exists()) {
        setLastError(i18n("Pi binary not found at: %1").arg(m_binaryPath));
        return;
    }

    if (!binaryInfo.isExecutable()) {
        setLastError(i18n("Pi binary is not executable: %1").arg(m_binaryPath));
        return;
    }

    setStatus(QStringLiteral("starting"));
    addLog(QStringLiteral("Starting Pi in RPC mode..."));

    m_readBuffer.clear();
    setIsStreaming(false);

    m_process->setWorkingDirectory(QDir::homePath());
    m_process->setProgram(m_binaryPath);
    m_process->setArguments({QStringLiteral("--mode"), QStringLiteral("rpc"), QStringLiteral("--no-session")});

    m_process->start();
}

void PiProcessManager::stop()
{
    if (!m_running) {
        addLog(QStringLiteral("Pi is not running"));
        return;
    }

    setStatus(QStringLiteral("stopping"));
    addLog(QStringLiteral("Stopping Pi..."));

    sendCommand(QStringLiteral("{\"type\":\"new_session\"}"));

    QTimer::singleShot(500, this, [this]() {
        if (m_process->state() == QProcess::Running) {
            m_process->terminate();
            if (!m_process->waitForFinished(3000)) {
                m_process->kill();
                m_process->waitForFinished(1000);
            }
        }
    });
}

bool PiProcessManager::autoDetectBinary()
{
    QStringList searchPaths = {
        QDir::homePath() + QStringLiteral("/.npm-global/bin/pi"),
        QDir::homePath() + QStringLiteral("/.local/bin/pi"),
        QStringLiteral("/usr/bin/pi"),
        QStringLiteral("/usr/local/bin/pi")
    };

    QProcess whichProcess;
    whichProcess.start(QStringLiteral("which"), {QStringLiteral("pi")});
    if (whichProcess.waitForFinished(3000)) {
        QString whichPath = QString::fromUtf8(whichProcess.readAllStandardOutput()).trimmed();
        if (!whichPath.isEmpty()) {
            QFileInfo info(whichPath);
            if (info.exists() && info.isExecutable()) {
                searchPaths.prepend(whichPath);
            }
        }
    }

    for (const QString &path : searchPaths) {
        QFileInfo info(path);
        if (info.exists() && info.isExecutable()) {
            setBinaryPath(path);
            addLog(QStringLiteral("Auto-detected Pi binary at: %1").arg(path));
            return true;
        }
    }

    addLog(QStringLiteral("Could not auto-detect Pi binary"));
    return false;
}

bool PiProcessManager::isBinaryValid() const
{
    if (m_binaryPath.isEmpty()) {
        return false;
    }
    QFileInfo info(m_binaryPath);
    return info.exists() && info.isExecutable();
}

bool PiProcessManager::validateBinaryPath(const QString &path) const
{
    if (path.isEmpty()) {
        return false;
    }
    QFileInfo info(path);
    return info.exists() && info.isExecutable();
}

void PiProcessManager::sendCommand(const QString &jsonCommand)
{
    if (m_process->state() != QProcess::Running) {
        addLog(QStringLiteral("Cannot send command: Pi is not running"));
        return;
    }

    QByteArray data = jsonCommand.toUtf8() + "\n";
    m_process->write(data);
    addLog(QStringLiteral("→ %1").arg(jsonCommand.left(200)));
}

QStringList PiProcessManager::recentLogs(int count) const
{
    QStringList result;
    int start = qMax(0, m_logBuffer.size() - count);
    for (int i = start; i < m_logBuffer.size(); ++i) {
        result.append(m_logBuffer.at(i));
    }
    return result;
}

QStringList PiProcessManager::logs() const
{
    return m_logBuffer;
}

void PiProcessManager::onProcessStarted()
{
    setRunning(true);
    setStatus(QStringLiteral("running"));
    addLog(QStringLiteral("Pi started successfully (RPC mode)"));
    Q_EMIT runningChanged(true);
}

void PiProcessManager::onProcessFinished(int exitCode, QProcess::ExitStatus exitStatus)
{
    setRunning(false);
    setIsStreaming(false);

    QString exitReason;
    if (exitStatus == QProcess::CrashExit) {
        exitReason = QStringLiteral("crashed");
        setStatus(QStringLiteral("crashed"));
    } else {
        exitReason = QStringLiteral("exited with code %1").arg(exitCode);
        setStatus(QStringLiteral("stopped"));
    }

    addLog(QStringLiteral("Pi %1").arg(exitReason));
}

void PiProcessManager::onProcessError(QProcess::ProcessError error)
{
    QString errorMsg;

    switch (error) {
    case QProcess::FailedToStart:
        errorMsg = i18n("Failed to start Pi. Check if the binary path is correct.");
        break;
    case QProcess::Crashed:
        errorMsg = i18n("Pi crashed unexpectedly.");
        break;
    case QProcess::Timedout:
        errorMsg = i18n("Pi operation timed out.");
        break;
    case QProcess::WriteError:
        errorMsg = i18n("Error writing to Pi process.");
        break;
    case QProcess::ReadError:
        errorMsg = i18n("Error reading from Pi process.");
        break;
    default:
        errorMsg = i18n("Unknown error occurred with Pi.");
        break;
    }

    setLastError(errorMsg);
    addLog(QStringLiteral("Error: %1").arg(errorMsg));

    setRunning(false);
    setStatus(QStringLiteral("stopped"));
    Q_EMIT processError(errorMsg);
}

void PiProcessManager::onReadyReadStandardOutput()
{
    QByteArray data = m_process->readAllStandardOutput();
    m_readBuffer += data;

    while (true) {
        int newlineIndex = m_readBuffer.indexOf('\n');
        if (newlineIndex == -1) break;

        QByteArray lineData = m_readBuffer.left(newlineIndex);
        m_readBuffer = m_readBuffer.mid(newlineIndex + 1);

        if (lineData.endsWith('\r')) {
            lineData = lineData.left(lineData.size() - 1);
        }

        QString line = QString::fromUtf8(lineData).trimmed();
        if (!line.isEmpty()) {
            processLine(line);
        }
    }
}

void PiProcessManager::onReadyReadStandardError()
{
    QByteArray data = m_process->readAllStandardError();
    QString output = QString::fromUtf8(data).trimmed();
    if (!output.isEmpty()) {
        addLog(QStringLiteral("[STDERR] %1").arg(output));
    }
}

void PiProcessManager::processLine(const QString &line)
{
    addLog(QStringLiteral("← %1").arg(line.left(200)));
    Q_EMIT eventReceived(line);
}

void PiProcessManager::loadSettings()
{
    QSettings settings;
    settings.beginGroup(QStringLiteral("PiServer"));

    m_binaryPath = settings.value(QStringLiteral("binaryPath")).toString();
    m_autoStart = settings.value(QStringLiteral("autoStart"), false).toBool();

    settings.endGroup();
}

void PiProcessManager::saveSettings()
{
    QSettings settings;
    settings.beginGroup(QStringLiteral("PiServer"));

    settings.setValue(QStringLiteral("binaryPath"), m_binaryPath);
    settings.setValue(QStringLiteral("autoStart"), m_autoStart);

    settings.endGroup();
    settings.sync();
}

void PiProcessManager::addLog(const QString &log)
{
    QString timestamp = QDateTime::currentDateTime().toString(QStringLiteral("hh:mm:ss"));
    QString formattedLog = QStringLiteral("[%1] %2").arg(timestamp, log);

    m_logBuffer.append(formattedLog);

    while (m_logBuffer.size() > MAX_LOG_LINES) {
        m_logBuffer.removeFirst();
    }

    Q_EMIT logsChanged();
}

void PiProcessManager::setLastError(const QString &error)
{
    if (m_lastError != error) {
        m_lastError = error;
        Q_EMIT lastErrorChanged(error);
    }
}

void PiProcessManager::setStatus(const QString &status)
{
    if (m_status != status) {
        m_status = status;
        Q_EMIT statusChanged(status);
    }
}

void PiProcessManager::setRunning(bool running)
{
    if (m_running != running) {
        m_running = running;
        Q_EMIT runningChanged(running);
    }
}

void PiProcessManager::setIsStreaming(bool streaming)
{
    if (m_isStreaming != streaming) {
        m_isStreaming = streaming;
        Q_EMIT isStreamingChanged();
    }
}
