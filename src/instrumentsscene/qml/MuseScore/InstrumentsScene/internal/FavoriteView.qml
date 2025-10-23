import QtQuick 2.15
import QtQuick.Layouts 1.15

import Muse.Ui 1.0
import Muse.UiComponents 1.0

ColumnLayout {
    id: root

    // ▼▼▼ 各ボタンに対応するシグナルを定義 ▼▼▼
    signal myOrchestraRequested()
    signal jazzTrioRequested()
    signal brassQuintetRequested()

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

    // ▼▼▼ 追加 ▼▼▼: 余ったスペースを埋めるための空のアイテム
    Item {
        Layout.fillHeight: true // 利用可能な垂直スペースをすべて占有する
    }
    // ▲▲▲ 追加 ▲▲▲

    // (必要に応じて、さらにボタンを追加)

}