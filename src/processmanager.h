/*
    SPDX-FileCopyrightText: 2024 Denys Madureira <denysmb@zoho.com>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

#ifndef PROCESSMANAGER_H
#define PROCESSMANAGER_H

#include <QObject>
#include <QProcess>
#include <QString>
#include <QStringList>
#include <QTimer>
#include <QSettings>
#include <QUuid>
#include <QDir>

class ProcessManager : public QObject
{
    Q_OBJECT

    Q_PROPERTY(bool running READ running NOTIFY runningChanged)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
    Q_PROPERTY(QString binaryPath READ binaryPath WRITE setBinaryPath NOTIFY binaryPathChanged)
    Q_PROPERTY(QString password READ password WRITE setPassword NOTIFY passwordChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY lastErrorChanged)
    Q_PROPERTY(bool autoStart READ autoStart WRITE setAutoStart NOTIFY autoStartChanged)
    Q_PROPERTY(bool autoRestart READ autoRestart WRITE setAutoRestart NOTIFY autoRestartChanged)
    Q_PROPERTY(int restartAttempts READ restartAttempts NOTIFY restartAttemptsChanged)

public:
    static ProcessManager* instance();

    bool running() const;
    QString status() const;
    QString binaryPath() const;
    void setBinaryPath(const QString &path);
    QString password() const;
    void setPassword(const QString &password);
    QString lastError() const;
    bool autoStart() const;
    void setAutoStart(bool enabled);
    bool autoRestart() const;
    void setAutoRestart(bool enabled);
    int restartAttempts() const;

    Q_INVOKABLE void start();
    Q_INVOKABLE void stop();
    Q_INVOKABLE void restart();
    Q_INVOKABLE bool autoDetectBinary();
    Q_INVOKABLE QStringList recentLogs(int count = 50) const;
    Q_INVOKABLE void regeneratePassword();
    Q_INVOKABLE bool isBinaryValid() const;

Q_SIGNALS:
    void runningChanged(bool running);
    void statusChanged(const QString &status);
    void binaryPathChanged(const QString &path);
    void passwordChanged(const QString &password);
    void lastErrorChanged(const QString &error);
    void autoStartChanged(bool enabled);
    void autoRestartChanged(bool enabled);
    void restartAttemptsChanged(int attempts);
    void logReceived(const QString &log);
    void serverStarted();
    void serverStopped();
    void errorOccurred(const QString &error);

private Q_SLOTS:
    void onProcessStarted();
    void onProcessFinished(int exitCode, QProcess::ExitStatus exitStatus);
    void onProcessError(QProcess::ProcessError error);
    void onReadyReadStandardOutput();
    void onReadyReadStandardError();
    void onHealthCheckTimeout();

private:
    explicit ProcessManager(QObject *parent = nullptr);
    ~ProcessManager();
    Q_DISABLE_COPY(ProcessManager)

    void loadSettings();
    void saveSettings();
    void addLog(const QString &log);
    void setLastError(const QString &error);
    void setStatus(const QString &status);
    void setRunning(bool running);
    void tryAutoRestart();
    void resetRestartAttempts();
    void startHealthCheck();
    void stopHealthCheck();

    static constexpr int MAX_LOG_LINES = 100;
    static constexpr int MAX_RESTART_ATTEMPTS = 3;
    static constexpr int HEALTH_CHECK_INTERVAL_MS = 5000;
    static constexpr int GRACEFUL_SHUTDOWN_TIMEOUT_MS = 5000;
    static constexpr int RESTART_BACKOFF_BASE_MS = 1000;

    QProcess *m_process;
    QTimer *m_healthCheckTimer;
    QStringList m_logBuffer;
    QString m_binaryPath;
    QString m_password;
    QString m_lastError;
    QString m_status;
    bool m_running;
    bool m_autoStart;
    bool m_autoRestart;
    int m_restartAttempts;
    bool m_isShuttingDown;
};

#endif // PROCESSMANAGER_H