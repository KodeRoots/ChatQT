set(QT_QML_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/src)

add_executable(chatqt)

ecm_add_qml_module(chatqt
    URI org.koderoots.chatqt
)

qt_policy(SET QTP0001 NEW)

target_sources(chatqt
    PRIVATE
    main.cpp
    processmanager.cpp
    piprocessmanager.cpp
    sessionstore.cpp
    hotreload.cpp
    mcpprocessmanager.cpp
    skillscanner.cpp
    flatpakutils.cpp
)

ecm_target_qml_sources(chatqt
    SOURCES
    qml/Main.qml
    qml/pages/ChatPage.qml
    qml/components/ChatMessage.qml
    qml/components/MessageInput.qml
    qml/components/ServerStatusIndicator.qml
    qml/components/ProviderCard.qml
    qml/components/InstanceCard.qml
    qml/components/SessionCard.qml
    qml/components/SessionSidebar.qml
    qml/components/McpCard.qml
    qml/settings/SettingsPage.qml
    qml/settings/SettingsGeneral.qml
    qml/settings/SettingsOpenClaw.qml
    qml/settings/SettingsOpenAICompatible.qml
    qml/settings/SettingsOpenCode.qml
    qml/settings/SettingsPi.qml
    qml/settings/SettingsMCP.qml
    qml/settings/SettingsSkillsMCP.qml
    qml/settings/SettingsAgent.qml
    qml/logic/AppSettings.qml
    qml/logic/ApiClient.js
    qml/logic/OpenCodeClient.js
    qml/logic/PiClient.js
    qml/logic/McpClient.js
    qml/logic/SkillManager.js
)

target_link_libraries(chatqt PRIVATE
    Qt6::Core
    Qt6::Quick
    Qt6::Qml
    Qt6::QuickControls2
    Qt6::Widgets
    Qt6::Sql
    Qt6::Network
    KF6::CoreAddons
    KF6::I18n
    KF6::Kirigami
    KF6::ConfigGui
    KF6::Crash
)

target_include_directories(chatqt PRIVATE ${CMAKE_CURRENT_SOURCE_DIR} ${CMAKE_BINARY_DIR})

install(TARGETS chatqt ${KDE_INSTALL_TARGETS_DEFAULT_ARGS})