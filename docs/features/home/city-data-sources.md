# 城市索引来源

- `assets/legacy/profile/city_regions.json`：腾讯位置服务行政区划列表，2026-10-02取得3622条，仅保留行政代码、名称、简称、拼音。使用现有位置服务账户读取官方 `/ws/district/v1/list`，文件不包含Key或用户定位。文档：https://lbs.qq.com/service/webService/webServiceGuide/webServiceDistrict 。行政区划会变化，更新时保留稳定代码，变更另行核验。
- `assets/legacy/profile/international_cities.json`：GeoNames `cities15000.zip`，2026-10-02取得并过滤CN/HK/MO/TW后31816条，保留稳定GeoNames ID、名称、ASCII检索名、国家代码。中国及港澳台由行政区划源覆盖。筛选与字段精简为本项目修改。

GeoNames 来源：https://download.geonames.org/export/dump/cities15000.zip ，说明：https://download.geonames.org/export/dump/ 。由 GeoNames 提供，遵循 Creative Commons Attribution 4.0 International (CC BY 4.0)：https://creativecommons.org/licenses/by/4.0/ 。城市选择国际列表保留来源标注；原始数据及本项目精简版本均按此许可提供。无准确性保证，城市名称不代表业务已开通。

城市历史只记录本设备实际选过的代码，最多8项，安全存储；不写入假历史，不持续定位，不采集会员个人信息。
