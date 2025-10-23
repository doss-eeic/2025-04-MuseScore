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
#ifndef MUSE_UI_COMMANDPALETTEMODEL_H
#define MUSE_UI_COMMANDPALETTEMODEL_H

#include <QAbstractListModel>

#include "modularity/ioc.h"
#include "../../iuiactionsregister.h"
#include "../../uiaction.h"
#include "../../../shortcuts/ishortcutsregister.h"
#include "async/asyncable.h"

namespace muse::ui {

class CommandPaletteModel : public QAbstractListModel, public muse::async::Asyncable
{
    Q_OBJECT

    muse::Inject<muse::ui::IUiActionsRegister> actionsRegister;
    muse::Inject<muse::shortcuts::IShortcutsRegister> shortcutsRegister;

    Q_PROPERTY(QString searchText READ searchText WRITE setSearchText NOTIFY searchTextChanged)
    Q_PROPERTY(int selectedIndex READ selectedIndex WRITE setSelectedIndex NOTIFY selectedIndexChanged)

public:
    explicit CommandPaletteModel(QObject* parent = nullptr);

    enum Roles {
        ActionCodeRole = Qt::UserRole + 1,
        TitleRole,
        DescriptionRole,
        ShortcutRole,
        CategoryRole,
        IsEnabledRole
    };

    // QAbstractListModel interface
    int rowCount(const QModelIndex& parent = QModelIndex()) const override;
    QVariant data(const QModelIndex& index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    // Properties
    QString searchText() const { return m_searchText; }
    void setSearchText(const QString& text);

    int selectedIndex() const { return m_selectedIndex; }
    void setSelectedIndex(int index);

    // Q_INVOKABLE methods
    Q_INVOKABLE void load();
    Q_INVOKABLE void executeSelectedCommand();
    Q_INVOKABLE void executeCommand(int index);

signals:
    void searchTextChanged();
    void selectedIndexChanged();
    void closeRequested();

private:
    struct CommandItem {
        std::string actionCode;
        QString title;
        QString description;
        QString shortcut;
        QString category;
        bool isEnabled = true;
    };

    void updateFilteredCommands();
    QString formatShortcut(const muse::shortcuts::Shortcut& shortcut) const;
    QString extractCategory(const std::string& actionCode) const;

    std::vector<CommandItem> m_allCommands;
    std::vector<CommandItem> m_filteredCommands;
    QString m_searchText;
    int m_selectedIndex = 0;
};

} // namespace muse::ui

#endif // MUSE_UI_COMMANDPALETTEMODEL_H