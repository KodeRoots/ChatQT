/*
    SPDX-FileCopyrightText: 2024 Denys Madureira <denysmb@zoho.com>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

import QtQuick
import QtCore
import org.kde.chatqt

QtObject {
    id: settings

    property string provider: _settings.value("provider", "ollama")
    property string openclawUrl: _settings.value("openclawUrl", "http://127.0.0.1:18789")
    property string openclawToken: _settings.value("openclawToken", "")
    property string openaiCompatibleUrl: _settings.value("openaiCompatibleUrl", "")
    property string openaiCompatibleToken: _settings.value("openaiCompatibleToken", "")
    property string openaiCompatibleModel: _settings.value("openaiCompatibleModel", "")
    property string openaiCompatibleProviders: _settings.value("openaiCompatibleProviders", "[]")
    property string selectedOpenAICompatibleProviderId: _settings.value("selectedOpenAICompatibleProviderId", "")
    property string openclawInstances: _settings.value("openclawInstances", "[]")
    property string selectedOpenClawInstanceId: _settings.value("selectedOpenClawInstanceId", "")
    property string opencodeUrl: _settings.value("opencodeUrl", "http://127.0.0.1:4096")
    property string opencodeUsername: _settings.value("opencodeUsername", "")
    property string opencodePassword: _settings.value("opencodePassword", "")
    property string opencodeModel: _settings.value("opencodeModel", "")
    property string lastActiveSessionId: _settings.value("lastActiveSessionId", "")

    // MCP settings
    property string mcpServers: _settings.value("mcpServers", "[]")
    property string mcpToolResults: "{}"

    // Provider enable/disable settings
    property bool ollamaEnabled: _settings.value("ollamaEnabled", true)
    property bool openclawEnabled: _settings.value("openclawEnabled", true)
    property bool openaiCompatibleEnabled: _settings.value("openaiCompatibleEnabled", true)
    property bool opencodeEnabled: _settings.value("opencodeEnabled", true)

    readonly property bool isOllama: provider === "ollama"
    readonly property bool isOpenClaw: provider === "openclaw"
    readonly property bool isOpenAICompatible: provider === "openai-compatible"
    readonly property bool isOpenCode: provider === "opencode"

    function getProviderDisplayName() {
        if (provider === "ollama") return "Ollama"
        if (provider === "openclaw") {
            var selectedInstance = getSelectedOpenClawInstance()
            if (selectedInstance) {
                return selectedInstance.displayName
            }
            return "OpenClaw"
        }
        if (provider === "openai-compatible") {
            var selectedProvider = getSelectedOpenAICompatibleProvider()
            if (selectedProvider) {
                return selectedProvider.displayName
            }
            return openaiCompatibleModel || "OpenAI"
        }
        if (provider === "opencode") return "OpenCode"
        return "ChatQT"
    }

    function generateUuid() {
        return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
            var r = Math.random() * 16 | 0
            var v = c === 'x' ? r : (r & 0x3 | 0x8)
            return v.toString(16)
        })
    }

    function getOpenaiCompatibleProviders() {
        try {
            var providers = JSON.parse(openaiCompatibleProviders)
            return providers.map(function(p) {
                if (p.enabled === undefined) {
                    p.enabled = true
                }
                if (!p.id) {
                    p.id = generateUuid()
                }
                return p
            })
        } catch (e) {
            return []
        }
    }

    function saveOpenaiCompatibleProviders(array) {
        openaiCompatibleProviders = JSON.stringify(array)
    }

    function getFirstEnabledOpenAICompatibleProvider() {
        var providers = getOpenaiCompatibleProviders()
        for (var i = 0; i < providers.length; i++) {
            if (providers[i].enabled === true) {
                return providers[i]
            }
        }
        return null
    }

    function getSelectedOpenAICompatibleProvider() {
        var providers = getOpenaiCompatibleProviders()
        for (var i = 0; i < providers.length; i++) {
            if (providers[i].id === selectedOpenAICompatibleProviderId) {
                return providers[i]
            }
        }
        return null
    }

    function getOpenClawInstances() {
        try {
            var instances = JSON.parse(openclawInstances)
            return instances.map(function(i) {
                if (i.enabled === undefined) {
                    i.enabled = true
                }
                if (!i.id) {
                    i.id = generateUuid()
                }
                return i
            })
        } catch (e) {
            return []
        }
    }

    function saveOpenClawInstances(array) {
        openclawInstances = JSON.stringify(array)
    }

    function getFirstEnabledOpenClawInstance() {
        var instances = getOpenClawInstances()
        for (var i = 0; i < instances.length; i++) {
            if (instances[i].enabled === true) {
                return instances[i]
            }
        }
        return null
    }

    function getSelectedOpenClawInstance() {
        var instances = getOpenClawInstances()
        for (var i = 0; i < instances.length; i++) {
            if (instances[i].id === selectedOpenClawInstanceId) {
                return instances[i]
            }
        }
        return null
    }

    function getMcpServers() {
        try {
            var servers = JSON.parse(mcpServers)
            return servers.map(function(s) {
                if (s.enabled === undefined) {
                    s.enabled = true
                }
                if (!s.id) {
                    s.id = generateUuid()
                }
                return s
            })
        } catch (e) {
            return []
        }
    }

    function saveMcpServers(array) {
        mcpServers = JSON.stringify(array)
    }

    function getEnabledMcpServers() {
        var servers = getMcpServers()
        var enabled = []
        for (var i = 0; i < servers.length; i++) {
            if (servers[i].enabled === true) {
                enabled.push(servers[i])
            }
        }
        return enabled
    }

    function getMcpToolResults() {
        try {
            return JSON.parse(mcpToolResults)
        } catch (e) {
            return {}
        }
    }

    function saveMcpToolResults(results) {
        mcpToolResults = JSON.stringify(results)
    }

    function save() {
        _settings.setValue("provider", provider)
        _settings.setValue("openclawUrl", openclawUrl)
        _settings.setValue("openclawToken", openclawToken)
        _settings.setValue("openaiCompatibleUrl", openaiCompatibleUrl)
        _settings.setValue("openaiCompatibleToken", openaiCompatibleToken)
        _settings.setValue("openaiCompatibleModel", openaiCompatibleModel)
        _settings.setValue("openaiCompatibleProviders", openaiCompatibleProviders)
        _settings.setValue("opencodeUrl", opencodeUrl)
        _settings.setValue("opencodeUsername", opencodeUsername)
        _settings.setValue("opencodePassword", opencodePassword)
        _settings.setValue("opencodeModel", opencodeModel)
        _settings.setValue("ollamaEnabled", ollamaEnabled)
        _settings.setValue("openclawEnabled", openclawEnabled)
        _settings.setValue("openaiCompatibleEnabled", openaiCompatibleEnabled)
        _settings.setValue("opencodeEnabled", opencodeEnabled)
        _settings.setValue("selectedOpenAICompatibleProviderId", selectedOpenAICompatibleProviderId)
        _settings.setValue("openclawInstances", openclawInstances)
        _settings.setValue("selectedOpenClawInstanceId", selectedOpenClawInstanceId)
        _settings.setValue("lastActiveSessionId", lastActiveSessionId)
        _settings.setValue("mcpServers", mcpServers)
        _settings.sync()
    }

    property Settings _settings: Settings {
        category: "Provider"
    }

    onProviderChanged: save()
    onOpenclawUrlChanged: save()
    onOpenclawTokenChanged: save()
    onOpenaiCompatibleUrlChanged: save()
    onOpenaiCompatibleTokenChanged: save()
    onOpenaiCompatibleModelChanged: save()
    onOpenaiCompatibleProvidersChanged: save()
    onOpencodeUrlChanged: save()
    onOpencodeUsernameChanged: save()
    onOpencodePasswordChanged: save()
    onOpencodeModelChanged: save()
    onOllamaEnabledChanged: save()
    onOpenclawEnabledChanged: save()
    onOpenaiCompatibleEnabledChanged: save()
    onOpencodeEnabledChanged: save()
    onSelectedOpenAICompatibleProviderIdChanged: save()
    onOpenclawInstancesChanged: save()
    onSelectedOpenClawInstanceIdChanged: save()
    onLastActiveSessionIdChanged: save()
    onMcpServersChanged: save()

    Component.onCompleted: {
        if (typeof ProcessManager !== "undefined") {
            opencodeUrl = ProcessManager.serverUrl
            if (ProcessManager.password !== "") {
                opencodeUsername = "opencode"
                opencodePassword = ProcessManager.password
            }

            ProcessManager.serverUrlChanged.connect(function() {
                opencodeUrl = ProcessManager.serverUrl
            })
            ProcessManager.passwordChanged.connect(function() {
                if (ProcessManager.password !== "") {
                    opencodeUsername = "opencode"
                    opencodePassword = ProcessManager.password
                }
            })
        }

        if (openclawInstances === "[]") {
            if (openclawUrl !== "http://127.0.0.1:18789" || openclawToken !== "") {
                var migratedInstance = {
                    id: generateUuid(),
                    displayName: "OpenClaw",
                    url: openclawUrl,
                    token: openclawToken,
                    enabled: true
                }
                openclawInstances = JSON.stringify([migratedInstance])
                selectedOpenClawInstanceId = migratedInstance.id
                console.log("Migrated existing OpenClaw settings to multi-instance format")
            }
        }
    }
}