import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick

Toolbar {
    id: extraOptions
    z: 1

    property string text: filterField.text

    IconToolbarButton {
        implicitWidth: height
        onClicked: {
            Wallpapers.openFallbackPicker(wallpaperSelectorContent.useDarkMode);
            GlobalStates.wallpaperSelectorOpen = false;
        }
        altAction: () => {
            Wallpapers.openFallbackPicker(wallpaperSelectorContent.useDarkMode);
            GlobalStates.wallpaperSelectorOpen = false;
            Config.options.wallpaperSelector.useSystemFileDialog = true
        }
        text: "open_in_new"
        StyledToolTip {
            text: Translation.tr("Use the system file picker instead\nRight-click to make this the default behavior")
        }
    }

    IconToolbarButton {
        implicitWidth: height
            onClicked: {
                if (wallpaperSelectorContent.browserMode) {
                    if (wallpaperSelectorContent.apiImages.length > 0) {
                        const randomImg = wallpaperSelectorContent.apiImages[Math.floor(Math.random() * wallpaperSelectorContent.apiImages.length)];
                        wallpaperSelectorContent.selectWallpaperPath(randomImg.actualPath || randomImg.filePath);
                    }
                } else if (wallpaperSelectorContent.favMode) {
                    const favs = Persistent.states.wallpaper.favourites;
                    if (favs.length > 0) {
                        const randomPath = favs[Math.floor(Math.random() * favs.length)];
                        wallpaperSelectorContent.selectWallpaperPath(randomPath);
                    }
                } else {
                    Wallpapers.randomFromCurrentFolder();
                }
            }
        text: "ifl"
        StyledToolTip {
            text: Translation.tr("Pick random from this folder")
        }
    }

    IconToolbarButton {
        implicitWidth: height
            onClicked: wallpaperSelectorContent.useDarkMode = !wallpaperSelectorContent.useDarkMode
            text: wallpaperSelectorContent.useDarkMode ? "dark_mode" : "light_mode"
        StyledToolTip {
            text: Translation.tr("Click to toggle light/dark mode\n(applied when wallpaper is chosen)")
        }
    }

    ToolbarTextField {
        id: filterField
        placeholderText: {
            if (wallpaperSelectorContent.browserMode) return Translation.tr("Search API (e.g. nature, city)");
            return focus ? Translation.tr("Search wallpapers") : Translation.tr("Hit \"/\" to search")
        }

        // Style
        clip: true
        font.pixelSize: Appearance.font.pixelSize.small

        // Search
        onTextChanged: {
            if (!wallpaperSelectorContent.browserMode) {
                Wallpapers.searchQuery = text;
                if (wallpaperSelectorContent.favMode) {
                    wallpaperSelectorContent.refreshFavourites();
                }
            }
        }

        onAccepted: {
            if (wallpaperSelectorContent.browserMode && text.trim().length > 0) {
                const newTags = text.trim().split(/\s+/);
                const allTags = [...newTags];
                wallpaperSelectorContent.moreOptionsModelData = null
                WallpaperBrowser.clearResponses();
                WallpaperBrowser.makeRequest(allTags, 20, 1);
                grid.currentIndex = 0;
                text = "";
            }
        }

        Keys.onPressed: event => {
            if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_V) { // Intercept Ctrl+V to handle "paste to go to" in pickers
                wallpaperSelectorContent.handleFilePasting(event);
                return;
            }
            else if (text.length !== 0) {
                // No filtering, just navigate grid
                if (event.key === Qt.Key_Down) {
                    grid.moveSelection(grid.columns);
                    event.accepted = true;
                    return;
                }
                if (event.key === Qt.Key_Up) {
                    grid.moveSelection(-grid.columns);
                    event.accepted = true;
                    return;
                }
            }
            event.accepted = false;
        }
    }

    IconToolbarButton {
        implicitWidth: height
        onClicked: {
            GlobalStates.wallpaperSelectorOpen = false;
        }
        text: "close"
        StyledToolTip {
            text: Translation.tr("Cancel wallpaper selection")
        }
    }                        
}