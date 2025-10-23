#ifndef MU_APPSHELL_COMMANDPALETTEMODEL_H
#define MU_APPSHELL_COMMANDPALETTEMODEL_H

#include <QAbstractListModel>

#include "modularity/ioc.h"
#include "actions/iactionsdispatcher.h"
#include "ui/iuiactionsregister.h"
#include "async/asyncable.h"
#include "shortcuts/ishortcutsregister.h" 

namespace mu::appshell {
class CommandPaletteModel : public QAbstractListModel, public muse::async::Asyncable
{
    Q_OBJECT

    muse::Inject<muse::actions::IActionsDispatcher> dispatcher;
    muse::Inject<muse::ui::IUiActionsRegister> actionsRegister;
    muse::Inject<muse::shortcuts::IShortcutsRegister> shortcutsRegister;

    Q_PROPERTY(QString searchText READ searchText WRITE setSearchText NOTIFY searchTextChanged)
    Q_PROPERTY(int selectedIndex READ selectedIndex WRITE setSelectedIndex NOTIFY selectedIndexChanged)

public:
    explicit CommandPaletteModel(QObject* parent = nullptr);

    enum Roles {
        CodeRole = Qt::UserRole + 1,
        TitleRole,
        DescriptionRole,
        CategoryRole,
        ShortcutRole,
        IsEnabledRole
    };

    int rowCount(const QModelIndex& parent = QModelIndex()) const override;
    QVariant data(const QModelIndex& index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    QString searchText() const;
    int selectedIndex() const;

    Q_INVOKABLE void load();
    Q_INVOKABLE void executeCommand(int index);
    Q_INVOKABLE void executeSelectedCommand();

public slots:
    void setSearchText(const QString& text);
    void setSelectedIndex(int index);

signals:
    void searchTextChanged();
    void selectedIndexChanged();
    void closeRequested();

private:
    void filterCommands();
    QString getShortcutForAction(const muse::actions::ActionCode& actionCode) const;  // この行を追加
    QString formatShortcut(const QString& sequence) const;  // この行を追加


    struct CommandItem {
        muse::actions::ActionCode code;
        QString title;
        QString description;
        QString category;
        QString shortcut;
        bool isEnabled = true;
    };

    QList<CommandItem> m_allCommands;
    QList<CommandItem> m_filteredCommands;
    QString m_searchText;
    int m_selectedIndex = 0;
};
}

#endif // MU_APPSHELL_COMMANDPALETTEMODEL_H