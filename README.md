# SecBuzzer ESM - DetectionEdge 

此專案僅說明相關DetectionEdge。
## 版本安裝及說明文件引導

1. 安裝前，可先參考Ｗiki中的[DetectionEdge 硬體規格建議](https://github.com/secbuzzer/DetectionEdge/wiki/DetectionEdge-硬體規格建議)進行環境評估。
2. 安裝可依照Wiki中的[DetectionEdge 操作說明手冊](https://github.com/secbuzzer/DetectionEdge/wiki/DetectionEdge-操作說明手冊)中的安裝操作說明。
3. 若曾有安裝過需完整移除可參考[DetectionEdge 操作說明手冊](https://github.com/secbuzzer/DetectionEdge/wiki/DetectionEdge-操作說明手冊)中的移除操作說明。
4. 若重新安裝可參照Wiki中的[DetectionEdge 操作說明手冊](https://github.com/secbuzzer/DetectionEdge/wiki/DetectionEdge-操作說明手冊)中的重新安裝操作說明
5. 版本更新，可參考重新安裝操作說明，將新版本直接取代即可，自動版本更新開發中。


## 開發工具使用一覽

|項次|工具名稱           |  版本       | 用途說明 |
|---|------------------|------------|---------|
| 1 |Ubuntu            | 18.04      | 作業系統，Ubuntu Server英文版 |
| 2 |Docker            | 18.09.3    | 軟體平台，可使用容器快速地建立、測試和部署應用程式 |
| 3 |Docker compose    | 1.29.2     | 可使用容器快速地建立、測試和部署應用程式 |
| 4 |Fluent-bit        | 1.8.12     | 惡意事件特徵萃取及派送 |
| 5 |Elasticsearch     | 7.6.0      | OSS版本，大數據資料庫，簡稱ES |
| 6 |Suricata          | 6.0.4      | IDS工具，負責偵測異常行為 |
| 7 |Python            | 3.8.5      | 直譯式程式語言 |
| 8 |JAVA              | 1.8.0      | 直譯式程式語言 |

## Secbuzzer ESM edge 版本紀錄

### V2.4.0
重構Edge元件，更換運行效率更高方式
> 1. 重構拋轉功能元件，提供運算效率及降低系統負擔。
> 2. 重構資料萃取元件，減少資料流失率。
> 3. 排程功能重構，去中心化，拆散於對應功能之各元件中。
> 4. 優化安裝腳本，新增清除資料及環境設定。
> 5. 目錄架構變更，採性質面向進行分類。
> 6. 偵測元件新增檢查機制，若無正常運行則會重啟服務。
> 7. 整合DDoS惡意攻擊情資偵測模組。
> 8. 多網卡鏡像流量自動偵測及加總統計。

### V2.3.5 
> 1. 去除未必要及使用功能，減輕運行負擔
> 2. 拋轉功能元件，新增DDoS惡意攻擊事件單位。
