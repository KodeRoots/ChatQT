/*
    SPDX-FileCopyrightText: 2026 Denys Madureira <denys@koderoots.org>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

#include "flatpakutils.h"

#include <QFileInfo>
#include <QProcess>
#include <QCoreApplication>

namespace FlatpakUtils {

bool isInsideFlatpak()
{
    static bool cached = qEnvironmentVariableIsSet("FLATPAK_ID");
    return cached;
}

void prepareHostCommand(QString &program, QStringList &args)
{
    if (!isInsideFlatpak()) {
        return;
    }

    QStringList hostArgs;
    hostArgs.append(QStringLiteral("--host"));
    hostArgs.append(program);
    hostArgs.append(args);

    program = QStringLiteral("flatpak-spawn");
    args = hostArgs;
}

bool isHostBinaryValid(const QString &path)
{
    if (path.isEmpty()) {
        return false;
    }

    if (!isInsideFlatpak()) {
        QFileInfo info(path);
        return info.exists() && info.isExecutable();
    }

    return QFileInfo(path).isAbsolute();
}

QString resolveHostBinary(const QString &binaryName)
{
    if (!isInsideFlatpak()) {
        return QString();
    }

    QProcess whichProcess;
    whichProcess.start(QStringLiteral("flatpak-spawn"),
                       {QStringLiteral("--host"), QStringLiteral("which"), binaryName});
    if (!whichProcess.waitForFinished(5000)) {
        return QString();
    }

    if (whichProcess.exitCode() != 0) {
        return QString();
    }

    return QString::fromUtf8(whichProcess.readAllStandardOutput()).trimmed();
}

QStringList hostAutoDetect(const QStringList &candidates)
{
    if (!isInsideFlatpak()) {
        return candidates;
    }

    QStringList resolved;
    for (const QString &candidate : candidates) {
        QFileInfo info(candidate);
        QString binaryName = info.fileName();

        QString hostPath = resolveHostBinary(binaryName);
        if (!hostPath.isEmpty()) {
            resolved.append(hostPath);
        }
    }

    return resolved.isEmpty() ? candidates : resolved;
}

}
