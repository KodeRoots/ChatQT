cmake_minimum_required(VERSION 3.16)

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

find_package(Qt6 ${QT_MIN_VERSION} REQUIRED COMPONENTS
    Core
    Quick
    QuickControls2
    Widgets
    Sql
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

qt_add_executable(chatqt 
    src/main.cpp
    src/processmanager.cpp
)

qt_add_qml_module(chatqt
    URI io.github.denysmb.chatqt
    VERSION 1.0
    QML_FILES
        src/qml/main.qml
        src/qml/pages/ChatPage.qml
        src/qml/components/ChatMessage.qml
        src/qml/components/MessageInput.qml
        src/qml/components/ServerStatusIndicator.qml
        src/qml/components/ProviderCard.qml
        src/qml/settings/SettingsPage.qml
        src/qml/settings/SettingsGeneral.qml
        src/qml/settings/SettingsOpenClaw.qml
        src/qml/settings/SettingsOpenAICompatible.qml
        src/qml/settings/SettingsOpenCode.qml
        src/qml/logic/AppSettings.qml
        src/qml/logic/ApiClient.js
        src/qml/logic/OpenCodeClient.js
)

target_link_libraries(chatqt PRIVATE
    Qt6::Core
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Widgets
    Qt6::Sql
    KF6::CoreAddons
    KF6::I18n
    KF6::Kirigami
    KF6::ConfigGui
    KF6::Crash
)

target_include_directories(chatqt PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src)

install(TARGETS chatqt ${KDE_INSTALL_TARGETS_DEFAULT_ARGS})
install(FILES resources/icons/io.github.denysmb.chatqt.svg DESTINATION ${KDE_INSTALL_ICONDIR}/hicolor/scalable/apps)

feature_summary(WHAT ALL FATAL_ON_MISSING_REQUIRED_PACKAGES)