// Generates metadata-only Markdown; never reads the source SQL or user rows.
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';
const [dumpPath, schemaPath, clientPath, outputDir] = process.argv.slice(2);
if (!outputDir) throw new Error('Expected DUMP.json SCHEMA.json CLIENT.json OUTPUT_DIR');
const json = path => JSON.parse(readFileSync(path, 'utf8').replace(/^\uFEFF/, ''));
const dump = json(dumpPath), schema = json(schemaPath), client = json(clientPath);
const md = value => String(value ?? '').replaceAll('|', '\\|').replaceAll('\n', ' ');
const codes = values => values.length ? values.map(value => '`' + md(value) + '`').join('、') : '—';
const readme = readFileSync('docs/v2/scope/LEGACY_PAGE_AUDIT.md', 'utf8');
const historical = new Map(readme.split('\n').filter(line => /^\| \d+ \|/.test(line)).map(line => {
  const parts = line.split('|').map(p => p.trim());
  return [parts[2].replaceAll('`', ''), { task: parts[3], role: parts[4], previous: parts[6] }];
}));
const additions = {
  'pages/group_manage_members/group_manage_members': { task: '群申请审批、管理员与转让群主', role: '群主/管理员', previous: '新增；纳入群聊扩展评审' },
  'releaseSystem/pages/musicPicker/musicPicker': { task: '搜索/收藏/试听/选择配乐', role: '创作者', previous: '新增；纳入作品发布评审' },
  'releaseSystem/pages/musicDetail/musicDetail': { task: '查看音乐与同款作品、使用音乐创作', role: '会员/创作者', previous: '新增；纳入作品发布评审' },
};
const routeLines = client.routes.map((item, i) => {
  const detail = historical.get(item.route) ?? additions[item.route];
  if (!detail) throw new Error('Unclassified route: ' + item.route);
  const ids = [...new Set(item.files.flatMap(file => file.ids))];
  return `| ${i + 1} | \`${item.route}\` | ${md(detail.task)} | ${md(detail.role)} | ${md(detail.previous)} | ${codes(ids)} |`;
});
const byRoutine = new Map(dump.routines.map(item => [item.name, item]));
function dependencies(names, visited = new Set()) {
  const tables = [];
  for (const name of names) {
    if (visited.has(name)) continue;
    visited.add(name);
    const item = byRoutine.get(name);
    tables.push(...(item?.tableReferences ?? []), ...dependencies(item?.routineCalls ?? [], visited));
  }
  return tables;
}
const rootCategory = 'S232202502210097';
const categories = new Set([rootCategory]);
for (let oldSize = -1; oldSize !== categories.size;) {
  oldSize = categories.size;
  for (const item of dump.interfaceCategories) if (categories.has(item.parentId)) categories.add(item.id);
}
const categoryById = new Map(dump.interfaceCategories.map(item => [item.id, item]));
const selected = dump.interfaces.filter(item => categories.has(item.category));
if (client.routes.length !== 72 || client.interfaces.length !== 82 || selected.length !== 103) {
  throw new Error('Baseline changed: review counts and wording before regenerating the dated report');
}
const extraInterfaces = [
  { id: 'S231202508300801', routine: 'K_GroupManageList' },
  { id: 'S231202508300802', routine: 'K_GroupManageAction' },
  { id: 'S231202508300803', routine: 'K_GroupCandidateList' },
];
const interfaceLines = selected.map(item => {
  const ref = client.interfaces.find(ref => ref.id === item.id);
  const tables = [...new Set([...item.tables, ...dependencies(item.routines)])].sort();
  return `| \`${item.id}\` | ${md(categoryById.get(item.category)?.name)} | ${ref ? ref.files.map(md).join('<br>') : '无静态编号引用；不能据此删除'} | ${codes(item.routines)} | ${codes(tables.filter(n => /^k_/i.test(n)))} | ${codes(tables.filter(n => !/^k_/i.test(n)))} | ${item.deleted ? '快照标记 deleted' : '快照目录存在；未核验线上'} |`;
});
for (const item of extraInterfaces) interfaceLines.push(`| \`${item.id}\` | App（后续脚本） | ${client.interfaces.find(ref => ref.id === item.id)?.files.map(md).join('<br>') ?? '—'} | \`${item.routine}\` | 见群聊增量脚本；未混入旧快照依赖 | — | 仅确认脚本存在，未确认实迁 |`);
const groups = {
  '身份、会员与个人资料': ['user','user_info','user_examine_images','user_examine_type','user_setting','user_setup','level_config','level_score_detail','exp_detail','invitation_code'],
  '关系、代理归属与备注（需拆权）': ['user_follow','user_relation','remark_detail','division'],
  '聊天、通知与群管理': ['conversations','conversations_blacklist','conversations_group_temp','conversations_messages','conversations_messages_attachments','conversations_messages_collect','conversations_messages_reads','conversations_temp','system_messages','push_log'],
  '作品、评论与内容互动': ['user_works','user_works_files','user_comment','user_comment_image','user_like_praise_collect','subject','like_log','collect_log','content_log'],
  '门店、预约、组局与入场': ['table','thali','order','order_detail','order_member','order_temp','closed_date_config','ticket_records','sign_qrcode'],
  '商品、库存与仓储后台': ['goods','goods_access_log','goods_batch','goods_classification','goods_detail','goods_property','goods_warehouse_location','batch','warehouse','shop_thing','shop_thing_check_log','shop_thing_classify'],
  '支付、资产与财务（部分仅后台）': ['stand_order','stand_order_type','transaction','transaction_notify','refund_transaction','wallet','balance_details','goldcoin_detail','diamond_detail','bill_detail','recharge_config','recharge_details','commission_log','bank_card','withdrawal','coupon','coupon_log','virtual_goods','virtual_goods_log'],
  '会员物品、存酒与领取': ['items_goods','items_goods_log','stored_items','stored_items_log','stored_wine','drinks_access_log'],
  '运营、规则与活动配置': ['config','activity','activity_join','ad_info','advertisement','advertisement_log','tweets','tweets_log','rule_note','prop','prop_function_item','question_answer','question_options','questionnaire','questions'],
};
const owners = new Map();
for (const [group, names] of Object.entries(groups)) for (const suffix of names) {
  const name = 'k_' + suffix;
  if (owners.has(name)) throw new Error('Duplicate table classification: ' + name);
  owners.set(name, group);
}
const tables = dump.tables.filter(item => /^k_/i.test(item.name));
if (tables.some(item => !owners.has(item.name)) || tables.length !== owners.size) throw new Error('Table classification is not exhaustive');
const tableLines = tables.map((item, i) => {
  const sourceSchema = schema.tables.find(t => t.name === item.name);
  const comparable = t => JSON.stringify({ columns: t.columns, indexes: t.indexes, engine: t.engine, charset: t.charset });
  const same = sourceSchema && comparable(item) === comparable(sourceSchema);
  return `| ${i + 1} | \`${item.name}\` | ${owners.get(item.name)} | ${item.columns.length} | ${md(item.charset)} | ${dump.insertStatements[item.name] ?? 0} | ${same ? '结构元数据相同' : '有差异，需核对'} |`;
});
const fieldLines = tables.flatMap(item => [`### ${item.name}`, '',
  item.columns.map(c => `\`${c.name}: ${c.type}${c.unsigned ? ' unsigned' : ''}${c.nullable ? ' nullable' : ''}\``).join('、'), '']);
mkdirSync(outputDir, { recursive: true });
writeFileSync(join(outputDir, 'LEGACY_ROUTES.md'), [
  '# 当前旧版 72 路由对照清单', '',
  '- 状态：已确认事实（注册路径与静态引用）；迁移去向仍待本轮评审。',
  '- 基线：小程序 `master / 9299208`；246 个运行时代码/样式/模板文件纳入结构扫描。',
  '- “旧规划去向”继承 69 路由历史清单，不表示本次再次批准删除/延期；新增 3 页单独登记。',
  '- 超大首页内部 Tab、聊天弹层、创作多步骤及动态菜单不是独立物理路由，仍须按产品主表验收。',
  '- 未出现静态编号不代表无接口：还可能走 Java 专用 HTTP、公共包装或动态目录。', '',
  '| # | 当前旧路由 | 用户任务 | 角色 | 旧规划去向 / 新增提示 | 页内静态接口编号 |',
  '|---:|---|---|---|---|---|', ...routeLines, '',
].join('\n'));
writeFileSync(join(outputDir, 'LEGACY_INTERFACES.md'), [
  '# KING CLUB 接口分类与依赖清单', '',
  '- 已确认事实：`s_interface.interfaceType -> s_interface_type.typeId`；通过 `parentId` 追溯“酒吧”分类树。',
  '- 根：`S232202502210097 酒吧`；子类：`S232202502210099 App`（92）、`S232202502210100 服务器端使用`（11）。快照共 103，另列 3 个群管理增量接口。',
  '- 当前客户端 82 个静态编号中 79 个命中快照；分类目录还补出 24 个没有静态编号引用的接口。',
  '- “服务器端使用”是分类而非可靠权限保证：头像修改编号 `S231202504160682` 仍出现在客户端。',
  '- 依赖由接口 SQL 的已知对象名及 Routine 调用递归提取，只是词法候选；动态 SQL、运行配置、Java 直接调用、触发器副作用需单独确认。',
  '- 非 k_ 对象仅作为外部依赖登记，不构成整表迁移授权。新端不得原样搬运 interfaceSql。',
  '- 本文件不含原始接口 SQL、行数据、密钥、生产地址或用户资料。', '',
  '| 旧接口 | 分类 | 客户端静态引用 | 入口 Routine | k_ 表候选依赖 | 公共依赖（非迁移表） | 证据状态 |',
  '|---|---|---|---|---|---|---|', ...interfaceLines, '',
].join('\n'));
writeFileSync(join(outputDir, 'LEGACY_TABLES.md'), [
  '# KING CLUB 表级归属与字段清单', '',
  '- 已确认事实：混合快照 515 张表中，94 张 `k_` 表是本轮 KING CLUB 业务数据盘点范围，共 1484 个字段。',
  '- 后续群聊脚本另有 `k_conversation_member`、`k_group_join_request` 两张候选增量表；不声称线上当前恰好 96 张。',
  '- 归属列是当前建议，跨域关系/财务/运营表需要逐表映射评审；首发 UI 暂缓不等于可以删除其数据。',
  '- INSERT 数是文件里的 INSERT 语句数，不是已验证数据库行数；0 不证明生产为空。没有读取或导出业务字段值。',
  '- 比较只覆盖字段名/基本类型/空值、索引标识、引擎、默认字符集，不证明 Routine、触发器或完整 DDL 相同。',
  '- 导出快照无 k_ 外键，87 张默认 utf8、7 张默认 utf8mb4；重建时验证逻辑引用、Unicode 和金额精度。', '',
  '| # | 旧表 | 建议业务归属 | 字段数 | 默认字符集 | 快照 INSERT 语句数 | 与仅结构文件比较 |',
  '|---:|---|---|---:|---|---:|---|', ...tableLines, '',
  '## 字段级原始结构索引（不是已批准的新库字段映射）', '', ...fieldLines,
].join('\n'));
console.log(JSON.stringify({ routeRows: routeLines.length, interfaceRows: interfaceLines.length,
  tableRows: tableLines.length, columnCount: tables.reduce((sum, t) => sum + t.columns.length, 0) }));
