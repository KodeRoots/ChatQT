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
#include "sessionstore.h"
#include "hotreload.h"

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
        i18n("© 2026 KodeRoots"));
    aboutData.setBugAddress("https://github.com/KodeRoots/ChatQT/issues");
    aboutData.setOrganizationDomain("koderoots.org");
    aboutData.addAuthor(
        i18nc("@info:credit", "Denys Madureira"),
        i18nc("@info:credit", "Author"),
        QStringLiteral("denys@koderoots.org"),
        QStringLiteral("https://denysmadureira.dev"));
    aboutData.setTranslator(
        i18nc("NAME OF TRANSLATORS", "Your names"),
        i18nc("EMAIL OF TRANSLATORS", "Your emails"));
    aboutData.setDesktopFileName(QStringLiteral("org.koderoots.chatqt"));
    KAboutData::setApplicationData(aboutData);

    if (qEnvironmentVariableIsEmpty("QT_QUICK_CONTROLS_STYLE")) {
        QQuickStyle::setStyle(QStringLiteral("org.kde.desktop"));
    }

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextObject(new KLocalizedContext(&engine));
    engine.rootContext()->setContextProperty(QStringLiteral("experimentalFeaturesEnabled"),
        !qEnvironmentVariableIsEmpty("CHATQT_ENABLE_EXPERIMENTAL_FEATURES"));

    qWarning() << "About to register SessionStore";
    // Register SessionStore as singleton
    qmlRegisterSingletonInstance("org.kde.chatqt", 1, 0, "SessionStore", SessionStore::instance());
    qWarning() << "SessionStore registered";

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

        qWarning() << "Root objects:" << engine.rootObjects().size();

        if (engine.rootObjects().isEmpty()) {
            return -1;
        }
    }

    return app.exec();
}
