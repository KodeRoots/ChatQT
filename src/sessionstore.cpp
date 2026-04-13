/*
    SPDX-FileCopyrightText: 2026 Denys Madureira <denys@koderoots.org>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

#include "sessionstore.h"

#include <QSqlQuery>
#include <QSqlError>
#include <QSqlRecord>
#include <QStandardPaths>
#include <QDir>
#include <QUuid>
#include <QDateTime>
#include <QMutexLocker>
#include <KLocalizedString>

SessionStore *SessionStore::s_instance = nullptr;

SessionStore::SessionStore(QObject *parent)
    : QObject(parent)
{
    if (!initDatabase()) {
        qWarning() << "SessionStore: Failed to initialize database";
    }
}

SessionStore::~SessionStore()
{
    if (m_db.isOpen()) {
        m_db.close();
    }
}

SessionStore *SessionStore::instance()
{
    if (!s_instance) {
        s_instance = new SessionStore();
    }
    return s_instance;
}

QString SessionStore::currentSessionId() const
{
    return m_currentSessionId;
}

void SessionStore::setCurrentSessionId(const QString &id)
{
    if (m_currentSessionId != id) {
        m_currentSessionId = id;
        Q_EMIT currentSessionIdChanged(id);
    }
}

bool SessionStore::initDatabase()
{
    QString dataDir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir dir(dataDir);
    if (!dir.exists()) {
        dir.mkpath(QStringLiteral("."));
    }

    m_dbPath = dataDir + QStringLiteral("/chatqt.db");

    m_db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), QStringLiteral("chatqt_sessions"));
    m_db.setDatabaseName(m_dbPath);

    if (!m_db.open()) {
        qWarning() << "SessionStore: Could not open database:" << m_db.lastError().text();
        return false;
    }

    QSqlQuery pragmaQuery(m_db);
    pragmaQuery.exec(QStringLiteral("PRAGMA journal_mode=WAL"));
    pragmaQuery.exec(QStringLiteral("PRAGMA foreign_keys=ON"));

    return createTables();
}

bool SessionStore::createTables()
{
    QSqlQuery query(m_db);

    const QString createSessions = QStringLiteral(
        "CREATE TABLE IF NOT EXISTS sessions ("
        "  id TEXT PRIMARY KEY,"
        "  title TEXT NOT NULL,"
        "  provider TEXT NOT NULL,"
        "  model TEXT NOT NULL,"
        "  created_at INTEGER NOT NULL,"
        "  updated_at INTEGER NOT NULL"
        ")"
    );

    const QString createMessages = QStringLiteral(
        "CREATE TABLE IF NOT EXISTS messages ("
        "  id INTEGER PRIMARY KEY AUTOINCREMENT,"
        "  session_id TEXT NOT NULL,"
        "  role TEXT NOT NULL,"
        "  content TEXT NOT NULL,"
        "  thinking_content TEXT DEFAULT '',"
        "  created_at INTEGER NOT NULL,"
        "  FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE CASCADE"
        ")"
    );

    const QString createIndex = QStringLiteral(
        "CREATE INDEX IF NOT EXISTS idx_messages_session ON messages(session_id, created_at)"
    );

    if (!query.exec(createSessions)) {
        logError(QStringLiteral("createSessions"), query.lastError());
        return false;
    }
    if (!query.exec(createMessages)) {
        logError(QStringLiteral("createMessages"), query.lastError());
        return false;
    }
    if (!query.exec(createIndex)) {
        logError(QStringLiteral("createIndex"), query.lastError());
        return false;
    }

    return true;
}

QString SessionStore::generateId() const
{
    return QUuid::createUuid().toString(QUuid::WithoutBraces);
}

bool SessionStore::executeQuery(QSqlQuery &query) const
{
    if (!query.exec()) {
        logError(query.executedQuery().isEmpty() ? QStringLiteral("executeQuery") : query.executedQuery(), query.lastError());
        return false;
    }
    return true;
}

void SessionStore::logError(const QString &operation, const QSqlError &error) const
{
    qWarning() << "SessionStore::" << operation << "error:" << error.text();
    const_cast<SessionStore*>(this)->Q_EMIT errorOccurred(error.text());
}

QString SessionStore::createSession(const QString &provider, const QString &model)
{
    QSqlQuery query(m_db);
    query.prepare(QStringLiteral(
        "INSERT INTO sessions (id, title, provider, model, created_at, updated_at) "
        "VALUES (?, ?, ?, ?, ?, ?)"
    ));

    const QString id = generateId();
    const qint64 now = QDateTime::currentMSecsSinceEpoch();

    query.addBindValue(id);
    query.addBindValue(QStringLiteral("New Chat"));
    query.addBindValue(provider);
    query.addBindValue(model);
    query.addBindValue(now);
    query.addBindValue(now);

    if (!executeQuery(query)) {
        return QString();
    }

    m_currentSessionId = id;
    Q_EMIT currentSessionIdChanged(id);
    Q_EMIT sessionCreated(id);
    return id;
}

QVariantMap SessionStore::getSession(const QString &sessionId) const
{
    QSqlQuery query(m_db);
    query.prepare(QStringLiteral(
        "SELECT id, title, provider, model, created_at, updated_at FROM sessions WHERE id = ?"
    ));
    query.addBindValue(sessionId);

    QVariantMap result;
    if (query.exec() && query.next()) {
        result[QStringLiteral("id")] = query.value(0);
        result[QStringLiteral("title")] = query.value(1);
        result[QStringLiteral("provider")] = query.value(2);
        result[QStringLiteral("model")] = query.value(3);
        result[QStringLiteral("created_at")] = query.value(4);
        result[QStringLiteral("updated_at")] = query.value(5);
    }
    return result;
}

QVariantList SessionStore::listSessions() const
{
    QSqlQuery query(m_db);
    query.prepare(QStringLiteral(
        "SELECT id, title, provider, model, created_at, updated_at FROM sessions ORDER BY updated_at DESC"
    ));

    QVariantList sessions;
    if (query.exec()) {
        while (query.next()) {
            QVariantMap session;
            session[QStringLiteral("id")] = query.value(0);
            session[QStringLiteral("title")] = query.value(1);
            session[QStringLiteral("provider")] = query.value(2);
            session[QStringLiteral("model")] = query.value(3);
            session[QStringLiteral("created_at")] = query.value(4);
            session[QStringLiteral("updated_at")] = query.value(5);
            sessions.append(session);
        }
    } else {
        logError(QStringLiteral("listSessions"), query.lastError());
    }
    return sessions;
}

bool SessionStore::deleteSession(const QString &sessionId)
{
    {
        QSqlQuery query(m_db);
        query.prepare(QStringLiteral("DELETE FROM messages WHERE session_id = ?"));
        query.addBindValue(sessionId);
        if (!executeQuery(query)) {
            return false;
        }
    }
    {
        QSqlQuery query(m_db);
        query.prepare(QStringLiteral("DELETE FROM sessions WHERE id = ?"));
        query.addBindValue(sessionId);
        if (!executeQuery(query)) {
            return false;
        }
    }

    if (m_currentSessionId == sessionId) {
        m_currentSessionId.clear();
        Q_EMIT currentSessionIdChanged(QString());
    }

    Q_EMIT sessionDeleted(sessionId);
    return true;
}

bool SessionStore::updateSessionTitle(const QString &sessionId, const QString &title)
{
    QSqlQuery query(m_db);
    query.prepare(QStringLiteral("UPDATE sessions SET title = ? WHERE id = ?"));
    query.addBindValue(title);
    query.addBindValue(sessionId);

    if (!executeQuery(query)) {
        return false;
    }

    Q_EMIT sessionUpdated(sessionId);
    return true;
}

bool SessionStore::updateSessionProvider(const QString &sessionId, const QString &provider, const QString &model)
{
    QSqlQuery query(m_db);
    query.prepare(QStringLiteral("UPDATE sessions SET provider = ?, model = ? WHERE id = ?"));
    query.addBindValue(provider);
    query.addBindValue(model);
    query.addBindValue(sessionId);

    if (!executeQuery(query)) {
        return false;
    }

    Q_EMIT sessionUpdated(sessionId);
    return true;
}

bool SessionStore::addMessage(const QString &sessionId, const QString &role, const QString &content, const QString &thinkingContent)
{
    QSqlQuery query(m_db);
    query.prepare(QStringLiteral(
        "INSERT INTO messages (session_id, role, content, thinking_content, created_at) "
        "VALUES (?, ?, ?, ?, ?)"
    ));

    const qint64 now = QDateTime::currentMSecsSinceEpoch();
    query.addBindValue(sessionId);
    query.addBindValue(role);
    query.addBindValue(content);
    query.addBindValue(thinkingContent);
    query.addBindValue(now);

    if (!executeQuery(query)) {
        return false;
    }

    QSqlQuery updateQuery(m_db);
    updateQuery.prepare(QStringLiteral("UPDATE sessions SET updated_at = ? WHERE id = ?"));
    updateQuery.addBindValue(now);
    updateQuery.addBindValue(sessionId);
    executeQuery(updateQuery);

    Q_EMIT messageAdded(sessionId, role);
    Q_EMIT sessionUpdated(sessionId);
    return true;
}

bool SessionStore::updateLastAssistantMessage(const QString &sessionId, const QString &content, const QString &thinkingContent)
{
    QSqlQuery query(m_db);
    query.prepare(QStringLiteral(
        "UPDATE messages SET content = ?, thinking_content = ? "
        "WHERE session_id = ? AND role = 'assistant' "
        "ORDER BY created_at DESC LIMIT 1"
    ));
    query.addBindValue(content);
    query.addBindValue(thinkingContent);
    query.addBindValue(sessionId);

    if (!executeQuery(query)) {
        return false;
    }
    return true;
}

bool SessionStore::finalizeLastAssistantMessage(const QString &sessionId, const QString &content, const QString &thinkingContent)
{
    QSqlQuery findQuery(m_db);
    findQuery.prepare(QStringLiteral(
        "SELECT id FROM messages WHERE session_id = ? AND role = 'assistant' ORDER BY created_at DESC LIMIT 1"
    ));
    findQuery.addBindValue(sessionId);

    if (!findQuery.exec() || !findQuery.next()) {
        QSqlQuery query(m_db);
        query.prepare(QStringLiteral(
            "INSERT INTO messages (session_id, role, content, thinking_content, created_at) "
            "VALUES (?, 'assistant', ?, ?, ?)"
        ));
        const qint64 now = QDateTime::currentMSecsSinceEpoch();
        query.addBindValue(sessionId);
        query.addBindValue(content);
        query.addBindValue(thinkingContent);
        query.addBindValue(now);
        if (!executeQuery(query)) {
            return false;
        }
    } else {
        QSqlQuery query(m_db);
        query.prepare(QStringLiteral(
            "UPDATE messages SET content = ?, thinking_content = ? WHERE id = ?"
        ));
        query.addBindValue(content);
        query.addBindValue(thinkingContent);
        query.addBindValue(findQuery.value(0));
        if (!executeQuery(query)) {
            return false;
        }
    }

    const qint64 now = QDateTime::currentMSecsSinceEpoch();
    QSqlQuery updateQuery(m_db);
    updateQuery.prepare(QStringLiteral("UPDATE sessions SET updated_at = ? WHERE id = ?"));
    updateQuery.addBindValue(now);
    updateQuery.addBindValue(sessionId);
    executeQuery(updateQuery);

    Q_EMIT sessionUpdated(sessionId);
    return true;
}

QVariantList SessionStore::loadSession(const QString &sessionId) const
{
    QSqlQuery query(m_db);
    query.prepare(QStringLiteral(
        "SELECT role, content, thinking_content, created_at FROM messages "
        "WHERE session_id = ? ORDER BY created_at ASC"
    ));
    query.addBindValue(sessionId);

    QVariantList messages;
    if (query.exec()) {
        while (query.next()) {
            QVariantMap msg;
            msg[QStringLiteral("role")] = query.value(0);
            msg[QStringLiteral("content")] = query.value(1);
            msg[QStringLiteral("thinkingContent")] = query.value(2);
            msg[QStringLiteral("createdAt")] = query.value(3);
            messages.append(msg);
        }
    } else {
        logError(QStringLiteral("loadSession"), query.lastError());
    }
    return messages;
}

QVariantMap SessionStore::getLastMessage(const QString &sessionId) const
{
    QSqlQuery query(m_db);
    query.prepare(QStringLiteral(
        "SELECT role, content, thinking_content, created_at FROM messages "
        "WHERE session_id = ? ORDER BY created_at DESC LIMIT 1"
    ));
    query.addBindValue(sessionId);

    QVariantMap result;
    if (query.exec() && query.next()) {
        result[QStringLiteral("role")] = query.value(0);
        result[QStringLiteral("content")] = query.value(1);
        result[QStringLiteral("thinkingContent")] = query.value(2);
        result[QStringLiteral("createdAt")] = query.value(3);
    }
    return result;
}

QString SessionStore::formatRelativeTime(qint64 timestamp) const
{
    const qint64 now = QDateTime::currentMSecsSinceEpoch();
    const qint64 diffMs = now - timestamp;
    const qint64 diffSecs = diffMs / 1000;

    if (diffSecs < 60) {
        return i18n("Just now");
    } else if (diffSecs < 3600) {
        const int mins = diffSecs / 60;
        return i18np("%1 min ago", "%1 mins ago", mins);
    } else if (diffSecs < 86400) {
        const int hours = diffSecs / 3600;
        return i18np("%1 hour ago", "%1 hours ago", hours);
    } else if (diffSecs < 172800) {
        return i18n("Yesterday");
    } else {
        const int days = diffSecs / 86400;
        return i18np("%1 day ago", "%1 days ago", days);
    }
}