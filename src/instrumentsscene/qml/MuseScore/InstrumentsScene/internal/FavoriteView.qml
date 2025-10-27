import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15

import Muse.Ui 1.0
import Muse.UiComponents 1.0

ColumnLayout {
    id: root

    // ▼▼▼ 各ボタンに対応するシグナルを定義 ▼▼▼
    signal myOrchestraRequested()
    signal jazzTrioRequested()
    signal brassQuintetRequested()

    signal addFavoriteSetRequested() // 「追加」ボタン用
    signal favoriteSetActivated(var setData) // 動的ボタン用 (今は使わない)
    // (既存プリセット用のシグナルは削除またはコメントアウト)
    signal deleteFavoriteSetRequested(string setName) // ★削除リクエスト用シグナル追加★

    // --- プロパティ ---
    property var userFavoritesModel: [] // ChooseInstrumentsPageからデータを受け取る

    spacing: 8 // 見出しとボタン、ボタン間の縦の間隔

    // (1) 一番上に「プリセット」の見出し
    StyledTextLabel {
        Layout.fillWidth: true // 幅をカラムいっぱいに広げる
        font: ui.theme.bodyBoldFont
        text: qsTrc("instruments", "プリセット") // 見出し
        horizontalAlignment: Text.AlignLeft // 左寄せ
    }

    // (2) 見出しの下にボタンを縦に並べる
    FlatButton {
        Layout.fillWidth: true // 幅をカラムいっぱいに広げる
        text: qsTrc("instruments", "オーケストラ")

        onClicked: {
            root.myOrchestraRequested() // 対応するシグナルを発信
        }
    }

    FlatButton {
        Layout.fillWidth: true
        text: qsTrc("instruments", "ジャズトリオ")

        onClicked: {
            root.jazzTrioRequested() // 対応するシグナルを発信
        }
    }

    FlatButton {
        Layout.fillWidth: true
        text: qsTrc("instruments", "金管五重奏")

        onClicked: {
            root.brassQuintetRequested() // 対応するシグナルを発信
        }
    }

    // Repeaterを使ってユーザー保存セットからボタンを生成
    Repeater {
        id: favoriteButtonsRepeater
        model: root.userFavoritesModel

        delegate: FlatButton { // ★ボタン全体を MouseArea で囲む★
            id: favButton
            width: root.width
            text: modelData.setName

            // ▼▼▼ この MouseArea を追加 ▼▼▼
            MouseArea {
                id: mouseArea
                anchors.fill: parent // ボタン全体を覆う
                acceptedButtons: Qt.LeftButton | Qt.RightButton // 左クリックと右クリックを受け付ける

                onClicked: (mouse) => { // mouse引数を追加
                    if (mouse.button === Qt.LeftButton) {
                        // 左クリック時は従来通りセットを適用
                        console.log("Left clicked:", modelData.setName);
                        root.favoriteSetActivated(modelData);
                    } else if (mouse.button === Qt.RightButton) {
                        // 右クリック時は削除メニューを表示
                        console.log("Right clicked:", modelData.setName);
                        deleteMenu.popup(); // 下で定義するメニューを表示
                    }
                }

                // ▼▼▼ 右クリックメニュー ▼▼▼
                Menu {
                   id: deleteMenu
                   MenuItem {
                       text: qsTr("削除") // "削除"
                       onTriggered: {
                           console.log("Delete triggered for:", modelData.setName);
                           // 削除リクエストシグナルを発信 (セット名を渡す)
                           root.deleteFavoriteSetRequested(modelData.setName);
                       }
                   }
                } // ▲▲▲ Menu ▲▲▲
            } // ▲▲▲ MouseArea ▲▲▲
        } // End delegate: FlatButton
    } // End Repeater

    // ▼▼▼ 追加 ▼▼▼: 余ったスペースを埋めるための空のアイテム
    Item {
        Layout.fillHeight: true // 利用可能な垂直スペースをすべて占有する
    }
    // ▲▲▲ 追加 ▲▲▲

    // (必要に応じて、さらにボタンを追加)

    FlatButton {
        id: addButton
        Layout.fillWidth: true
        text: qsTrc("instruments", "セットに追加")
        icon: IconCode.PLUS
        onClicked: {
            console.log("FavoritesView: 'セットに追加' button clicked, emitting signal.");
            root.addFavoriteSetRequested() // シグナルを発信
        }
    }

}