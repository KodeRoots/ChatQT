/*
    SPDX-FileCopyrightText: 2024 Denys Madureira <denysmb@zoho.com>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

import QtQuick
import QtCore

QtObject {
    id: settings

    property string provider: _settings.value("provider", "ollama")
    property string openclawUrl: _settings.value("openclawUrl", "http://127.0.0.1:18789")
    property string openclawToken: _settings.value("openclawToken", "")
    property string openaiCompatibleUrl: _settings.value("openaiCompatibleUrl", "")
    property string openaiCompatibleToken: _settings.value("openaiCompatibleToken", "")
    property string openaiCompatibleModel: _settings.value("openaiCompatibleModel", "")
    property bool openaiCompatibleDisableThinking: _settings.value("openaiCompatibleDisableThinking", false)

    readonly property bool isOllama: provider === "ollama"
    readonly property bool isOpenClaw: provider === "openclaw"
    readonly property bool isOpenAICompatible: provider === "openai-compatible"

    function getProviderDisplayName() {
        if (provider === "ollama") return "Ollama"
        if (provider === "openclaw") return "OpenClaw"
        if (provider === "openai-compatible") return openaiCompatibleModel || "OpenAI"
        return "ChatQT"
    }

    function save() {
        _settings.setValue("provider", provider)
        _settings.setValue("openclawUrl", openclawUrl)
        _settings.setValue("openclawToken", openclawToken)
        _settings.setValue("openaiCompatibleUrl", openaiCompatibleUrl)
        _settings.setValue("openaiCompatibleToken", openaiCompatibleToken)
        _settings.setValue("openaiCompatibleModel", openaiCompatibleModel)
        _settings.setValue("openaiCompatibleDisableThinking", openaiCompatibleDisableThinking)
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
    onOpenaiCompatibleDisableThinkingChanged: save()
}