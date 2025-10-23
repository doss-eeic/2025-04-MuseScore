/*
 * SPDX-License-Identifier: GPL-3.0-only
 * MuseScore-Studio-CLA-applies
 *
 * MuseScore Studio
 * Music Composition & Notation
 *
 * Copyright (C) 2021 MuseScore Limited
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

import Muse.Ui 1.0
import Muse.UiComponents 1.0

import MuseScore.AppShell 1.0

StyledDialogView {
    id: root

    title: qsTrc("appshell", "Command Palette")

    contentWidth: 700
    contentHeight: 500

    CommandPaletteModel {
        id: commandPaletteModel

        onCloseRequested: {
            root.hide()
        }
    }

    Component.onCompleted: {
        commandPaletteModel.load()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 12

        // 検索フィールド
        SearchField {
            id: searchField
            Layout.fillWidth: true

            onSearchTextChanged: {
                commandPaletteModel.searchText = searchText
            }

            Component.onCompleted: {
                forceActiveFocus()
            }

            Keys.onDownPressed: {
                commandsList.incrementCurrentIndex()
            }

            Keys.onUpPressed: {
                commandsList.decrementCurrentIndex()
            }

            Keys.onReturnPressed: {
                commandPaletteModel.executeSelectedCommand()
            }

            Keys.onEscapePressed: {
                root.hide()
            }
        }

        ListView {
            id: commandsList
            Layout.fillWidth: true
            Layout.fillHeight: true

            model: commandPaletteModel
            clip: true
            
            currentIndex: commandPaletteModel.selectedIndex

            onCurrentIndexChanged: {
                commandPaletteModel.selectedIndex = currentIndex
            }

            delegate: ListItemBlank {
                width: commandsList.width
                height: 50

                isSelected: commandsList.currentIndex === index

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 12

                    StyledTextLabel {
                        Layout.fillWidth: true
                        text: model.title
                        font: ui.theme.bodyBoldFont
                        horizontalAlignment: Text.AlignLeft
                        opacity: model.isEnabled ? 1.0 : 0.4  // この行を変更（110行目付近）
                    }

                    StyledTextLabel {
                        visible: model.shortcut !== ""
                        text: model.shortcut
                        opacity: model.isEnabled ? 0.6 : 0.3  // この行を変更（116行目付近）
                        font: ui.theme.bodyFont
                    }
                }

                onClicked: {
                    console.log("=== QML: onClicked triggered ===")
                    console.log("Index:", index)
                    console.log("model.isEnabled:", model.isEnabled)
                    console.log("commandPaletteModel:", commandPaletteModel)
                    
                    if (model.isEnabled) {
                        console.log("Calling executeCommand with index:", index)
                        commandPaletteModel.executeCommand(index)
                    } else {
                        console.log("Command is disabled, not executing")
                    }
                }
            }
            ScrollBar.vertical: StyledScrollBar {}
        }
    }
}