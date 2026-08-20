/*
    SPDX-FileCopyrightText: 2026 Denys Madureira <denys@koderoots.org>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

#include "filehelper.h"

#include <QFile>
#include <QFileInfo>
#include <QMimeDatabase>
#include <QMimeType>

namespace {
constexpr qint64 MAX_FILE_SIZE = 5 * 1024 * 1024;
}

FileHelper *FileHelper::s_instance = nullptr;

FileHelper::FileHelper(QObject *parent) : QObject(parent) {}

FileHelper *FileHelper::instance() {
  if (!s_instance) {
    s_instance = new FileHelper();
  }
  return s_instance;
}

QVariantMap FileHelper::readFile(const QUrl &url) const {
  QVariantMap result;
  result[QStringLiteral("success")] = false;

  const QString path = url.toLocalFile();
  const QFileInfo info(path);
  result[QStringLiteral("name")] = info.fileName();

  if (!info.exists() || !info.isFile()) {
    result[QStringLiteral("error")] = QStringLiteral("file not found");
    return result;
  }

  if (info.size() > MAX_FILE_SIZE) {
    result[QStringLiteral("error")] =
        QStringLiteral("file is too large (max 5 MB)");
    return result;
  }

  QFile file(path);
  if (!file.open(QIODevice::ReadOnly)) {
    result[QStringLiteral("error")] = QStringLiteral("could not open file");
    return result;
  }

  const QByteArray data = file.readAll();
  const QMimeDatabase db;
  const QMimeType mime = db.mimeTypeForFileNameAndData(info.fileName(), data);
  const QString mimeName = mime.name();
  result[QStringLiteral("mime")] = mimeName;

  if (mimeName.startsWith(QStringLiteral("image/"))) {
    result[QStringLiteral("isImage")] = true;
    result[QStringLiteral("content")] = QString::fromLatin1(data.toBase64());
    result[QStringLiteral("success")] = true;
    return result;
  }

  if (mimeName.startsWith(QStringLiteral("text/")) ||
      mime.inherits(QStringLiteral("text/plain"))) {
    result[QStringLiteral("isImage")] = false;
    result[QStringLiteral("content")] = QString::fromUtf8(data);
    result[QStringLiteral("success")] = true;
    return result;
  }

  result[QStringLiteral("error")] =
      QStringLiteral("unsupported file type: %1").arg(mimeName);
  return result;
}
