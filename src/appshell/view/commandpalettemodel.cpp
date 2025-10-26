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
#include "commandpalettemodel.h"
#include <algorithm>
#include <QSettings>
#include "log.h"

using namespace mu::appshell;
using namespace muse::actions;
using namespace muse::ui;
using namespace muse::shortcuts;

CommandPaletteModel::CommandPaletteModel(QObject* parent)
    : QAbstractListModel(parent)
{
    loadRecentCommands();
}

int CommandPaletteModel::rowCount(const QModelIndex&) const
{
    return m_filteredCommands.size();
}

QVariant CommandPaletteModel::data(const QModelIndex& index, int role) const
{
    if (!index.isValid() || index.row() >= m_filteredCommands.size()) {
        return QVariant();
    }

    const CommandItem& item = m_filteredCommands.at(index.row());

    switch (role) {
    case CodeRole: return QString::fromStdString(item.code);
    case TitleRole: return item.title;
    case DescriptionRole: return item.description;
    case CategoryRole: return item.category;
    case ShortcutRole: return item.shortcut;
    case IsEnabledRole: return item.isEnabled;
    }

    return QVariant();
}

QVariantList CommandPaletteModel::recentCommands() const
{
    LOGI() << "=== recentCommands() getter called ===";
    LOGI() << "m_recentCommands size: " << m_recentCommands.size();
    
    QVariantList list;

    for (const CommandItem& item : m_recentCommands) {
        QVariantMap map;
        map["code"] = QString::fromStdString(item.code);
        map["title"] = item.title;
        map["shortcut"] = item.shortcut;
        map["isEnabled"] = item.isEnabled;
        list << map;
        LOGI() << "  - " << item.title;
    }

    LOGI() << "Returning list with " << list.size() << " items";
    return list;
}

void CommandPaletteModel::clearRecentCommands()
{
    if (m_recentCommands.isEmpty()) {
        return;
    }

    m_recentCommands.clear();
    emit recentCommandsChanged();
}

void CommandPaletteModel::executeCommandByCode(const QString& code)
{
    auto it = std::find_if(m_filteredCommands.begin(), m_filteredCommands.end(),
                           [&](const CommandItem& item) {
                               return QString::fromStdString(item.code) == code;
                           });
    if (it == m_filteredCommands.end()) {
        return;
    }

    int index = std::distance(m_filteredCommands.begin(), it);
    executeCommand(index);
}


QHash<int, QByteArray> CommandPaletteModel::roleNames() const
{
    static const QHash<int, QByteArray> roles {
        { CodeRole, "code" },
        { TitleRole, "title" },
        { DescriptionRole, "description" },
        { CategoryRole, "category" },
        { ShortcutRole, "shortcut" },
        { IsEnabledRole, "isEnabled" } 
    };
    return roles;
}

QString CommandPaletteModel::searchText() const
{
    return m_searchText;
}

int CommandPaletteModel::selectedIndex() const
{
    return m_selectedIndex;
}

void CommandPaletteModel::load()
{
    LOGI() << "=== CommandPaletteModel::load() called ===";
    LOGI() << "Initial m_recentCommands size: " << m_recentCommands.size();
    
    beginResetModel();

    m_allCommands.clear();

    std::vector<UiAction> actions = actionsRegister()->actionList();
    for (const UiAction& action : actions) {
        CommandItem item;
        item.code = action.code;
        item.title = action.title.raw().translated().toQString();
        item.description = action.description.translated().toQString();
        
        item.shortcut = getShortcutForAction(action.code);
        item.isEnabled = true;  // デフォルト値

        m_allCommands.append(item);
    }

    m_filteredCommands = m_allCommands;

    endResetModel();

    // 最近使ったコマンドの情報を m_allCommands から復元
    QList<CommandItem> updatedRecentCommands;
    for (const CommandItem& recentItem : m_recentCommands) {
        LOGI() << "Looking for recent command: " << recentItem.code;
        auto it = std::find_if(m_allCommands.begin(), m_allCommands.end(),
                               [&](const CommandItem& cmd) { return cmd.code == recentItem.code; });
        if (it != m_allCommands.end()) {
            LOGI() << "Found: " << it->title;
            updatedRecentCommands.append(*it);
        } else {
            LOGI() << "Not found in all commands";
        }
    }
    
    // デバッグ: 最近使ったコマンドがない場合、テスト用に追加
    if (updatedRecentCommands.isEmpty() && !m_allCommands.isEmpty()) {
        LOGI() << "Adding test recent commands for debugging";
        // 最初の3つのコマンドをテストとして追加
        for (int i = 0; i < qMin(3, m_allCommands.size()); ++i) {
            updatedRecentCommands.append(m_allCommands[i]);
        }
    }
    
    m_recentCommands = updatedRecentCommands;
    LOGI() << "Updated m_recentCommands size: " << m_recentCommands.size();
    
    // 最近使ったコマンドの内容をログ出力
    for (const CommandItem& item : m_recentCommands) {
        LOGI() << "Recent: " << item.code << " - " << item.title;
    }
    
    emit recentCommandsChanged();

    emit selectedIndexChanged();
}

QString CommandPaletteModel::getShortcutForAction(const muse::actions::ActionCode& actionCode) const
{
    const Shortcut& shortcut = shortcutsRegister()->shortcut(actionCode);
    
    if (shortcut.sequences.empty()) {
        return QString();
    }
    
    // 最初のショートカットシーケンスを使用
    QString sequence = QString::fromStdString(shortcut.sequences.front());
    
    // プラットフォーム固有の表記に変換（Ctrl → ⌘ など）
    return formatShortcut(sequence);
}

QString CommandPaletteModel::formatShortcut(const QString& sequence) const
{
    QString formatted = sequence;
    
    // プラットフォーム固有の表記に変換
#ifdef Q_OS_MAC
    formatted.replace("Ctrl", "⌘");
    formatted.replace("Alt", "⌥");
    formatted.replace("Shift", "⇧");
#else
    // Linux/Windows では標準的な表記
    formatted.replace("Meta", "Super");
#endif
    
    // "+"を" + "に変換（見やすくする）
    formatted.replace("+", " + ");
    
    return formatted;
}


void CommandPaletteModel::setSearchText(const QString& text)
{
    if (m_searchText == text) {
        return;
    }

    m_searchText = text;
    filterCommands();
    emit searchTextChanged();
}

void CommandPaletteModel::setSelectedIndex(int index)
{
    if (m_selectedIndex == index) {
        return;
    }

    m_selectedIndex = qBound(0, index, m_filteredCommands.size() - 1);
    emit selectedIndexChanged();
}

void CommandPaletteModel::executeCommand(int index)
{
    LOGI() << "=== executeCommand called ===";
    LOGI() << "Index: " << index << ", Filtered size: " << m_filteredCommands.size();
    
    if (index < 0 || index >= m_filteredCommands.size()) {
        return;
    }

    const CommandItem& item = m_filteredCommands.at(index);
    LOGI() << "Executing: [" << item.code << "] " << item.title;
    dispatcher()->dispatch(item.code);

    auto it = std::find_if(m_recentCommands.begin(), m_recentCommands.end(),
                           [&](const CommandItem& cmd) { return cmd.code == item.code; });

    if (it != m_recentCommands.end()) {
        m_recentCommands.erase(it);               // 既にある場合は一度削除
    }

    m_recentCommands.prepend(item);               // 最新のものを先頭に追加

    if (m_recentCommands.size() > MAX_RECENT_COMMANDS) {
        m_recentCommands.removeLast();            // 最大件数を超えたら末尾を削除
    }

    emit recentCommandsChanged();
    saveRecentCommands();  // 最近使ったコマンドを保存

    emit closeRequested();
}

void CommandPaletteModel::executeSelectedCommand()
{
    executeCommand(m_selectedIndex);
}

void CommandPaletteModel::filterCommands()
{
    beginResetModel();

    m_filteredCommands.clear();

    if (m_searchText.isEmpty()) {
        m_filteredCommands = m_allCommands;
    } else {
        QString lowerSearch = m_searchText.toLower();
        for (const CommandItem& item : m_allCommands) {
            if (item.title.toLower().contains(lowerSearch)
                || item.description.toLower().contains(lowerSearch)
                || QString::fromStdString(item.code).toLower().contains(lowerSearch)) {
                m_filteredCommands.append(item);
            }
        }
    }

    m_selectedIndex = 0;

    endResetModel();

    emit selectedIndexChanged();
}

void CommandPaletteModel::loadRecentCommands()
{
    LOGI() << "=== loadRecentCommands() called ===";
    QSettings settings;
    settings.beginGroup("CommandPalette");
    
    QStringList recentCodes = settings.value("RecentCommands").toStringList();
    LOGI() << "Loaded recent commands from QSettings: " << recentCodes.size() << " items";
    
    settings.endGroup();
    
    m_recentCommands.clear();
    
    for (const QString& code : recentCodes) {
        LOGI() << "Recent command code: " << code;
        CommandItem item;
        item.code = code.toStdString();
        item.title = code;
        item.isEnabled = true;
        m_recentCommands.append(item);
    }
}

void CommandPaletteModel::saveRecentCommands()
{
    LOGI() << "=== saveRecentCommands() called ===";
    LOGI() << "Saving " << m_recentCommands.size() << " recent commands";
    
    QSettings settings;
    settings.beginGroup("CommandPalette");
    
    QStringList recentCodes;
    for (const CommandItem& item : m_recentCommands) {
        QString code = QString::fromStdString(item.code);
        LOGI() << "Saving: " << code << " - " << item.title;
        recentCodes.append(code);
    }
    
    settings.setValue("RecentCommands", recentCodes);
    settings.endGroup();
    settings.sync();
    LOGI() << "Recent commands saved to QSettings";
}