/*
    SPDX-FileCopyrightText: 2026 Denys Madureira <denys@koderoots.org>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

#ifndef FILEHELPER_H
#define FILEHELPER_H

#include <QObject>
#include <QUrl>
#include <QVariantMap>

class FileHelper : public QObject {
  Q_OBJECT

public:
  static FileHelper *instance();

  Q_INVOKABLE QVariantMap readFile(const QUrl &url) const;

private:
  explicit FileHelper(QObject *parent = nullptr);
  Q_DISABLE_COPY(FileHelper)

  static FileHelper *s_instance;
};

#endif // FILEHELPER_H
