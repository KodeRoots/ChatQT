cmake_minimum_required(VERSION 3.20)

project(chatqt VERSION 1.0.0 LANGUAGES CXX)

set(KF_MIN_VERSION "6.0.0")
set(QT_MIN_VERSION "6.5.0")

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(ECM ${KF_MIN_VERSION} REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})

include(KDEInstallDirs6)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)
include(ECMSetupVersion)
include(ECMGenerateHeaders)
include(ECMPoQmTools)
include(ECMQmlModule)

find_package(Qt6 ${QT_MIN_VERSION} REQUIRED COMPONENTS
    Core
    Quick
    QuickControls2
    Widgets
    Sql
    Network
    Qml
)

find_package(KF6 ${KF_MIN_VERSION} REQUIRED COMPONENTS
    CoreAddons
    I18n
    Kirigami
    Config
    Crash
)

find_package(KF6KirigamiAddons REQUIRED)

ecm_setup_version(${PROJECT_VERSION}
    VARIABLE_PREFIX CHATQT
    VERSION_HEADER "${CMAKE_CURRENT_BINARY_DIR}/chatqt_version.h"
)

add_subdirectory(src)

install(FILES resources/icons/org.koderoots.chatqt.svg DESTINATION ${KDE_INSTALL_ICONDIR}/hicolor/scalable/apps)
install(FILES org.koderoots.chatqt.desktop DESTINATION ${KDE_INSTALL_APPDIR})
install(FILES org.koderoots.chatqt.metainfo.xml DESTINATION ${KDE_INSTALL_METAINFODIR})

feature_summary(WHAT ALL FATAL_ON_MISSING_REQUIRED_PACKAGES)