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
import MuseScore.InstrumentsScene 1.0 // InstrumentsOnScoreListModel, InstrumentListModel をインポート

import "internal"
// QMLリポジトリとFavoritesViewをインポート
import "./" // InstrumentSetRepository.qml と FavoritesView.qml

Rectangle {
    id: root

    // --- Properties ---
    // C++モデルを受け取る
    required property InstrumentsOnScoreListModel instrumentsOnScoreModel

    property bool canSelectMultipleInstruments: true
    property string currentInstrumentId: ""
    property string description: instrumentsModel.selectedInstrument ? instrumentsModel.selectedInstrument.description : ""

    readonly property bool hasSelectedInstruments: root.canSelectMultipleInstruments
                                                  ? instrumentsOnScoreModel.count > 0
                                                  : Boolean(instrumentsModel.selectedInstrument)

    property NavigationSection navigationSection: null
    property alias navigation: instrumentsView.navigation // Alias for navigation control

    // QMLリポジトリのインスタンス
    InstrumentSetRepository { id: instrumentSetRepositoryQml }

    // FavoritesViewに渡すためのデータ保持用プロパティ
    property var currentFavoritesModel: []

    // --- Signals ---
    signal submitRequested() // Usually for single instrument selection mode

    // --- Functions ---
    // Get instrument data (for external use if needed)
    function instruments() {
        if (root.canSelectMultipleInstruments) {
            // ★注意: このinstruments()は詳細データを返す古いもの。IDリスト取得は getCurrentInstrumentIds() を使う
            return root.instrumentsOnScoreModel.instruments()
        }
        return [ instrumentsModel.selectedInstrument ]
    }

    // Get current score order data (for external use if needed)
    function currentOrder() {
        if (root.canSelectMultipleInstruments) {
            return root.instrumentsOnScoreModel.currentOrder()
        }
        return undefined
    }

    // Set initial focus
    function focusOnFirst() {
        familyView.focusOnFirst()
    }

    // Save the current set of instruments in the score panel as a favorite
    function saveCurrentSet() {
        console.log("saveCurrentSet: Attempting to get IDs from C++...");

        // 1. C++の Invokable メソッドを呼び出してIDリストを取得
        var idList = root.instrumentsOnScoreModel.getCurrentInstrumentIds();
        console.log("saveCurrentSet: Received IDs from C++:", JSON.stringify(idList));

        // 2. 取得したIDリストが有効かチェック
        if (!idList || !Array.isArray(idList) || idList.length === 0) {
             console.warn("Save failed: C++ method returned no valid IDs, or score panel is empty.");
             // Optionally provide user feedback here (e.g., update a status label)
             return; // IDがなければ保存しない
        }

        // 3. 既存のセットをロードして次のセット名を決定 ("お気に入りX" 形式)
        var sets = instrumentSetRepositoryQml.loadSets();
        var maxNum = 0;
        var favoriteSets = sets.filter(function(item) {
            // Check if setName exists, is a string, and starts with "お気に入り"
            return item.setName && typeof item.setName === 'string' && item.setName.startsWith("お気に入り");
        });
        favoriteSets.forEach(function(item) {
            // Extract number using regex for safety
            var numMatch = item.setName.match(/^お気に入り(\d+)$/);
            if (numMatch && numMatch[1]) {
                var num = parseInt(numMatch[1], 10);
                if (!isNaN(num) && num > maxNum) {
                    maxNum = num;
                }
            }
        });
        var newName = "お気に入り" + (maxNum + 1);

        // 4. QMLリポジトリに保存
        console.log("Saving set:", newName, "with IDs:", JSON.stringify(idList));
        var saved = instrumentSetRepositoryQml.saveSet(newName, idList);

        // 5. 保存後、モデルデータを再ロードしてUI (FavoritesView) を更新
        if (saved) {
            currentFavoritesModel = instrumentSetRepositoryQml.loadSets(); // Update the property bound to FavoritesView
            console.log("Successfully saved set:", newName);
        } else {
             console.error("Failed to save set:", newName);
             // Optionally provide user feedback about the failure
        }
    }

    // Apply a favorite set (replace instruments in the score panel)
    function applyFavoriteSet(setData) {
        // Validate the received data
        if (!setData || !setData.instrumentIds || !Array.isArray(setData.instrumentIds) || setData.instrumentIds.length === 0) {
            console.warn("Apply failed: Invalid favorite set data received.", JSON.stringify(setData));
            return;
        }
        console.log("Applying favorite set:", setData.setName, "with IDs:", JSON.stringify(setData.instrumentIds));
        // Call the helper function in 'prv' object
        prv.applyPresetIds(setData.instrumentIds);
    }

    // --- Visual ---
    color: ui.theme.backgroundPrimaryColor

    // --- Models ---
    // Model for the central instrument list (C++ based)
    InstrumentListModel {
        id: instrumentsModel
        // onLoadFinished removed (assuming no panel switching)
        onFocusRequested: function(groupIndex, instrumentIndex) {
            familyView.scrollToGroup(groupIndex)
            instrumentsView.focusInstrument(instrumentIndex)
        }
    }

    // --- Helper Object ---
    // Contains helper functions, especially for applying presets/sets
    QtObject {
        id: prv

        // Function called when adding from central list (-> button or double-click)
        function addSelectedInstrumentsToScore() {
            var selectedIds = instrumentsModel.selectedInstrumentIdList();
            if (selectedIds && selectedIds.length > 0) {
                root.instrumentsOnScoreModel.addInstruments(selectedIds);
                Qt.callLater(instrumentsOnScoreView.scrollViewToEnd); // Scroll after update
            } else {
                 console.warn("addSelectedInstrumentsToScore: No instruments selected.");
            }
        }

        // --- Preset applying functions ---
        // These call the common helper function 'applyPresetIds'
        function addMyOrchestra() {
             console.log("Applying My Orchestra preset...");
             // ★ Ensure these IDs are correct ★
             applyPresetIds(["violin","viola", "violoncello", "contrabass"]);
        }
        function addJazzTrio() {
             console.log("Applying Jazz Trio preset...");
             // ★ Ensure these IDs are correct ★
             applyPresetIds(["piano", "banjo", "drumset"]);
        }
        function addBrassQuintet() {
             console.log("Applying Brass Quintet preset...");
             // ★ Ensure these IDs are correct ★
             applyPresetIds(["bb-trumpet", "bb-cornet", "horn", "trombone", "tuba"]);
        }

        // --- Common helper function to apply a list of instrument IDs ---
        // Clears the score panel and adds the provided instruments
        function applyPresetIds(ids) {
             // 1. Validate the input ID list
             if (!ids || !Array.isArray(ids) || ids.length === 0) {
                 console.warn("applyPresetIds: Invalid ID list provided.");
                 return;
             }
             // 2. Check if the C++ model is available
             if (!root.instrumentsOnScoreModel) {
                  console.error("applyPresetIds: InstrumentsOnScoreListModel not available!");
                  return;
             }

             // 3. Clear existing instruments (check if 'clear' exists)
             if (typeof root.instrumentsOnScoreModel.clear === "function") {
                 console.log("applyPresetIds: Clearing existing instruments...");
                 root.instrumentsOnScoreModel.clear();
             } else {
                  console.warn("applyPresetIds: 'clear' function not found on model. Cannot clear existing instruments.");
                  // Decide if you want to proceed adding without clearing, or stop
                  // return; // Stop if clearing is essential
             }

             // 4. Add new instruments (check if 'addInstruments' exists)
             if (typeof root.instrumentsOnScoreModel.addInstruments === "function") {
                 console.log("applyPresetIds: Adding instruments:", JSON.stringify(ids));
                 root.instrumentsOnScoreModel.addInstruments(ids);
                 // 5. Scroll to end after a delay to ensure UI updates
                 Qt.callLater(instrumentsOnScoreView.scrollViewToEnd);
             } else {
                  console.error("applyPresetIds: 'addInstruments' function not found on model!");
             }
        }
    } // End QtObject prv

    // ▼▼▼ 追加: 削除関数 ▼▼▼
    function deleteFavoriteSet(setName) {
        console.log("Attempting to delete set:", setName);
        var deleted = instrumentSetRepositoryQml.deleteSet(setName); // QMLリポジトリの削除関数を呼び出す

        if (deleted) { // 削除が成功したら
            // モデルデータを再ロードしてUIを更新
            currentFavoritesModel = instrumentSetRepositoryQml.loadSets();
            console.log("Successfully deleted set and updated model.");
        } else {
            console.error("Failed to delete set:", setName);
            // 必要であればユーザーにエラー通知
        }
    }
    // ▲▲▲ 追加 ▲▲▲

    // --- Lifecycle Handler ---
    Component.onCompleted: {
        // Load the central instrument list model
        instrumentsModel.load(canSelectMultipleInstruments, currentInstrumentId);
        // Load saved favorite sets from the QML repository
        currentFavoritesModel = instrumentSetRepositoryQml.loadSets();
        console.log("ChooseInstrumentsPage loaded. Initial favorites:", JSON.stringify(currentFavoritesModel));
    }

    // --- Layout ---
    RowLayout {
        anchors.fill: parent
        spacing: 12 // Space between panels

        // Left Panel: Families/Groups
        FamilyView {
            id: familyView
            Layout.minimumWidth: 200
            Layout.preferredWidth: root.canSelectMultipleInstruments ? Math.max(200, root.width / 5) : 0 // Adjust width dynamically
            Layout.fillWidth: !root.canSelectMultipleInstruments
            Layout.fillHeight: true
            navigation.section: root.navigationSection
            navigation.order: 2
            // Bind directly to the C++ model for genres/groups
            genres: instrumentsModel.genres
            groups: instrumentsModel.groups
            currentGenreIndex: instrumentsModel.currentGenreIndex
            currentGroupIndex: instrumentsModel.currentGroupIndex
            // Simple genre selection handler (no panel switching)
            onGenreSelected: function(newIndex) {
                 instrumentsModel.currentGenreIndex = newIndex;
                 instrumentsView.clearSearch(); // Clear search in central panel
            }
            onGroupSelected: function(newIndex) {
                 instrumentsModel.currentGroupIndex = newIndex;
                 if (instrumentsView.searching) {
                     instrumentsModel.saveCurrentGroup(); // Remember group if searching
                     instrumentsView.clearSearch();
                 }
                 focusGroupNavigation(newIndex); // Internal navigation helper
            }
        }

        SeparatorLine { orientation: Qt.Vertical }

        // Favorites Panel
        FavoriteView { // ★ Ensure this matches your file name (FavoritesView.qml) ★
            id: favoritesView
            Layout.minimumWidth: 180
            Layout.preferredWidth: root.canSelectMultipleInstruments ? Math.max(180, root.width / 5) : 0 // Adjust width
            Layout.fillWidth: !root.canSelectMultipleInstruments
            Layout.fillHeight: true
            // Bind the data model for user sets
            userFavoritesModel: currentFavoritesModel
            // --- Signal Handlers ---
            // Connect signals from FavoritesView to functions in this component
            onAddFavoriteSetRequested: { root.saveCurrentSet(); }
            onFavoriteSetActivated: function(setData) { root.applyFavoriteSet(setData); }
            onMyOrchestraRequested: { prv.addMyOrchestra(); }
            onJazzTrioRequested: { prv.addJazzTrio(); }
            onBrassQuintetRequested: { prv.addBrassQuintet(); }

            // ▼▼▼ 追加: 削除リクエストハンドラ ▼▼▼
            onDeleteFavoriteSetRequested: function(setName) {
                root.deleteFavoriteSet(setName); // 上で定義した削除関数を呼び出す
            }
            // ▲▲▲ 追加 ▲▲▲
        }

        SeparatorLine { orientation: Qt.Vertical }

        // Central Panel: Instrument List
        InstrumentsView {
            id: instrumentsView
            Layout.minimumWidth: 276
            Layout.preferredWidth: root.canSelectMultipleInstruments ? Math.max(276, root.width / 4) : 0 // Adjust width
            Layout.fillWidth: !root.canSelectMultipleInstruments
            Layout.fillHeight: true
            navigation.section: root.navigationSection
            navigation.order: 3
            // Provide the C++ model for the list
            instrumentsModel: instrumentsModel
            // Handle request to add selected instrument(s)
            onAddSelectedInstrumentsToScoreRequested: {
                if (root.canSelectMultipleInstruments) {
                    prv.addSelectedInstrumentsToScore();
                } else {
                    // Handle single selection mode submission
                    root.submitRequested();
                }
            }
        }

        SeparatorLine {
            visible: root.canSelectMultipleInstruments
            orientation: Qt.Vertical
        }

        // Add Button (Arrow Right)
        FlatButton {
            id: addButton
            NavigationPanel { /* ... Navigation properties ... */ }
            navigation.name: "Select"
            /* ... Navigation properties ... */
            toolTipTitle: qsTrc("instruments", "Add selected instruments to score")
            visible: root.canSelectMultipleInstruments
            Layout.preferredWidth: 30
            enabled: instrumentsModel.hasSelection // Enable only when items are selected in central list
            icon: IconCode.ARROW_RIGHT
            onClicked: {
                prv.addSelectedInstrumentsToScore();
            }
        }

        SeparatorLine {
            visible: root.canSelectMultipleInstruments
            orientation: Qt.Vertical
        }

        // Right Panel: Instruments on Score
        InstrumentsOnScoreView {
            id: instrumentsOnScoreView
            navigation.section: root.navigationSection
            navigation.order: 5
            visible: root.canSelectMultipleInstruments
            Layout.fillWidth: true // Takes remaining width
            Layout.fillHeight: true
            // Provide the C++ model for instruments currently on the score
            instrumentsOnScoreModel: root.instrumentsOnScoreModel
        }

        SeparatorLine {
            visible: root.canSelectMultipleInstruments
            orientation: Qt.Vertical
        }

        // Up/Down Buttons Column
        Column {
            visible: root.canSelectMultipleInstruments
            Layout.preferredWidth: 30
            Layout.alignment: Qt.AlignVCenter
            spacing: 12
            NavigationPanel { /* ... Navigation properties ... */ }
            FlatButton { // Up Button
                enabled: root.instrumentsOnScoreModel.isMovingUpAvailable
                icon: IconCode.ARROW_UP
                /* ... Navigation properties ... */
                toolTipTitle: qsTrc("instruments", "Move selected instruments up")
                onClicked: { root.instrumentsOnScoreModel.moveSelectionUp(); }
            }
            FlatButton { // Down Button
                enabled: root.instrumentsOnScoreModel.isMovingDownAvailable
                icon: IconCode.ARROW_DOWN
                /* ... Navigation properties ... */
                toolTipTitle: qsTrc("instruments", "Move selected instruments down")
                onClicked: { root.instrumentsOnScoreModel.moveSelectionDown(); }
            }
        }
    } // End RowLayout
} // End Rectangle