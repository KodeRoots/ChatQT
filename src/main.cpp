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

#include <KAboutData>
#include <KLocalizedContext>
#include <KLocalizedString>
#include <KCrash>

#include "chatqt_version.h"
#include "processmanager.h"

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

    QObject::connect(&engine, &QQmlApplicationEngine::warnings, [](const QList<QQmlError> &warnings) {
        for (const QQmlError &warning : warnings) {
            qWarning() << "QML Warning:" << warning.toString();
        }
    });

    const QUrl url(QStringLiteral("qrc:/org/koderoots/chatqt/src/qml/main.qml"));
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

    return app.exec();
}