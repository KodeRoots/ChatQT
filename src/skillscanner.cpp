/*
    SPDX-FileCopyrightText: 2026 Denys Madureira <denys@koderoots.org>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

#include "skillscanner.h"

#include <QDir>
#include <QFile>
#include <QTextStream>
#include <QJsonObject>
#include <QJsonDocument>
#include <QSet>

SkillScanner *SkillScanner::s_instance = nullptr;

SkillScanner::SkillScanner(QObject *parent)
    : QObject(parent)
{
}

SkillScanner *SkillScanner::instance()
{
    if (!s_instance) {
        s_instance = new SkillScanner();
    }
    return s_instance;
}

QJsonObject SkillScanner::parseFrontmatter(const QString &content) const
{
    QJsonObject result;
    result[QStringLiteral("name")] = QString();
    result[QStringLiteral("description")] = QString();

    if (!content.startsWith(QStringLiteral("---"))) {
        return result;
    }

    int endIndex = content.indexOf(QStringLiteral("---"), 3);
    if (endIndex == -1) {
        return result;
    }

    QString frontmatter = content.mid(3, endIndex - 3).trimmed();
    QStringList lines = frontmatter.split(QLatin1Char('\n'));

    for (const QString &line : lines) {
        QString trimmed = line.trimmed();
        int colonIndex = trimmed.indexOf(QLatin1Char(':'));
        if (colonIndex == -1) continue;

        QString key = trimmed.left(colonIndex).trimmed();
        QString value = trimmed.mid(colonIndex + 1).trimmed();

        if (key == QLatin1String("name")) {
            result[QStringLiteral("name")] = value;
        } else if (key == QLatin1String("description")) {
            result[QStringLiteral("description")] = value;
        }
    }

    return result;
}

QJsonArray SkillScanner::discoverSkillsFromFolder(const QString &folderPath) const
{
    QJsonArray skills;

    QDir dir(folderPath);
    if (!dir.exists()) {
        return skills;
    }

    QStringList subdirs = dir.entryList(QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name);

    for (const QString &subdirName : subdirs) {
        QString skillMdPath = folderPath + QLatin1Char('/') + subdirName + QStringLiteral("/SKILL.md");

        QFile file(skillMdPath);
        if (!file.exists()) continue;

        if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) continue;

        QTextStream in(&file);
        QString content = in.readAll();
        file.close();

        QJsonObject meta = parseFrontmatter(content);
        QString name = meta[QStringLiteral("name")].toString();
        QString description = meta[QStringLiteral("description")].toString();

        if (name.isEmpty() && description.isEmpty()) {
            name = subdirName;
        }

        if (!name.isEmpty()) {
            QJsonObject skill;
            skill[QStringLiteral("name")] = name;
            skill[QStringLiteral("description")] = description;
            skill[QStringLiteral("folder")] = folderPath;
            skill[QStringLiteral("directoryName")] = subdirName;
            skill[QStringLiteral("filePath")] = skillMdPath;
            skills.append(skill);
        }
    }

    return skills;
}

QJsonArray SkillScanner::discoverSkills(const QStringList &folders) const
{
    QJsonArray allSkills;
    QSet<QString> seen;

    for (const QString &folder : folders) {
        QString cleanPath = folder.trimmed();
        if (cleanPath.isEmpty()) continue;

        if (cleanPath.startsWith(QLatin1String("~"))) {
            cleanPath = QDir::homePath() + cleanPath.mid(1);
        }

        QJsonArray folderSkills = discoverSkillsFromFolder(cleanPath);

        for (const QJsonValue &value : folderSkills) {
            QJsonObject skill = value.toObject();
            QString name = skill[QStringLiteral("name")].toString();
            if (!seen.contains(name)) {
                allSkills.append(skill);
                seen.insert(name);
            }
        }
    }

    return allSkills;
}

QString SkillScanner::readFile(const QString &filePath) const
{
    if (filePath.isEmpty()) return QString();

    QString cleanPath = filePath.trimmed();
    if (cleanPath.startsWith(QLatin1String("~"))) {
        cleanPath = QDir::homePath() + cleanPath.mid(1);
    }

    QFile file(cleanPath);
    if (!file.exists()) return QString();

    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) return QString();

    QTextStream in(&file);
    QString content = in.readAll();
    file.close();

    return content;
}

QString SkillScanner::buildSystemMessage(const QJsonArray &skills, const QString &agentContent) const
{
    QStringList parts;

    if (!skills.isEmpty()) {
        QStringList skillLines;
        skillLines << QStringLiteral("Available skills (use when the task matches):");

        for (const QJsonValue &value : skills) {
            QJsonObject skill = value.toObject();
            QString name = skill[QStringLiteral("name")].toString();
            QString description = skill[QStringLiteral("description")].toString();

            QString line = QStringLiteral("- ") + name;
            if (!description.isEmpty()) {
                line += QLatin1String(": ") + description;
            }
            skillLines << line;
        }

        parts << skillLines.join(QLatin1Char('\n'));
    }

    if (!agentContent.isEmpty()) {
        parts << QStringLiteral("Agent instructions:\n") + agentContent;
    }

    return parts.join(QStringLiteral("\n\n"));
}
