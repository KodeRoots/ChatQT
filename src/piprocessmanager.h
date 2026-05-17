/*
    SPDX-FileCopyrightText: 2026 Denys Madureira <denys@koderoots.org>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

#ifndef PIPROCESSMANAGER_H
#define PIPROCESSMANAGER_H

#include <QObject>
#include <QProcess>
#include <QString>
#include <QStringList>
#include <QTimer>
#include <QSettings>
#include <QDir>
#include <QFileInfo>

class PiProcessManager : public QObject
{
    Q_OBJECT

    Q_PROPERTY(bool running READ running NOTIFY runningChanged)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
    Q_PROPERTY(QString binaryPath READ binaryPath WRITE setBinaryPath NOTIFY binaryPathChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY lastErrorChanged)
    Q_PROPERTY(bool autoStart READ autoStart WRITE setAutoStart NOTIFY autoStartChanged)
    Q_PROPERTY(QStringList logs READ logs NOTIFY logsChanged)
    Q_PROPERTY(bool isStreaming READ isStreaming NOTIFY isStreamingChanged)

public:
    static PiProcessManager* instance();

    bool running() const;
    QString status() const;
    QString binaryPath() const;
    void setBinaryPath(const QString &path);
    QString lastError() const;
    bool autoStart() const;
    void setAutoStart(bool enabled);
    bool isStreaming() const;

    Q_INVOKABLE void start();
    Q_INVOKABLE void stop();
    Q_INVOKABLE bool autoDetectBinary();
    Q_INVOKABLE bool isBinaryValid() const;
    Q_INVOKABLE bool validateBinaryPath(const QString &path) const;
    Q_INVOKABLE void sendCommand(const QString &jsonCommand);
    Q_INVOKABLE QStringList recentLogs(int count = 50) const;
    QStringList logs() const;

Q_SIGNALS:
    void runningChanged(bool running);
    void statusChanged(const QString &status);
    void binaryPathChanged(const QString &path);
    void lastErrorChanged(const QString &error);
    void autoStartChanged(bool enabled);
    void logsChanged();
    void isStreamingChanged();
    void eventReceived(const QString &jsonEvent);
    void processError(const QString &error);

private Q_SLOTS:
    void onProcessStarted();
    void onProcessFinished(int exitCode, QProcess::ExitStatus exitStatus);
    void onProcessError(QProcess::ProcessError error);
    void onReadyReadStandardOutput();
    void onReadyReadStandardError();

private:
    explicit PiProcessManager(QObject *parent = nullptr);
    ~PiProcessManager();
    Q_DISABLE_COPY(PiProcessManager)

    void loadSettings();
    void saveSettings();
    void addLog(const QString &log);
    void setLastError(const QString &error);
    void setStatus(const QString &status);
    void setRunning(bool running);
    void setIsStreaming(bool streaming);
    void processLine(const QString &line);

    static constexpr int MAX_LOG_LINES = 100;

    QProcess *m_process;
    QString m_binaryPath;
    QString m_lastError;
    QString m_status;
    bool m_running;
    bool m_autoStart;
    bool m_isStreaming;
    QStringList m_logBuffer;
    QByteArray m_readBuffer;
};

#endif // PIPROCESSMANAGER_H
