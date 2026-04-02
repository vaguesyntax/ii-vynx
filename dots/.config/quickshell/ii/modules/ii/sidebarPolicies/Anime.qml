import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.ii.sidebarPolicies.anime
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell

Item {
    id: root
    property real padding: 4

    property var inputField: tagInputField
    readonly property var responses: Booru.responses
    property string previewDownloadPath: Directories.booruPreviews
    property string downloadPath: Directories.booruDownloads
    property string nsfwPath: Directories.booruDownloadsNsfw
    property string commandPrefix: "/"
    property real scrollOnNewResponse: 100
    property int tagSuggestionDelay: 210
    property var suggestionQuery: ""
    property var suggestionList: []

    property bool showHistory: false
    property bool pullLoading: false
    property int pullLoadingGap: 80
    property real normalizedPullDistance: Math.max(0, (1 - Math.exp(-booruResponseListView.verticalOvershoot / 50)) * booruResponseListView.dragging)

    Connections {
        target: Booru
        function onTagSuggestion(query, suggestions) {
            root.suggestionQuery = query;
            root.suggestionList = suggestions;
        }
        function onRunningRequestsChanged() {
            if (Booru.runningRequests === 0) {
                root.pullLoading = false;
            }
        }
        function onResponseFinished() {
            if (root.responses.length === 0) return

                var last = root.responses[root.responses.length - 1]
                if (last && last.provider !== "system") {
                    Qt.callLater(function() {
                        booruResponseListView.contentY = booruResponseListView.contentY + root.scrollOnNewResponse
                    })
                }
        }
    }

    property var allCommands: [
        {
            name: "clear",
            description: Translation.tr("Clear the current list of images"),
            execute: () => {
                Booru.clearResponses();
            }
        },
        {
            name: "next",
            description: Translation.tr("Get the next page of results"),
            execute: () => {
                if (root.responses.length > 0) {
                    const lastResponse = root.responses[root.responses.length - 1];
                    root.handleInput(`${lastResponse.tags.join(" ")} ${parseInt(lastResponse.page) + 1}`);
                } else {
                    root.handleInput("");
                }
            }
        },
        {
            name: "safe",
            description: Translation.tr("Disable NSFW content"),
            execute: () => {
                Persistent.states.booru.allowNsfw = false;
            }
        },
        {
            name: "lewd",
            description: Translation.tr("Allow NSFW content"),
            execute: () => {
                Persistent.states.booru.allowNsfw = true;
            }
        },
        {
            name: "gelbooru_key",
            description: Translation.tr("Set Gelbooru API key"),
            execute: (args) => {
                if (args.length > 0) {
                    Booru.setApiKey("gelbooru", args[0]);
                } else {
                    Booru.addSystemMessage(Translation.tr("Usage: /gelbooru_key <key>"));
                }
            }
        },
        {
            name: "gelbooru_id",
            description: Translation.tr("Set Gelbooru User ID"),
            execute: (args) => {
                if (args.length > 0) {
                    Booru.setUserId("gelbooru", args[0]);
                } else {
                    Booru.addSystemMessage(Translation.tr("Usage: /gelbooru_id <id>"));
                }
            }
        },
        {
            name: "gelbooru_pass_hash",
            description: Translation.tr("Set Gelbooru Pass Hash"),
            execute: (args) => {
                if (args.length > 0) {
                    Booru.setPassHash("gelbooru", args[0]);
                } else {
                    Booru.addSystemMessage(Translation.tr("Usage: /gelbooru_pass_hash <hash>"));
                }
            }
        },
        {
            name: "history",
            description: Translation.tr("Show your last 10 searches"),
            execute: () => {
                root.showHistory = !root.showHistory
            }
        },
        {
            name: "limit",
            description: Translation.tr("Set image limit. Usage: %1limit NUMBER").arg(root.commandPrefix),
            execute: args => {
                if (args.length === 0 || args[0] === "") {
                    Booru.addSystemMessage(
                        Translation.tr("Current limit: %1").arg(Config.options.sidebar.booru.limit)
                    );
                    return;
                }

                const value = parseInt(args[0]);

                if (isNaN(value) || value < 1 || value > 100) {
                    Booru.addSystemMessage(
                        Translation.tr("Invalid value. Use %1limit NUMBER (1–100)").arg(root.commandPrefix)
                    );
                    return;
                }

                Config.options.sidebar.booru.limit = value;

                Booru.addSystemMessage(
                    Translation.tr("Limit set to %1").arg(value)
                );
            }
        },
        {
            name: "thumbnail",
            description: Translation.tr("Set thumbnail row height. Usage: %1thumbnail VALUE").arg(root.commandPrefix),
            execute: args => {
                if (args.length === 0 || args[0] === "") {
                    Booru.addSystemMessage(
                        Translation.tr("Current thumbnail: %1").arg(Config.options.sidebar.booru.rowTooShortThreshold)
                    );
                    return;
                }

                const value = parseInt(args[0]);

                if (isNaN(value) || value < 100 || value > 1000) {
                    Booru.addSystemMessage(
                        Translation.tr("Invalid value. Use %1thumbnail VALUE (100–1000)").arg(root.commandPrefix)
                    );
                    return;
                }

                Config.options.sidebar.booru.rowTooShortThreshold = value;

                for (let i = 0; i < booruResponseListView.count; i++) {
                    const item = booruResponseListView.itemAtIndex(i);
                    if (item && item.responseData.provider !== "system") {
                        item.rowTooShortThreshold = value;
                    }
                }

                Booru.addSystemMessage(
                    Translation.tr("Thumbnail set to %1").arg(value)
                );
            }
        },
    ]

    function handleInput(inputText) {
        if (inputText.startsWith(root.commandPrefix)) {
            // Handle special commands
            const command = inputText.split(" ")[0].substring(1);
            const args = inputText.split(" ").slice(1);
            const commandObj = root.allCommands.find(cmd => cmd.name === `${command}`);
            if (commandObj) {
                commandObj.execute(args);
            } else {
                Booru.addSystemMessage(Translation.tr("Unknown command: ") + command);
            }
        }
        else if (inputText.trim() == "+") {
            root.handleInput(`${root.commandPrefix}next`);
        }
        else {
            // Create tag list
            const tagList = inputText.split(/\s+/).filter(tag => tag.length > 0);
            let pageIndex = 1;
            for (let i = 0; i < tagList.length; ++i) { // Detect page number
                if (/^\d+$/.test(tagList[i])) {
                    pageIndex = parseInt(tagList[i], 10);
                    tagList.splice(i, 1);
                    break;
                }
            }

            const historyEntry = { tags: tagList, page: pageIndex, provider: Booru.currentProvider };
            let hist = Persistent.states.booru.searchHistory
            ? Array.from(Persistent.states.booru.searchHistory)
            : [];

            hist = hist.filter(e =>
            !(e.tags.join(" ") === tagList.join(" ") &&
            e.page === pageIndex &&
            e.provider === Booru.currentProvider)
            );

            hist.unshift(historyEntry);
            Persistent.states.booru.searchHistory = hist.slice(0, 10);

            Booru.makeRequest(tagList, Persistent.states.booru.allowNsfw, Config.options.sidebar.booru.limit, pageIndex);
        }
    }

    onFocusChanged: (focus) => {
        if (focus && !keyInputDialogLoader.active) {
            tagInputField.forceActiveFocus()
        }
    }

    property real pageKeyScrollAmount: booruResponseListView.height / 2
    Keys.onPressed: (event) => {
        if (keyInputDialogLoader.active) return
            tagInputField.forceActiveFocus()
        if (event.modifiers === Qt.NoModifier) {
            if (event.key === Qt.Key_PageUp) {
                if (booruResponseListView.atYBeginning) return;
                booruResponseListView.contentY = Math.max(0, booruResponseListView.contentY - root.pageKeyScrollAmount)
                event.accepted = true
            } else if (event.key === Qt.Key_PageDown) {
                if (booruResponseListView.atYEnd) return;
                booruResponseListView.contentY = Math.min(booruResponseListView.contentHeight, booruResponseListView.contentY + root.pageKeyScrollAmount)
                event.accepted = true
            }
        }
        if ((event.modifiers & Qt.ControlModifier) && (event.modifiers & Qt.ShiftModifier) && event.key === Qt.Key_O) {
            Booru.clearResponses()
        }
    }


    ColumnLayout {
        id: columnLayout
        anchors {
            fill: parent
            margins: root.padding
        }
        spacing: root.padding

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: swipeView.width
                    height: swipeView.height
                    radius: Appearance.rounding.small
                }
            }

            ScrollEdgeFade {
                z: 1
                target: booruResponseListView
                vertical: true
            }

            StyledListView { // Booru responses
                id: booruResponseListView
                z: 0
                anchors.fill: parent
                spacing: 10
                
                touchpadScrollFactor: Config.options.interactions.scrolling.touchpadScrollFactor * 1.4
                mouseScrollFactor: Config.options.interactions.scrolling.mouseScrollFactor * 1.4

                model: ScriptModel {
                    values: root.responses
                }
                delegate: BooruResponse {
                    responseData: modelData
                    tagInputField: root.inputField
                    previewDownloadPath: root.previewDownloadPath
                    downloadPath: root.downloadPath
                    nsfwPath: root.nsfwPath
                }

                onDragEnded: { // Pull to load more
                    const gap = booruResponseListView.verticalOvershoot
                    if (gap > root.pullLoadingGap) {
                        root.pullLoading = true
                        root.handleInput(`${root.commandPrefix}next`)
                    }
                }
            }

            PagePlaceholder {
                id: placeholderItem
                z: 2
                shown: root.responses.length === 0
                icon: "bookmark_heart"
                title: Translation.tr("Anime boorus")
                description: ""
                shape: MaterialShape.Shape.Bun
            }

            ScrollToBottomButton {
                z: 3
                target: booruResponseListView
            }

            MaterialLoadingIndicator {
                id: loadingIndicator
                z: 4
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    bottom: parent.bottom
                    bottomMargin: 20 + (root.pullLoading ? 0 : Math.max(0, (root.normalizedPullDistance - 0.5) * 50))
                    Behavior on bottomMargin {
                        NumberAnimation {
                            duration: 200
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
                        }
                    }
                }
                loading: root.pullLoading || Booru.runningRequests > 0
                pullProgress: Math.min(1, booruResponseListView.verticalOvershoot / root.pullLoadingGap * booruResponseListView.dragging)
                scale: root.pullLoading ? 1 : Math.min(1, root.normalizedPullDistance * 2)
            }
            // HISTORY
            Rectangle {
                id: historyPanel
                anchors.fill: parent
                visible: root.showHistory
                z: 10
                radius: Appearance.rounding.small
                color: Appearance.m3colors.m3surfaceContainer

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                }

                ColumnLayout {
                    anchors {
                        fill: parent
                        margins: 10
                    }
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true

                        StyledText {
                            text: Translation.tr("Recent Searches")
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: Font.DemiBold
                            color: Appearance.colors.colOnLayer2
                        }

                        Item { Layout.fillWidth: true }

                        RippleButton {
                            implicitWidth: 30
                            implicitHeight: 30
                            buttonRadius: Appearance.rounding.small
                            onClicked: {
                                Persistent.states.booru.searchHistory = [];
                            }
                            contentItem: MaterialSymbol {
                                anchors.centerIn: parent
                                text: "delete"
                                iconSize: 18
                                color: Appearance.colors.colOnLayer2
                            }
                        }

                        RippleButton {
                            implicitWidth: 30
                            implicitHeight: 30
                            buttonRadius: Appearance.rounding.small
                            onClicked: root.showHistory = false
                            contentItem: MaterialSymbol {
                                anchors.centerIn: parent
                                text: "close"
                                iconSize: 18
                                color: Appearance.colors.colOnLayer2
                            }
                        }
                    }

                    StyledListView {
                        id: historyListView
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 4
                        clip: true

                        model: ScriptModel {
                            values: Persistent.states.booru.searchHistory ?? []
                        }

                        delegate: RippleButton {
                            required property var modelData
                            anchors.left: parent?.left
                            anchors.right: parent?.right
                            implicitHeight: historyRow.implicitHeight + 16
                            buttonRadius: Appearance.rounding.small
                            colBackground: Appearance.colors.colLayer1
                            colBackgroundHover: Appearance.colors.colLayer1Hover

                            onClicked: {
                                const entry = modelData

                                const searchText = entry.tags.join(" ") +
                                (entry.page > 1 ? " " + entry.page : "")

                                if (entry.provider && entry.provider !== Booru.currentProvider) {
                                    Booru.setProvider(entry.provider)
                                }

                                root.showHistory = false
                                tagInputField.text = searchText
                                root.handleInput(searchText)
                            }

                            contentItem: RowLayout {
                                id: historyRow
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    margins: 10
                                    verticalCenter: parent.verticalCenter
                                }
                                spacing: 8

                                MaterialSymbol {
                                    text: "history"
                                    iconSize: 18
                                    color: Appearance.colors.colOnLayer1
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: modelData.tags?.join(", ") || Translation.tr("[no tags]")
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        color: Appearance.colors.colOnLayer1
                                        elide: Text.ElideRight
                                    }

                                    StyledText {
                                        text: Translation.tr("Page %1 · %2")
                                        .arg(modelData.page ?? 1)
                                        .arg(Booru.providers[modelData.provider]?.name ?? modelData.provider ?? "?")
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        color: Appearance.colors.colSubtext
                                    }
                                }
                            }
                        }
                    }

                    PagePlaceholder {
                        Layout.alignment: Qt.AlignCenter
                        visible: (Persistent.states.booru.searchHistory ?? []).length === 0
                        shown: (Persistent.states.booru.searchHistory ?? []).length === 0
                        icon: "manage_search"
                        title: Translation.tr("No history yet")
                        description: ""
                        shape: MaterialShape.Shape.Cookie7Sided
                    }
                }
            }
            // HISTORY BLOCK
        }

        DescriptionBox { // Tag suggestion description
            text: root.suggestionList[tagSuggestions.selectedIndex]?.description ?? ""
            showArrows: root.suggestionList.length > 1
        }

        Loader { // Loader for Gelbooru API credentials input buttons
            id: gelbooruButtonsLoader
            width: item?.implicitWidth
            height: item?.implicitHeight
            Layout.alignment: Qt.AlignHCenter

            active: Booru.currentProvider === "gelbooru" &&
            root.responses.length === 0 &&
            (!Booru.apiKeys["gelbooru"] || !Booru.apiKeys["gelbooru_user_id"] || !Booru.apiKeys["gelbooru_pass_hash"])
            visible: active

            sourceComponent: Item {
                implicitWidth: contentLayout.implicitWidth
                implicitHeight: contentLayout.implicitHeight
                anchors.horizontalCenter: parent.horizontalCenter

                ColumnLayout {
                    id: contentLayout
                    width: 330
                    anchors.horizontalCenter: parent.horizontalCenter

                    RowLayout {
                        id: gelbooruSelector
                        Layout.alignment: Qt.AlignHCenter
                        width: parent.width
                        spacing: 2

                        property var options: {
                            var opts = []
                            if (!Booru.apiKeys["gelbooru"])
                                opts.push({ displayName: "API Key", icon: "key", value: "gelbooru_key" })
                                if (!Booru.apiKeys["gelbooru_user_id"])
                                    opts.push({ displayName: "User ID", icon: "person", value: "gelbooru_id" })
                                    if (!Booru.apiKeys["gelbooru_pass_hash"])
                                        opts.push({ displayName: "Pass Hash", icon: "password", value: "gelbooru_pass_hash" })
                                        return opts
                        }

                        Repeater {
                            model: gelbooruSelector.options
                            delegate: SelectionGroupButton {
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                leftmost: index === 0
                                rightmost: index === gelbooruSelector.options.length - 1
                                toggled: false

                                colBackground: Appearance.colors.colSecondaryContainer
                                colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                                colBackgroundActive: Appearance.colors.colSecondaryContainerActive

                                onClicked: keyInputDialogLoader.open(modelData.value)

                                contentItem: Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 4

                                    Item {
                                        width: Appearance.font.pixelSize.larger
                                        height: Appearance.font.pixelSize.larger
                                        anchors.verticalCenter: parent.verticalCenter

                                        MaterialSymbol {
                                            anchors.centerIn: parent
                                            width: Appearance.font.pixelSize.larger
                                            height: Appearance.font.pixelSize.larger
                                            text: modelData.icon
                                            iconSize: Appearance.font.pixelSize.larger
                                            color: Appearance.colors.colOnSecondaryContainer
                                        }
                                    }

                                    StyledText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.displayName
                                        color: Appearance.colors.colOnSecondaryContainer
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Loader { // Loader for provider selection dropdown
            id: providerSelectorLoader
            width: item?.implicitWidth
            height: item?.implicitHeight
            Layout.alignment: Qt.AlignHCenter

            active: root.responses.length === 0
            visible: active

            sourceComponent: Item {
                implicitWidth: providerContentLayout.implicitWidth
                implicitHeight: providerContentLayout.implicitHeight
                anchors.horizontalCenter: parent.horizontalCenter

                ColumnLayout {
                    id: providerContentLayout
                    width: 330
                    anchors.horizontalCenter: parent.horizontalCenter

                    StyledComboBox {
                        id: booruProviderSelector
                        width: parent.width

                        buttonIcon: "image_search"
                        textRole: "title"
                        model: [
                            { title: "yande.re",   icon: "image",         value: "yandere" },
                            { title: "Konachan",   icon: "wallpaper",     value: "konachan" },
                            { title: "Zerochan",   icon: "child_care",    value: "zerochan" },
                            { title: "Danbooru",   icon: "photo_library", value: "danbooru" },
                            { title: "Gelbooru",   icon: "collections",   value: "gelbooru" },
                            { title: "waifu.im",   icon: "favorite",      value: "waifu.im" },
                            { title: "Alcy",       icon: "landscape",     value: "t.alcy.cc" }
                        ]
                        enabled: true

                        currentIndex: {
                            const providers = booruProviderSelector.model;
                            for (var i = 0; i < providers.length; i++) {
                                if (providers[i].value === Booru.currentProvider) {
                                    return i;
                                }
                            }
                            return 0;
                        }

                        onActivated: index => {
                            Persistent.states.booru.provider = booruProviderSelector.model[index].value
                        }
                    }
                }
            }
        }

        FlowButtonGroup { // Tag suggestions
            id: tagSuggestions
            visible: root.suggestionList.length > 0 && tagInputField.text.length > 0
            property int selectedIndex: 0
            Layout.fillWidth: true
            spacing: 5

            Repeater {
                id: tagSuggestionRepeater
                model: {
                    tagSuggestions.selectedIndex = 0
                    return root.suggestionList.slice(0, 10)
                }
                delegate: ApiCommandButton {
                    id: tagButton
                    colBackground: tagSuggestions.selectedIndex === index ? Appearance.colors.colSecondaryContainerHover : Appearance.colors.colSecondaryContainer
                    bounce: false
                    contentItem: RowLayout {
                        anchors.centerIn: parent
                        spacing: 5
                        StyledText {
                            Layout.fillWidth: false
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnSecondaryContainer
                            horizontalAlignment: Text.AlignRight
                            text: modelData.displayName ?? modelData.name
                        }
                        StyledText {
                            Layout.fillWidth: false
                            visible: modelData.count !== undefined
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnSecondaryContainer
                            horizontalAlignment: Text.AlignLeft
                            text: modelData.count ?? ""
                        }
                    }

                    onHoveredChanged: {
                        if (tagButton.hovered) {
                            tagSuggestions.selectedIndex = index;
                        }
                    }
                    onClicked: {
                        tagSuggestions.acceptTag(modelData.name)
                    }
                }
            }

            function acceptTag(tag) {
                const words = tagInputField.text.trim().split(/\s+/);
                if (words.length > 0) {
                    words[words.length - 1] = tag;
                } else {
                    words.push(tag);
                }
                const updatedText = words.join(" ") + " ";
                tagInputField.text = updatedText;
                tagInputField.cursorPosition = tagInputField.text.length;
                tagInputField.forceActiveFocus();
            }

            function acceptSelectedTag() {
                if (tagSuggestions.selectedIndex >= 0 && tagSuggestions.selectedIndex < tagSuggestionRepeater.count) {
                    const tag = root.suggestionList[tagSuggestions.selectedIndex].name;
                    tagSuggestions.acceptTag(tag);
                }
            }
        }

        Rectangle { // Tag input area
            id: tagInputContainer
            property real columnSpacing: 5
            Layout.fillWidth: true
            radius: Appearance.rounding.normal - root.padding
            color: Appearance.colors.colLayer2
            implicitWidth: tagInputField.implicitWidth
            implicitHeight: Math.max(inputFieldRowLayout.implicitHeight + inputFieldRowLayout.anchors.topMargin 
                + commandButtonsRow.implicitHeight + commandButtonsRow.anchors.bottomMargin + columnSpacing, 45)
            clip: true

            Behavior on implicitHeight {
                animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
            }

            RowLayout { // Input field and send button
                id: inputFieldRowLayout
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: 5
                spacing: 0

                StyledTextArea { // The actual TextArea
                    id: tagInputField
                    wrapMode: TextArea.Wrap
                    Layout.fillWidth: true
                    padding: 10
                    color: activeFocus ? Appearance.m3colors.m3onSurface : Appearance.m3colors.m3onSurfaceVariant
                    renderType: Text.NativeRendering
                    placeholderText: Translation.tr('Enter tags, or "%1" for commands').arg(root.commandPrefix)

                    background: null

                    property Timer searchTimer: Timer { // Timer for tag suggestions
                        interval: root.tagSuggestionDelay
                        repeat: false
                        onTriggered: {
                            const inputText = tagInputField.text
                            const words = inputText.trim().split(/\s+/);
                            if (words.length > 0) {
                                Booru.triggerTagSearch(words[words.length - 1]);
                            }
                        }
                    }

                    onTextChanged: { // Handle tag suggestions
                        if(tagInputField.text.length === 0) {
                            root.suggestionQuery = ""
                            root.suggestionList = []
                            searchTimer.stop();
                            return
                        }
                        if(tagInputField.text.startsWith(root.commandPrefix)) {
                            root.suggestionQuery = tagInputField.text
                            root.suggestionList = root.allCommands.filter(cmd => cmd.name.startsWith(tagInputField.text.substring(1))).map(cmd => {
                                return {
                                    name: `${root.commandPrefix}${cmd.name}`,
                                    description: `${cmd.description}`,
                                }
                            })
                            searchTimer.stop();
                            return
                        }
                        searchTimer.restart();
                    }

                    function accept() {
                        root.handleInput(text)
                        text = ""
                    }

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Tab) {
                            tagSuggestions.acceptSelectedTag();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up) {
                            tagSuggestions.selectedIndex = Math.max(0, tagSuggestions.selectedIndex - 1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Down) {
                            tagSuggestions.selectedIndex = Math.min(root.suggestionList.length - 1, tagSuggestions.selectedIndex + 1);
                            event.accepted = true;
                        } else if ((event.key === Qt.Key_Enter || event.key === Qt.Key_Return)) {
                            if (event.modifiers & Qt.ShiftModifier) {
                                // Insert newline
                                tagInputField.insert(tagInputField.cursorPosition, "\n")
                                event.accepted = true
                            } else { // Accept text
                                const inputText = tagInputField.text
                                root.handleInput(inputText)
                                tagInputField.clear()
                                event.accepted = true
                            }
                        }
                    }
                }

                RippleButton { // Send button
                    id: sendButton
                    Layout.alignment: Qt.AlignTop
                    Layout.rightMargin: 5
                    implicitWidth: 40
                    implicitHeight: 40
                    buttonRadius: Appearance.rounding.small
                    enabled: tagInputField.text.length > 0
                    toggled: enabled

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: sendButton.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            const inputText = tagInputField.text
                            root.handleInput(inputText)
                            tagInputField.clear()
                        }
                    }

                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        iconSize: 22
                        color: sendButton.enabled ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer2Disabled
                        text: "arrow_upward"
                    }
                }
            }

            RowLayout { // Controls
                id: commandButtonsRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 5
                anchors.leftMargin: 5
                anchors.rightMargin: 5
                spacing: 5

                property var commandsShown: [
                    {
                        name: "history",
                        sendDirectly: true,
                    },
                    {
                        name: "clear",
                        sendDirectly: true,
                    }, 
                ]

                ApiInputBoxIndicator { // Tool indicator
                    icon: "api"
                    text: Booru.providers[Booru.currentProvider].name
                    tooltipText: Translation.tr("Current API endpoint: %1\nSet it with %2mode PROVIDER")
                        .arg(Booru.providers[Booru.currentProvider].url)
                        .arg(root.commandPrefix)
                }

                StyledText {
                    font.pixelSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnLayer1
                    text: "•"
                }

                MouseArea { // NSFW toggle
                    visible: width > 0
                    implicitWidth: switchesRow.implicitWidth
                    Layout.fillHeight: true

                    hoverEnabled: true
                    PointingHandInteraction {}
                    onPressed: {
                        nsfwSwitch.checked = !nsfwSwitch.checked
                    }

                    RowLayout {
                        id: switchesRow
                        spacing: 5
                        anchors.centerIn: parent

                        StyledText {
                            Layout.fillHeight: true
                            Layout.leftMargin: 10
                            Layout.alignment: Qt.AlignVCenter
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: nsfwSwitch.enabled ? Appearance.colors.colOnLayer1 : Appearance.m3colors.m3outline
                            text: Translation.tr("Allow NSFW")
                        }
                        StyledSwitch {
                            id: nsfwSwitch
                            enabled: Booru.currentProvider !== "zerochan"
                            scale: 0.6
                            Layout.alignment: Qt.AlignVCenter
                            checked: (Persistent.states.booru.allowNsfw && Booru.currentProvider !== "zerochan")
                            onCheckedChanged: {
                                if (!nsfwSwitch.enabled) return;
                                Persistent.states.booru.allowNsfw = checked;
                            }
                        }
                    }

                }

                Item { Layout.fillWidth: true }

                ButtonGroup {
                    padding: 0
                    Repeater { // Command buttons
                        id: commandRepeater
                        model: commandButtonsRow.commandsShown
                        delegate: ApiCommandButton {
                            property string commandRepresentation: `${root.commandPrefix}${modelData.name}`
                            buttonText: commandRepresentation
                            colBackground: Appearance.colors.colLayer2

                            downAction: () => {
                                if (modelData.sendDirectly) {
                                    root.handleInput(commandRepresentation)
                                } else {
                                    tagInputField.text = commandRepresentation + " "
                                    tagInputField.cursorPosition = tagInputField.text.length
                                    tagInputField.forceActiveFocus()
                                }
                                if (modelData.name === "clear") {
                                    tagInputField.text = ""
                                }
                            }
                        }
                    }
                }
            }

        }
    }

    Loader { // Loader for Gelbooru key input dialog
        anchors.fill: parent
        z: 100
        active: false

        property string keyType: ""

        function open(type) {
            keyType = type
            active = true
        }

        onActiveChanged: {
            if (active && item) {
                item.show = true
                item.forceActiveFocus()
            }
        }

        sourceComponent: WindowDialog {
            id: keyDialog
            anchors.fill: parent
            backgroundWidth: 380
            show: false

            Component.onCompleted: {
                show = true
                dialogInput.forceActiveFocus()
            }

            onDismiss: {
                show = false
            }

            onVisibleChanged: {
                if (!visible) {
                    keyInputDialogLoader.active = false
                    keyInputDialogLoader.keyType = ""
                }
            }

            MaterialSymbol {
                Layout.alignment: Qt.AlignHCenter
                iconSize: 26
                text: keyInputDialogLoader.keyType === "gelbooru_id" ? "person" :
                keyInputDialogLoader.keyType === "gelbooru_pass_hash" ? "password" : "key"
                color: Appearance.colors.colSecondary
            }

            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: Appearance.font.pixelSize.large
                font.weight: Font.DemiBold
                color: Appearance.m3colors.m3onSurface
                text: {
                    if (keyInputDialogLoader.keyType === "gelbooru_key")
                        return Translation.tr("Gelbooru API Key")
                        if (keyInputDialogLoader.keyType === "gelbooru_id")
                            return Translation.tr("Gelbooru User ID")
                            if (keyInputDialogLoader.keyType === "gelbooru_pass_hash")
                                return Translation.tr("Gelbooru Pass Hash")
                                return ""
                }
            }

            MaterialTextField {
                id: dialogInput
                Layout.fillWidth: true
                focus: true
                placeholderText: {
                    if (keyInputDialogLoader.keyType === "gelbooru_key")
                        return Translation.tr("Enter API Key...")
                        if (keyInputDialogLoader.keyType === "gelbooru_id")
                            return Translation.tr("Enter User ID...")
                            if (keyInputDialogLoader.keyType === "gelbooru_pass_hash")
                                return Translation.tr("Enter Pass Hash...")
                                return ""
                }

                Keys.onPressed: event => {
                    if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_V) {
                        event.accepted = false
                    } else if (event.key === Qt.Key_Escape) {
                        keyDialog.dismiss()
                        event.accepted = true
                    }
                }

                onAccepted: keyDialog.submitValue()
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: 10
                Item { Layout.fillWidth: true }

                DialogButton {
                    buttonText: Translation.tr("Cancel")
                    onClicked: keyDialog.dismiss()
                }

                DialogButton {
                    enabled: dialogInput.text.trim().length > 0
                    buttonText: Translation.tr("Save")
                    onClicked: keyDialog.submitValue()
                }
            }

            function submitValue() {
                const value = dialogInput.text.trim()
                if (value.length === 0) return

                    if (keyInputDialogLoader.keyType === "gelbooru_key") {
                        KeyringStorage.setNestedField(["apiKeys", "gelbooru"], value)
                    } else if (keyInputDialogLoader.keyType === "gelbooru_id") {
                        KeyringStorage.setNestedField(["apiKeys", "gelbooru_user_id"], value)
                    } else if (keyInputDialogLoader.keyType === "gelbooru_pass_hash") {
                        KeyringStorage.setNestedField(["apiKeys", "gelbooru_pass_hash"], value)
                    }

                    keyDialog.dismiss()
            }
        }
    }
}
