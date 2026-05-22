import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Qt.labs.synchronizer

Item {
    id: root
    required property var scopeRoot
    property int sidebarPadding: 10
    anchors.fill: parent
    property bool aiChatEnabled: Config.options.policies.ai !== 0  
    property bool translatorEnabled: Config.options.policies.translator !== 0
    property bool animeEnabled: Config.options.policies.weeb !== 0  
    property bool animeCloset: Config.options.policies.weeb === 2  
    property bool wallpapersEnabled: Config.options.policies.wallpapers !== 0  

    property bool _sidebarExtended: scopeRoot.extend
    property int _maxTextTabs: _sidebarExtended ? 4 : 3

    property var extensionPages: ExtensionManager.ready
        ? ExtensionManager.getContributionPoint("sidebarLeftPages") : []

    Connections {
        target: ExtensionManager
        function onExtensionInstalled() { root.extensionPages = ExtensionManager.getContributionPoint("sidebarLeftPages") }
        function onExtensionRemoved() { root.extensionPages = ExtensionManager.getContributionPoint("sidebarLeftPages") }
        function onExtensionToggled() { root.extensionPages = ExtensionManager.getContributionPoint("sidebarLeftPages") }
    }

    property var tabButtonList: [  
        ...(root.aiChatEnabled ? [{"icon": "neurology", "name": Translation.tr("Intelligence")}] : []),  
        ...(root.translatorEnabled ? [{"icon": "translate", "name": Translation.tr("Translator")}] : []), 
        ...(root.wallpapersEnabled ? [{"icon": "wallpaper", "name": Translation.tr("Wallpapers")}] : []),
        ...((root.animeEnabled && !root.animeCloset) ? [{"icon": "bookmark_heart", "name": Translation.tr("Anime")}] : []),
        ...root.extensionPages.map(p => ({icon: p.icon, name: p.title}))
    ]
    property int tabCount: swipeView.count

    function focusActiveItem() {
        swipeView.currentItem.forceActiveFocus()
    }

    function createExtensionPage(page) {
        return Qt.createQmlObject(
            'import QtQuick; Loader { source: "file://' + page.fullPath + '"; active: true; onLoaded: if (item) item.extensionId = "' + page.extensionId + '" }',
            swipeView
        )
    }

    Keys.onPressed: (event) => {
        if (event.modifiers === Qt.ControlModifier) {
            if (event.key === Qt.Key_PageDown) {
                swipeView.incrementCurrentIndex()
                event.accepted = true;
            }
            else if (event.key === Qt.Key_PageUp) {
                swipeView.decrementCurrentIndex()
                event.accepted = true;
            }
        }
    }

    ColumnLayout {
        anchors {
            fill: parent
            margins: sidebarPadding
        }
        spacing: sidebarPadding

        Toolbar {
            visible: tabButtonList.length > 1
            Layout.alignment: Qt.AlignHCenter
            enableShadow: false
            colBackground: Appearance.colors.colLayer3
            ToolbarTabBar {
                id: tabBar
                Layout.alignment: Qt.AlignHCenter
                tabButtonList: root.tabButtonList
                maxTextTabs: root._maxTextTabs
                currentIndex: Math.min(Persistent.states.sidebar.policies.tab, Math.max(0, root.tabButtonList.length - 1))
                onCurrentIndexChanged: Persistent.states.sidebar.policies.tab = currentIndex
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            implicitWidth: swipeView.implicitWidth
            implicitHeight: swipeView.implicitHeight
            radius: Appearance.rounding.normal
            color: Appearance.colors.colLayer1

            SwipeView { // Content pages
                id: swipeView
                anchors.fill: parent
                spacing: 10
                currentIndex: Math.min(Persistent.states.sidebar.policies.tab, Math.max(0, swipeView.count - 1))
                onCurrentIndexChanged: Persistent.states.sidebar.policies.tab = currentIndex

                clip: true
                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: swipeView.width
                        height: swipeView.height
                        radius: Appearance.rounding.small
                    }
                }

                contentChildren: [
                    ...(root.aiChatEnabled ? [aiChat.createObject()] : []),
                    ...(root.translatorEnabled ? [translator.createObject()] : []),
                    ...((root.tabButtonList.length === 0 || (!root.aiChatEnabled && !root.translatorEnabled && root.animeCloset)) ? [placeholder.createObject()] : []),
                    ...(root.animeEnabled ? [anime.createObject()] : []),
                    ...root.extensionPages.map(p => root.createExtensionPage(p)).filter(item => item)
                ]
            }
        }

        Component {
            id: aiChat
            AiChat {}
        }
        Component {
            id: translator
            Translator {}
        }
        Component {
            id: anime
            Anime {}
        }
        Component {
            id: placeholder
            Item {
                StyledText {
                    anchors.centerIn: parent
                    text: root.animeCloset ? Translation.tr("Nothing") : Translation.tr("Enjoy your empty sidebar...")
                    color: Appearance.colors.colSubtext
                }
            }
        }
    }
}