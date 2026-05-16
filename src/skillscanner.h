/*
    SPDX-FileCopyrightText: 2026 Denys Madureira <denys@koderoots.org>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

#ifndef SKILLSCANNER_H
#define SKILLSCANNER_H

#include <QObject>
#include <QString>
#include <QStringList>
#include <QJsonArray>

class SkillScanner : public QObject
{
    Q_OBJECT

public:
    static SkillScanner* instance();

    Q_INVOKABLE QJsonArray discoverSkills(const QStringList &folders) const;
    Q_INVOKABLE QString readFile(const QString &filePath) const;
    Q_INVOKABLE QString buildSystemMessage(const QJsonArray &skills, const QString &agentContent) const;

private:
    explicit SkillScanner(QObject *parent = nullptr);
    Q_DISABLE_COPY(SkillScanner)

    QJsonObject parseFrontmatter(const QString &content) const;
    QJsonArray discoverSkillsFromFolder(const QString &folderPath) const;

    static SkillScanner *s_instance;
};

#endif // SKILLSCANNER_H
