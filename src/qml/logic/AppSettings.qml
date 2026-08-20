/*
    SPDX-FileCopyrightText: 2024 Denys Madureira <denysmb@zoho.com>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

import QtQuick
import QtCore
import org.kde.chatqt
import "HumanizerSoul.js" as HumanizerSoul

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
    property string lastActiveSessionId: _settings.value("lastActiveSessionId", "")

    // MCP settings
    property string mcpServers: _settings.value("mcpServers", "[]")
    property string mcpToolResults: "{}"

    // Memory settings
    property string memoryContent: _settings.value("memoryContent", "")

    // Soul settings
    property string soulContent: _settings.value("soulContent", "")
    property bool humanizedOutput: _settings.value("humanizedOutput", false)

    // Provider enable/disable settings
    property bool ollamaEnabled: _settings.value("ollamaEnabled", true)
    property bool experimentalFeatures: typeof experimentalFeaturesEnabled !== 'undefined' ? experimentalFeaturesEnabled : false

    property bool _openclawEnabledStored: _settings.value("openclawEnabled", false)

    property bool openclawEnabled: experimentalFeatures && _openclawEnabledStored
    property bool openaiCompatibleEnabled: _settings.value("openaiCompatibleEnabled", true)

    readonly property bool isOllama: provider === "ollama"
    readonly property bool isOpenClaw: provider === "openclaw"
    readonly property bool isOpenAICompatible: provider === "openai-compatible"

    function getEffectiveSoulContent() {
        var soul = (soulContent || "").trim()
        if (!humanizedOutput) {
            return soul
        }
        var humanizer = (HumanizerSoul.content || "").trim()
        if (soul === "") {
            return humanizer
        }
        return soul + "\n\n" + humanizer
    }

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
                if (s.isBuiltIn === undefined) {
                    s.isBuiltIn = false
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
        _settings.setValue("ollamaEnabled", ollamaEnabled)
        _settings.setValue("openclawEnabled", _openclawEnabledStored)
        _settings.setValue("openaiCompatibleEnabled", openaiCompatibleEnabled)
        _settings.setValue("selectedOpenAICompatibleProviderId", selectedOpenAICompatibleProviderId)
        _settings.setValue("openclawInstances", openclawInstances)
        _settings.setValue("selectedOpenClawInstanceId", selectedOpenClawInstanceId)
        _settings.setValue("lastActiveSessionId", lastActiveSessionId)
        _settings.setValue("mcpServers", mcpServers)
        _settings.setValue("soulContent", soulContent)
        _settings.setValue("humanizedOutput", humanizedOutput)
        _settings.setValue("memoryContent", memoryContent)
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
    onOllamaEnabledChanged: save()
    onOpenclawEnabledChanged: save()
    onOpenaiCompatibleEnabledChanged: save()
    onSelectedOpenAICompatibleProviderIdChanged: save()
    onOpenclawInstancesChanged: save()
    onSelectedOpenClawInstanceIdChanged: save()
    onLastActiveSessionIdChanged: save()
    onSoulContentChanged: save()
    onHumanizedOutputChanged: save()
    onMemoryContentChanged: save()
    onMcpServersChanged: save()

    Component.onCompleted: {
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