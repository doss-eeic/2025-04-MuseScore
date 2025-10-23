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

#include "log.h"

using namespace mu::appshell;
using namespace muse::actions;
using namespace muse::ui;
using namespace muse::shortcuts;

CommandPaletteModel::CommandPaletteModel(QObject* parent)
    : QAbstractListModel(parent)
{
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