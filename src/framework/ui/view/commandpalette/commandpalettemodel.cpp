/*
 * SPDX-License-Identifier: GPL-3.0-only
 * MuseScore-CLA-applies
 *
 * MuseScore
 * Music Composition & Notation
 *
 * Copyright (C) 2021 MuseScore Limited and others
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
#include "commandpalettemodel.h"

#include "log.h"

using namespace muse;
using namespace muse::ui;
using namespace muse::shortcuts;

CommandPaletteModel::CommandPaletteModel(QObject* parent)
    : QAbstractListModel(parent)
{
}

int CommandPaletteModel::rowCount(const QModelIndex&) const
{
    return static_cast<int>(m_filteredCommands.size());
}

QVariant CommandPaletteModel::data(const QModelIndex& index, int role) const
{
    if (!index.isValid() || index.row() >= static_cast<int>(m_filteredCommands.size())) {
        return QVariant();
    }

    const CommandItem& item = m_filteredCommands[index.row()];

    switch (role) {
    case ActionCodeRole:
        return QString::fromStdString(item.actionCode);
    case TitleRole:
        return item.title;
    case DescriptionRole:
        return item.description;
    case ShortcutRole:
        return item.shortcut;
    case CategoryRole:
        return item.category;
    case IsEnabledRole:
        return item.isEnabled;
    }

    return QVariant();
}

QHash<int, QByteArray> CommandPaletteModel::roleNames() const
{
    return {
        { ActionCodeRole, "actionCode" },
        { TitleRole, "title" },
        { DescriptionRole, "description" },
        { ShortcutRole, "shortcut" },
        { CategoryRole, "category" },
        { IsEnabledRole, "isEnabled" }
    };
}

void CommandPaletteModel::setSearchText(const QString& text)
{
    if (m_searchText == text) {
        return;
    }

    m_searchText = text;
    emit searchTextChanged();
    updateFilteredCommands();
}

void CommandPaletteModel::setSelectedIndex(int index)
{
    if (m_selectedIndex == index) {
        return;
    }

    if (index < 0 || index >= static_cast<int>(m_filteredCommands.size())) {
        return;
    }

    m_selectedIndex = index;
    emit selectedIndexChanged();
}

void CommandPaletteModel::load()
{
    TRACEFUNC;

    beginResetModel();

    m_allCommands.clear();

    // 全アクションを取得
    std::vector<UiAction> actions = actionsRegister()->actionList();

    for (const UiAction& action : actions) {
        if (!action.isValid()) {
            continue;
        }

        // タイトルが空のアクションはスキップ
        QString title = action.title.qTranslatedWithoutMnemonic();
        if (title.isEmpty()) {
            continue;
        }

        CommandItem item;
        item.actionCode = action.code;
        item.title = title;
        
        item.description = action.description.qTranslated();
        item.category = extractCategory(action.code);

        // ショートカット情報の取得
        const Shortcut& shortcut = shortcutsRegister()->shortcut(action.code);
        item.shortcut = formatShortcut(shortcut);
        // デフォルト値を true に設定してから状態を取得
        item.isEnabled = true;
        
        // アクションの状態を取得
        UiActionState state = actionsRegister()->actionState(action.code);
        if (state.enabled) {
            item.isEnabled = state.enabled;
        }

        m_allCommands.push_back(item);
    }

    endResetModel();

    LOGI() << "Loaded " << m_allCommands.size() << " commands";

    updateFilteredCommands();
}

void CommandPaletteModel::updateFilteredCommands()
{
    beginResetModel();

    m_filteredCommands.clear();

    QString lowerSearch = m_searchText.toLower();

    for (const CommandItem& item : m_allCommands) {
        // 検索フィルタリング
        if (m_searchText.isEmpty() ||
            item.title.toLower().contains(lowerSearch) ||
            item.description.toLower().contains(lowerSearch) ||
            item.category.toLower().contains(lowerSearch) ||
            QString::fromStdString(item.actionCode).toLower().contains(lowerSearch)) {
            m_filteredCommands.push_back(item);
        }
    }

    // 有効なコマンドを上位にソート（この部分を追加）
    std::stable_sort(m_filteredCommands.begin(), m_filteredCommands.end(),
                     [](const CommandItem& a, const CommandItem& b) {
                         if (a.isEnabled != b.isEnabled) {
                             return a.isEnabled > b.isEnabled;  // 有効なものが先
                         }
                         return false;  // 元の順序を保持
                     });

    // 最大表示件数を制限(パフォーマンス対策)
    if (m_filteredCommands.size() > 100) {
        m_filteredCommands.resize(100);
    }

    endResetModel();

    // 選択インデックスをリセット
    m_selectedIndex = 0;
    emit selectedIndexChanged();

    LOGD() << "Filtered to " << m_filteredCommands.size() << " commands (search: " << m_searchText << ")";
}

QString CommandPaletteModel::formatShortcut(const Shortcut& shortcut) const
{
    if (shortcut.sequences.empty()) {
        return QString();
    }

    QStringList sequences;
    for (const std::string& seq : shortcut.sequences) {
        sequences << QString::fromStdString(seq);
    }

    return sequences.join(", ");
}

QString CommandPaletteModel::extractCategory(const std::string& actionCode) const
{
    // アクションコードからカテゴリを抽出
    // 例: "file-open" -> "file"
    std::string codeStr = actionCode;
    size_t dashPos = codeStr.find('-');
    
    if (dashPos != std::string::npos) {
        std::string category = codeStr.substr(0, dashPos);
        // 最初の文字を大文字に
        if (!category.empty()) {
            category[0] = std::toupper(category[0]);
        }
        return QString::fromStdString(category);
    }

    return QString("Other");
}

void CommandPaletteModel::executeSelectedCommand()
{
    executeCommand(m_selectedIndex);
}

void CommandPaletteModel::executeCommand(int index)
{
    if (index < 0 || index >= static_cast<int>(m_filteredCommands.size())) {
        LOGE() << "Invalid command index: " << index;
        return;
    }

    const CommandItem& item = m_filteredCommands[index];

    LOGI() << "Executing command: " << item.actionCode;

    // アクションを実行
    actionsRegister()->action(item.actionCode);

    // ダイアログを閉じる
    emit closeRequested();
}