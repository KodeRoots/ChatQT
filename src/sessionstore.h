/*
    SPDX-FileCopyrightText: 2026 Denys Madureira <denys@koderoots.org>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

#ifndef SESSIONSTORE_H
#define SESSIONSTORE_H

#include <QObject>
#include <QString>
#include <QVariantList>
#include <QVariantMap>
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QSqlError>
#include <QMutex>

class SessionStore : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QString currentSessionId READ currentSessionId WRITE setCurrentSessionId NOTIFY currentSessionIdChanged)

public:
    static SessionStore* instance();

    QString currentSessionId() const;
    void setCurrentSessionId(const QString &id);

    Q_INVOKABLE QString createSession(const QString &provider, const QString &model);
    Q_INVOKABLE QVariantMap getSession(const QString &sessionId) const;
    Q_INVOKABLE QVariantList listSessions() const;
    Q_INVOKABLE bool deleteSession(const QString &sessionId);
    Q_INVOKABLE bool updateSessionTitle(const QString &sessionId, const QString &title);
    Q_INVOKABLE bool updateSessionProvider(const QString &sessionId, const QString &provider, const QString &model);
    Q_INVOKABLE bool addMessage(const QString &sessionId, const QString &role, const QString &content, const QString &thinkingContent = QString());
    Q_INVOKABLE bool updateLastAssistantMessage(const QString &sessionId, const QString &content, const QString &thinkingContent = QString());
    Q_INVOKABLE bool markLastAssistantAsError(const QString &sessionId);
    Q_INVOKABLE bool finalizeLastAssistantMessage(const QString &sessionId, const QString &content, const QString &thinkingContent = QString());
    Q_INVOKABLE QVariantList loadSession(const QString &sessionId) const;
    Q_INVOKABLE QVariantMap getLastMessage(const QString &sessionId) const;
    Q_INVOKABLE QString formatRelativeTime(qint64 timestamp) const;

Q_SIGNALS:
    void currentSessionIdChanged(const QString &id);
    void sessionCreated(const QString &sessionId);
    void sessionDeleted(const QString &sessionId);
    void sessionUpdated(const QString &sessionId);
    void messageAdded(const QString &sessionId, const QString &role);
    void errorOccurred(const QString &message);

private:
    explicit SessionStore(QObject *parent = nullptr);
    ~SessionStore();
    Q_DISABLE_COPY(SessionStore)

    bool initDatabase();
    bool createTables();
    QString generateId() const;
    bool executeQuery(QSqlQuery &query) const;
    void logError(const QString &operation, const QSqlError &error) const;

    QSqlDatabase m_db;
    QString m_dbPath;
    QString m_currentSessionId;
    static SessionStore *s_instance;
};

#endif // SESSIONSTORE_H