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
import QtQuick.Layouts 1.15

import Muse.Ui 1.0
import Muse.UiComponents 1.0
import MuseScore.InstrumentsScene 1.0

import "internal"
// ▼▼▼ 追加 ▼▼▼: 新しく作成したFavoritesView.qmlをインポートします
import "./"

Rectangle {
    id: root

    required property InstrumentsOnScoreListModel instrumentsOnScoreModel

    property bool canSelectMultipleInstruments: true
    property string currentInstrumentId: ""
    property string description: instrumentsModel.selectedInstrument ? instrumentsModel.selectedInstrument.description : ""

    readonly property bool hasSelectedInstruments: root.canSelectMultipleInstruments
                                                  ? instrumentsOnScoreModel.count > 0
                                                  : Boolean(instrumentsModel.selectedInstrument)

    property NavigationSection navigationSection: null
    property alias navigation: instrumentsView.navigation
    signal submitRequested()

    function instruments() {
        if (root.canSelectMultipleInstruments) {
            return root.instrumentsOnScoreModel.instruments()
        }
        return [ instrumentsModel.selectedInstrument ]
    }

    function currentOrder() {
        if (root.canSelectMultipleInstruments) {
            return root.instrumentsOnScoreModel.currentOrder()
        }
        return undefined
    }

    function focusOnFirst() {
        familyView.focusOnFirst()
    }

    color: ui.theme.backgroundPrimaryColor

    InstrumentListModel {
        id: instrumentsModel
        onFocusRequested: function(groupIndex, instrumentIndex) {
            familyView.scrollToGroup(groupIndex)
            instrumentsView.focusInstrument(instrumentIndex)
        }
    }

    QtObject {
        id: prv
        function addSelectedInstrumentsToScore() {
            root.instrumentsOnScoreModel.addInstruments(instrumentsModel.selectedInstrumentIdList())
            Qt.callLater(instrumentsOnScoreView.scrollViewToEnd)
        }
            // ▼▼▼ この関数を丸ごと追加 ▼▼▼
        function addMyOrchestra() {
            // ★重要★: IDを正確に調べてください (例: "violin", "viola")
            var ids = ["violin", "viola", "cello", "double-bass"];
            if (!root.instrumentsOnScoreModel) {
                console.warn("addMyOrchestra: instrumentsOnScoreModel not available");
                return;
            }
            if (typeof root.instrumentsOnScoreModel.addInstruments === "function") {
                // 既存の楽器に追加する
                root.instrumentsOnScoreModel.addInstruments(ids);
            } else {
                console.error("addMyOrchestra: Cannot add instruments! addInstruments function not found.");
            }
            Qt.callLater(instrumentsOnScoreView.scrollViewToEnd);
        }
        // ▲▲▲ 追加ここまで ▲▲▲
        // ▼▼▼ この関数を追加 ▼▼▼
        function addJazzTrio() {
            // ★重要★: ジャズトリオの楽器ID (例: ピアノ, ベース, ドラム) を正確に調べてください
            var ids = ["piano", "double-bass", "drumset"]; // 仮のIDです
            if (!root.instrumentsOnScoreModel) { console.warn("addJazzTrio: model not available"); return; }
            if (typeof root.instrumentsOnScoreModel.addInstruments === "function") {
                root.instrumentsOnScoreModel.addInstruments(ids);
            } else { console.error("addJazzTrio: addInstruments function not found."); }
            Qt.callLater(instrumentsOnScoreView.scrollViewToEnd);
        }

        // ▼▼▼ この関数を追加 ▼▼▼
        function addBrassQuintet() {
            // ★重要★: 金管五重奏の楽器ID (例: トランペットx2, ホルン, トロンボーン, チューバ) を正確に調べてください
            var ids = ["trumpet", "trumpet", "horn", "trombone", "tuba"]; // 仮のIDです
            if (!root.instrumentsOnScoreModel) { console.warn("addBrassQuintet: model not available"); return; }
            if (typeof root.instrumentsOnScoreModel.addInstruments === "function") {
                root.instrumentsOnScoreModel.addInstruments(ids);
            } else { console.error("addBrassQuintet: addInstruments function not found."); }
            Qt.callLater(instrumentsOnScoreView.scrollViewToEnd);
        }
        // ▲▲▲ 追加ここまで ▲▲▲
        
    }

    Component.onCompleted: {
        instrumentsModel.load(canSelectMultipleInstruments, currentInstrumentId)
    }

    RowLayout {
        anchors.fill: parent
        spacing: 12

        FamilyView {
            id: familyView
            Layout.minimumWidth: 200
            Layout.preferredWidth: root.canSelectMultipleInstruments ? root.width / 5 : 0
            Layout.fillWidth: !root.canSelectMultipleInstruments
            Layout.fillHeight: true
            navigation.section: root.navigationSection
            navigation.order: 2
            genres: instrumentsModel.genres
            groups: instrumentsModel.groups
            currentGenreIndex: instrumentsModel.currentGenreIndex
            currentGroupIndex: instrumentsModel.currentGroupIndex
            onGenreSelected: function(newIndex) {
                instrumentsModel.currentGenreIndex = newIndex
                instrumentsView.clearSearch()
            }
            onGroupSelected: function(newIndex) {
                instrumentsModel.currentGroupIndex = newIndex
                if (instrumentsView.searching) {
                    instrumentsModel.saveCurrentGroup()
                    instrumentsView.clearSearch()
                }
                focusGroupNavigation(newIndex)
            }
        }

        SeparatorLine { orientation: Qt.Vertical }

        // ▼▼▼ 追加 ▼▼▼: FamilyViewの隣にFavoritesViewを配置します
        FavoriteView {
            id: favoritesView
            Layout.minimumWidth: 200
            Layout.preferredWidth: root.canSelectMultipleInstruments ? root.width / 5 : 0
            Layout.fillWidth: !root.canSelectMultipleInstruments
            Layout.fillHeight: true

            // ▼▼▼ このハンドラを追加 ▼▼▼
            onMyOrchestraRequested: {
                prv.addMyOrchestra() // prv内の関数を呼び出す
            }
            // ▲▲▲ 追加ここまで ▲▲▲

            // ▼▼▼ このハンドラを追加 ▼▼▼
            onJazzTrioRequested: {
                prv.addJazzTrio() // 対応する関数を呼び出す
            }

            // ▼▼▼ このハンドラを追加 ▼▼▼
            onBrassQuintetRequested: {
                prv.addBrassQuintet() // 対応する関数を呼び出す
            }
            // ▲▲▲ 追加ここまで ▲▲▲
        }
        // ▲▲▲ 追加 ▲▲▲

        SeparatorLine { orientation: Qt.Vertical }

        InstrumentsView {
            id: instrumentsView
            Layout.minimumWidth: 276
            Layout.preferredWidth: root.canSelectMultipleInstruments ? root.width / 4 : 0
            Layout.fillWidth: !root.canSelectMultipleInstruments
            Layout.fillHeight: true
            navigation.section: root.navigationSection
            navigation.order: 3
            instrumentsModel: instrumentsModel
            onAddSelectedInstrumentsToScoreRequested: {
                if (root.canSelectMultipleInstruments) {
                    prv.addSelectedInstrumentsToScore()
                } else {
                    root.submitRequested()
                }
            }
        }

        SeparatorLine {
            visible: root.canSelectMultipleInstruments
            orientation: Qt.Vertical
        }

        FlatButton {
            NavigationPanel {
                id: navSelectPanel
                name: "SelectPanel"
                enabled: root.enabled && root.visible
                section: root.navigationSection
                order: 4
            }
            navigation.name: "Select"
            navigation.panel: navSelectPanel
            navigation.order: 1
            toolTipTitle: qsTrc("instruments", "Add selected instruments to score")
            visible: root.canSelectMultipleInstruments
            Layout.preferredWidth: 30
            enabled: instrumentsModel.hasSelection
            icon: IconCode.ARROW_RIGHT
            onClicked: {
                prv.addSelectedInstrumentsToScore()
            }
        }

        SeparatorLine {
            visible: root.canSelectMultipleInstruments
            orientation: Qt.Vertical
        }

        InstrumentsOnScoreView {
            id: instrumentsOnScoreView
            navigation.section: root.navigationSection
            navigation.order: 5
            visible: root.canSelectMultipleInstruments
            Layout.fillWidth: true
            Layout.fillHeight: true
            instrumentsOnScoreModel: root.instrumentsOnScoreModel
        }

        SeparatorLine {
            visible: root.canSelectMultipleInstruments
            orientation: Qt.Vertical
        }

        Column {
            visible: root.canSelectMultipleInstruments
            Layout.preferredWidth: 30
            Layout.alignment: Qt.AlignVCenter
            spacing: 12
            NavigationPanel {
                id: navUpDownPanel
                name: "UpDownSelected"
                enabled: root.enabled && root.visible
                section: root.navigationSection
                order: 6
                direction: NavigationPanel.Vertical
            }
            FlatButton {
                enabled: root.instrumentsOnScoreModel.isMovingUpAvailable
                icon: IconCode.ARROW_UP
                navigation.name: "Up"
                navigation.panel: navUpDownPanel
                navigation.row: 1
                toolTipTitle: qsTrc("instruments", "Move selected instruments up")
                onClicked: {
                    root.instrumentsOnScoreModel.moveSelectionUp()
                }
            }
            FlatButton {
                enabled: root.instrumentsOnScoreModel.isMovingDownAvailable
                icon: IconCode.ARROW_DOWN
                navigation.name: "Down"
                navigation.panel: navUpDownPanel
                navigation.row: 2
                toolTipTitle: qsTrc("instruments", "Move selected instruments down")
                onClicked: {
                    root.instrumentsOnScoreModel.moveSelectionDown()
                }
            }
        }
    }
}