# SecBuzzer ESM
開發中


## 版本安裝及說明文件引導

1. 首次安裝可依照Wiki中的[連線安裝手冊](https://github.com/secbuzzer/DetectionEdge/wiki/SecBuzzer-ESM%E9%80%A3%E7%B7%9A%E5%AE%89%E8%A3%9D%E6%89%8B%E5%86%8A)步驟進行，若部屬環境並無對外網路連線，可另外參照[離線安裝手冊](https://github.com/secbuzzer/DetectionEdge/wiki/SecBuzzer-ESM%E9%9B%A2%E7%B7%9A%E5%AE%89%E8%A3%9D%E6%89%8B%E5%86%8A)
2. 若曾經有安裝過想要移除或重新安裝可參照Wiki中的[重新安裝手冊](https://github.com/secbuzzer/DetectionEdge/wiki/SecBuzzer-ESM%E9%87%8D%E6%96%B0%E5%AE%89%E8%A3%9D%E6%89%8B%E5%86%8A)
3. 版本更新教學(開發中)
4. DTM擴充功能安裝教學(開發中)
5. 輕量化版本部屬教學(開發中)
6. 本產品有提供地端資料視覺化的開源插件，其詳細設定教學請參考[Grafana設定教學](https://github.com/secbuzzer/DetectionEdge/wiki/Granfana%E6%8F%92%E4%BB%B6%E8%A8%AD%E5%AE%9A%E6%95%99%E5%AD%B8)

## 開發工具使用一覽

|項次|工具名稱          |  版本      | 用途說明                                        |
|---|------------------|------------|------------------------------------------------|
| 1 |Ubuntu            | 18.04      | 作業系統，Ubuntu Server英文版                   |
| 2 |Docker            | 18.09.3    | 軟體平台，可使用容器快速地建立、測試和部署應用程式 |
| 3 |Fluentd           | 1.9-1      | 日誌收容與解析、派送                             |
| 4 |Elasticsearch     | 7.6.0      | OSS版本，大數據資料庫，簡稱ES                    |
| 5 |Elasticsearch Head| 2006       | 視覺化ES查詢、管理套件                           |
| 6 |Grafana           | 6.7.2      | 視覺化呈現                                      |
| 7 |Suricata          | 6.0.0      | IDS工具，負責偵測異常行為                        |
| 8 |RabbitMQ          | 3.8.3      | 訊息佇列工具                                    |
| 9 |Tomcat            | 8.5.55     | Servlet容器，主要作為Web伺服器                   |
|10 |OpenJDK           | 11.0.8-jre | 跨平台程式語言, Java開發環境的開源版本            |
|11 |Python            | 3.8.5      | 直譯式程式語言                                  |
