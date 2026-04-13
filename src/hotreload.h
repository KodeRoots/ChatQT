/*
    SPDX-FileCopyrightText: 2024 Denys Madureira <denysmb@zoho.com>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

#ifndef HOTRELOAD_H
#define HOTRELOAD_H

#include <QObject>
#include <QEvent>
#include <QQmlApplicationEngine>
#include <QUrl>

class QQmlApplicationEngine;
class QQuickWindow;

class HotReload : public QObject
{
    Q_OBJECT

public:
    explicit HotReload(QQmlApplicationEngine *engine, const QUrl &url, QObject *parent = nullptr);

    void setWindow(QQuickWindow *window);

protected:
    bool eventFilter(QObject *obj, QEvent *event) override;

private Q_SLOTS:
    void reload();

private:
    QQmlApplicationEngine *m_engine;
    QQuickWindow *m_window;
    QUrl m_url;
};

#endif // HOTRELOAD_H