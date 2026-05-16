/*
    SPDX-FileCopyrightText: 2024 Denys Madureira <denysmb@zoho.com>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

#include <QApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQmlError>
#include <QQuickStyle>
#include <QIcon>
#include <QUrl>
#include <QQmlEngine>
#include <QQuickWindow>

#include <KAboutData>
#include <KLocalizedContext>
#include <KLocalizedString>
#include <KCrash>

#include "chatqt_version.h"
#include "processmanager.h"
#include "sessionstore.h"
#include "hotreload.h"
#include "mcpprocessmanager.h"
#include "skillscanner.h"

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    app.setWindowIcon(QIcon::fromTheme(QStringLiteral("org.koderoots.chatqt")));

    KCrash::initialize();
    KLocalizedString::setApplicationDomain("chatqt");

    KAboutData aboutData(
        QStringLiteral("chatqt"),
        i18nc("@title", "ChatQT"),
        QStringLiteral(CHATQT_VERSION_STRING),
        i18n("A simple AI chat client for OpenAI-compatible providers"),
        KAboutLicense::LGPL_V2_1,
        i18n("(c) 2024 Denys Madureira")
    );
    aboutData.addAuthor(i18nc("@info:credit", "Denys Madureira"), QString(), QStringLiteral("denysmb@zoho.com"));
    aboutData.setDesktopFileName(QStringLiteral("org.koderoots.chatqt"));
    KAboutData::setApplicationData(aboutData);

    if (qEnvironmentVariableIsEmpty("QT_QUICK_CONTROLS_STYLE")) {
        QQuickStyle::setStyle(QStringLiteral("org.kde.desktop"));
    }

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextObject(new KLocalizedContext(&engine));

    // Register ProcessManager as singleton
    qmlRegisterSingletonInstance("org.kde.chatqt", 1, 0, "ProcessManager", ProcessManager::instance());

    // Register SessionStore as singleton
    qmlRegisterSingletonInstance("org.kde.chatqt", 1, 0, "SessionStore", SessionStore::instance());

    // Register McpProcessManager as singleton
    qmlRegisterSingletonInstance("org.kde.chatqt", 1, 0, "McpProcessManager", McpProcessManager::instance());

    // Register SkillScanner as singleton
    qmlRegisterSingletonInstance("org.kde.chatqt", 1, 0, "SkillScanner", SkillScanner::instance());

    QObject::connect(&app, &QApplication::aboutToQuit,
                     ProcessManager::instance(), &ProcessManager::cleanShutdown);

    QObject::connect(&engine, &QQmlApplicationEngine::warnings, [](const QList<QQmlError> &warnings) {
        for (const QQmlError &warning : warnings) {
            qWarning() << "QML Warning:" << warning.toString();
        }
    });

    QString qmlSourceDir = qEnvironmentVariable("QML_SRC_DIR");
    if (!qmlSourceDir.isEmpty()) {
        QString path = qmlSourceDir + QStringLiteral("/main.qml");
        QUrl url = QUrl::fromLocalFile(path);
        engine.addImportPath(qmlSourceDir);

        QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
                         &app, [url](QObject *obj, const QUrl &objUrl) {
            if (!obj && url == objUrl) {
                QCoreApplication::exit(-1);
            }
        }, Qt::QueuedConnection);
        engine.load(url);

        if (engine.rootObjects().isEmpty()) {
            return -1;
        }

        auto *hotReload = new HotReload(&engine, url, &app);
        auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
        if (window) {
            hotReload->setWindow(window);
        }
    } else {
        engine.loadFromModule("org.koderoots.chatqt", "Main");

        if (engine.rootObjects().isEmpty()) {
            return -1;
        }
    }

    return app.exec();
}