/*
    SPDX-FileCopyrightText: 2026 Denys Madureira <denys@koderoots.org>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

#ifndef FLATPAKUTILS_H
#define FLATPAKUTILS_H

#include <QString>
#include <QStringList>

namespace FlatpakUtils {

bool isInsideFlatpak();

void prepareHostCommand(QString &program, QStringList &args);

bool isHostBinaryValid(const QString &path);

QString resolveHostBinary(const QString &binaryName);

QStringList hostAutoDetect(const QStringList &candidates);

}

#endif // FLATPAKUTILS_H
