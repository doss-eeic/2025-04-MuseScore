import QtQuick 2.15
import QtQuick.LocalStorage 2.15 // LocalStorageを使うためにインポート

// QMLだけでお気に入りセットを管理するオブジェクト
QtObject {
    id: repository

    // プライベート: データベース接続を取得するヘルパー関数
    function _getDb() {
        // データベース名、バージョン、説明、推定サイズ
        return LocalStorage.openDatabaseSync("MuseScoreUserSets", "1.0", "User Instrument Sets", 100000);
    }

    // データベースのテーブルを初期化する関数
    function initializeDatabase() {
        var db = _getDb();
        db.transaction(function(tx) {
            // テーブルが存在しなければ作成
            // setName: セット名 (例: "お気に入り1"), TEXT型でUNIQUE制約 (同じ名前は登録不可)
            // instrumentIds: 楽器IDの配列をJSON文字列化したもの, TEXT型
            tx.executeSql('CREATE TABLE IF NOT EXISTS UserInstrumentSets(setName TEXT UNIQUE NOT NULL PRIMARY KEY, instrumentIds TEXT NOT NULL)');
            console.log("Database table UserInstrumentSets initialized.");
        });
    }

    // このコンポーネントが読み込まれたときに初期化を実行
    Component.onCompleted: {
        initializeDatabase();
    }

    // === QMLから呼び出す公開関数 ===

    // 保存されている全てのセットをロードする関数
    // 戻り値: [{setName: "...", instrumentIds: ["id1", "id2", ...]}, ...] の形式のJavaScript配列
    function loadSets() {
        var db = _getDb();
        var sets = []; // 結果を格納する配列
        try {
            db.readTransaction(function(tx) {
                var rs = tx.executeSql('SELECT setName, instrumentIds FROM UserInstrumentSets ORDER BY setName'); // 名前順で取得
                console.log("Found " + rs.rows.length + " saved sets.");
                for (var i = 0; i < rs.rows.length; i++) {
                    var row = rs.rows.item(i);
                    var ids = [];
                    try {
                        // JSON文字列をパースして配列に戻す
                        console.log("Loading raw IDs string for", row.setName + ":", row.instrumentIds);
                    　　ids = JSON.parse(row.instrumentIds || "[]");
                    　　console.log("Parsed IDs for", row.setName + ":", JSON.stringify(ids)); // ★パース後の配列が正しいか？★
                        if (!Array.isArray(ids)) ids = []; // 配列でなければ空にする
                    } catch (e) {
                        console.error("Failed to parse instrumentIds JSON for set:", row.setName, e);
                        ids = []; // パース失敗時は空配列
                    }
                    sets.push({
                        setName: row.setName,
                        instrumentIds: ids
                    });
                }
            });
        } catch (error) {
            console.error("Error loading sets from LocalStorage:", error);
            // エラーが発生した場合も空の配列を返す
            return [];
        }
        // console.log("Loaded sets:", JSON.stringify(sets)); // デバッグ用
        return sets; // JavaScript配列を返す
    }

    // 新しいセットを保存する関数 (同名があれば上書き)
    // setName: 保存するセット名 (文字列)
    // instrumentIds: 楽器IDの配列 (例: ["violin", "viola"])
    function saveSet(setName, instrumentIds) {
        // 引数の型チェック (より安全に)
        if (typeof setName !== 'string' || !setName || !Array.isArray(instrumentIds) || instrumentIds.length === 0) {
            console.error("Save failed: Invalid arguments provided.", "Name:", setName, "IDs:", instrumentIds);
            return false; // 保存失敗を示すために false を返す (任意)
        }

        function deleteSet(setName) {
         if (typeof setName !== 'string' || !setName) {
             console.warn("Delete failed: Invalid setName provided:", setName);
             return false; // 失敗
         }
         var db = _getDb(); // _getDb() は openDatabaseSync を呼び出すヘルパー
         var success = false;
         try {
             db.transaction(function(tx) {
                 // 指定された名前の行を削除
                 var result = tx.executeSql('DELETE FROM UserInstrumentSets WHERE setName = ?', [setName]);
                 if (result.rowsAffected > 0) {
                     success = true; // 1行以上削除できたら成功
                 }
             });
         } catch(error) {
              console.error("Error deleting set '" + setName + "' from LocalStorage:", error);
              return false; // 失敗
         }
         if (success) {
             console.log("Successfully deleted set:", setName);
         } else {
             console.warn("Set '" + setName + "' not found or delete failed.");
         }
         return success; // 成功/失敗を返す
    }
    // ▲▲▲ 追加 ▲▲▲

        var db = _getDb();
        var success = false;
        try {
            // IDリストをJSON文字列に変換
            var idsJson = JSON.stringify(instrumentIds);

            db.transaction(function(tx) {
                // 同じ名前があれば上書き(REPLACE), なければ挿入(INSERT)
                var result = tx.executeSql('INSERT OR REPLACE INTO UserInstrumentSets(setName, instrumentIds) VALUES(?, ?)', [setName, idsJson]);
                // console.log("Save result:", result.rowsAffected); // デバッグ用
                if (result.rowsAffected > 0) {
                    success = true;
                }
            });
        } catch (error) {
            console.error("Error saving set '" + setName + "' to LocalStorage:", error);
            return false; // 保存失敗
        }
        if (success) {
            console.log("Successfully saved set:", setName);
        } else {
             console.warn("Set '" + setName + "' might not have been saved correctly.");
        }
        return success; // 保存成功/失敗を返す (任意)
    }

    // (任意) セットを削除する関数
    function deleteSet(setName) {
         if (typeof setName !== 'string' || !setName) {
             console.warn("Delete failed: Invalid setName provided.");
             return false;
         }
         var db = _getDb();
         var success = false;
         try {
             db.transaction(function(tx) {
                 var result = tx.executeSql('DELETE FROM UserInstrumentSets WHERE setName = ?', [setName]);
                 if (result.rowsAffected > 0) {
                     success = true;
                 }
             });
         } catch(error) {
              console.error("Error deleting set '" + setName + "' from LocalStorage:", error);
              return false;
         }
         if (success) {
             console.log("Successfully deleted set:", setName);
         } else {
             console.warn("Set '" + setName + "' not found or delete failed.");
         }
         return success;
    }
}