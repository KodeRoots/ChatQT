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
#include <QNetworkAccessManager>
#include <QNetworkReply>

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
    Q_PROPERTY(QString host READ host WRITE setHost NOTIFY hostChanged)
    Q_PROPERTY(int port READ port WRITE setPort NOTIFY portChanged)
    Q_PROPERTY(QString serverUrl READ serverUrl NOTIFY serverUrlChanged)
    Q_PROPERTY(QStringList logs READ logs NOTIFY logsChanged)

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
    Q_INVOKABLE bool validateBinaryPath(const QString &path) const;

    QString host() const;
    void setHost(const QString &host);
    int port() const;
    void setPort(int port);
    QString serverUrl() const;
    QStringList logs() const;

public Q_SLOTS:
    void cleanShutdown();

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
    void hostChanged(const QString &host);
    void portChanged(int port);
    void serverUrlChanged(const QString &url);
    void logsChanged();

private Q_SLOTS:
    void onProcessStarted();
    void onProcessFinished(int exitCode, QProcess::ExitStatus exitStatus);
    void onProcessError(QProcess::ProcessError error);
    void onReadyReadStandardOutput();
    void onReadyReadStandardError();
    void onHealthCheckTimeout();
    void onHealthCheckReply();

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
    void launchProcess();
    void performHttpHealthCheck();
    QNetworkRequest buildHealthCheckRequest() const;

    static constexpr int MAX_LOG_LINES = 100;
    static constexpr int MAX_RESTART_ATTEMPTS = 3;
    static constexpr int HEALTH_CHECK_INTERVAL_MS = 5000;
    static constexpr int GRACEFUL_SHUTDOWN_TIMEOUT_MS = 5000;
    static constexpr int RESTART_BACKOFF_BASE_MS = 1000;
    static constexpr int HEALTH_CHECK_HTTP_TIMEOUT_MS = 3000;

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
    QString m_host;
    int m_port;
    QNetworkAccessManager *m_networkManager;
    QNetworkReply *m_pendingHealthCheck;
    bool m_externalServer;
    bool m_launchOnCheckFail;
};

#endif // PROCESSMANAGER_H
