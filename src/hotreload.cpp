/*
    SPDX-FileCopyrightText: 2024 Denys Madureira <denysmb@zoho.com>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

#include "hotreload.h"

#include <QQmlApplicationEngine>
#include <QQuickItem>
#include <QQuickWindow>
#include <QKeyEvent>
#include <QGuiApplication>

HotReload::HotReload(QQmlApplicationEngine *engine, const QUrl &url, QObject *parent)
    : QObject(parent)
    , m_engine(engine)
    , m_window(nullptr)
    , m_url(url)
{
}

void HotReload::setWindow(QQuickWindow *window)
{
    m_window = window;
    if (m_window) {
        m_window->installEventFilter(this);
    }
}

bool HotReload::eventFilter(QObject *obj, QEvent *event)
{
    if (event->type() == QEvent::KeyPress) {
        auto *keyEvent = static_cast<QKeyEvent *>(event);
        if (keyEvent->modifiers() == Qt::ControlModifier && keyEvent->key() == Qt::Key_R) {
            reload();
            return true;
        }
    }
    return QObject::eventFilter(obj, event);
}

void HotReload::reload()
{
    if (!m_engine) return;

    const auto rootObjects = m_engine->rootObjects();
    for (auto *obj : rootObjects) {
        if (obj == m_window) {
            m_window->removeEventFilter(this);
            m_window = nullptr;
        }
        delete obj;
    }

    m_engine->clearComponentCache();

    m_engine->load(m_url);

    if (m_engine->rootObjects().isEmpty()) {
        qWarning() << "HotReload: failed to reload QML from" << m_url;
        QGuiApplication::exit(-1);
        return;
    }

    auto *newWindow = qobject_cast<QQuickWindow *>(m_engine->rootObjects().first());
    if (newWindow) {
        setWindow(newWindow);
    }
}