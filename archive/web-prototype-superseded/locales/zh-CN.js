/*
 * Project Seven Seas — Simplified Chinese locale table.
 *
 * Mirrors locales/en.js key for key. Placeholders ({name}) must match the
 * English table exactly; tests/locale.test.js enforces parity.
 */
(function (root) {
  'use strict';

  const S = {};
  const put = (prefix, map, suffix) => { for (const k of Object.keys(map)) S[prefix + k + (suffix || '')] = map[k]; };
  const pair = (prefix, map, a, b) => { for (const k of Object.keys(map)) { S[prefix + k + a] = map[k][0]; S[prefix + k + b] = map[k][1]; } };

  // ------------------------------------------------------------- app shell
  Object.assign(S, {
    'app.title': '七海计划',
    'app.short': '七海',
    'app.tagline': '打造一艘船，培养一支船员队伍，成为七海最强的船长。',
    'lang.choose': '请选择语言',
    'lang.note': '之后可以在「系统」中更改语言。切换语言会重新启动游戏；两种语言共用同一份存档。',

    'nav.label': '主导航',
    'nav.home': '总览', 'nav.ship': '船只', 'nav.map': '海图', 'nav.crew': '船员',
    'nav.port': '港口', 'nav.pets': '宠物研究室', 'nav.codex': '图鉴', 'nav.system': '系统',

    'status.gold': '金币', 'status.food': '食物', 'status.supplies': '补给', 'status.materials': '材料',
    'status.stamina': '体力', 'status.ledger': '未入账', 'status.time': '时间', 'status.location': '位置',
    'status.ledger_hint': '本次航行获得的金币和材料。停靠港口时入账；战败会损失其中的 25%。',
    'status.clock': '{hour}:00', 'status.saved': '已保存', 'status.save_failed': '保存失败',
    'status.stun': '眩晕', 'status.slow': '减速', 'status.mark': '标记', 'status.taunt': '嘲讽',
    'status.evade': '闪避中', 'status.shield': '护盾', 'status.buffAtk': '攻击提升', 'status.buffDef': '防御提升',
    'status.regen': '再生', 'status.dot': '灼烧', 'status.sunder': '破甲',

    'ui.confirm': '确认', 'ui.cancel': '取消', 'ui.yes': '是', 'ui.no': '否', 'ui.delete': '删除',
    'ui.day': '第 {n} 天', 'ui.lv': 'Lv {n}', 'ui.tier': '{n} 阶', 'ui.free': '免费', 'ui.unknown': '未知',
    'ui.former_crew': '前船员',

    'title.continue': '继续游戏', 'title.new_game': '新游戏', 'title.load': '读取存档',
    'title.language': '语言：{lang}', 'title.no_slots': '还没有手动存档。',
    'title.footer': '离线游戏 · 进度保存在本浏览器 · 所有画面均由代码生成',
    'title.unknown_captain': '无名船长', 'title.strongest': '七海最强船长',

    'where.port': '停靠于 {location}', 'where.location': '停泊于 {location}', 'where.site': '正在探索 {location}',
    'where.at_sea': '航行中，前往 {location}', 'where.battle': '在 {location} 附近战斗',

    'save.reason_auto': '自动存档', 'save.reason_port': '停靠港口', 'save.reason_battle': '战斗之后',
    'save.reason_trial': '船长试炼', 'save.reason_hull': '船体升级', 'save.reason_loaded': '已读取',
    'save.reason_manual': '手动存档', 'save.reason_new_game': '新游戏',

    'confirm.return_title': '紧急返航？',
    'confirm.return_body': '直接返回 {location}。不消耗食物、金币或体力，耗时 12 小时。抵达后，未入账的 {gold} 金币和 {materials} 材料将会入账。',
    'confirm.unreachable_title': '部分设施无法到达',
    'warn.confirm_unreachable': '有 {n} 个可选设施无法到达，本次航行中不会生效。仍要出航吗？',
    'warn.deck_no_stair': '没有楼梯通往第 {deck} 层甲板。',
    'warn.facility_unreachable': '未与第 {deck} 层甲板的通道相连。',
    'warn.facility_stowed': '已收进货舱。'
  });

  // --------------------------------------------------------------- overview
  Object.assign(S, {
    'home.objective': '当前目标', 'home.log': '航海日志', 'home.quests': '任务', 'home.no_quests': '尚未接受支线任务。',
    'home.ship': '船只', 'home.hull': '船体', 'home.crew_cap': '船员床位', 'home.crew_cap_value': '{n} / {max}',
    'home.formation': '战斗编队', 'home.stamina': '船只体力', 'home.stamina_value': '{n} / {max}',
    'home.stamina_rule': '可选挑战会消耗体力。航行、被迫战斗、撤退、已清理的房间和返回港口都不消耗体力。只有口粮和补给能恢复体力。',
    'home.serve_ration': '分发口粮（+{n}）', 'home.use_supply': '使用补给（+{n}）',
    'home.ledger': '{gold} 金币 · {materials} 材料', 'home.ledger_short': '未入账货物',
    'home.damage': '船体损伤', 'home.facility_damaged': '{facility} 已损坏。',
    'home.missing_required': '缺少必需设施或无法到达：{facility}。',
    'home.over_capacity': '船员超出床位。出航前请建造或升级船员舱。',
    'home.ship_ready': '船只已准备好出航。', 'home.aid_available': '本港口可提供免费紧急援助。',
    'home.open_ship': '打开船只', 'home.open_crew': '打开船员', 'home.open_port': '打开港口', 'home.open_chart': '打开海图',
    'home.explore_site': '继续探索', 'home.resume_battle': '继续战斗',
    'home.emergency_return': '紧急返航', 'home.emergency_hint': '随时可用：免费返回最近的安全港口。',
    'home.last_safe': '最近的安全港口：{location}',

    'obj.step': '第 {n} 步，共 {total} 步', 'obj.target': '目标：{location}', 'obj.target_hidden': '目标：尚未标记的地点——继续探索以发现它',
    'obj.have': '船上已有 {have} / {need}', 'obj.show_on_chart': '在海图上显示',
    'obj.trial_locked': '{location} 的船长试炼将在主线完成后开放。对手：{rival}。',
    'obj.trial_open': '{location} 的船长试炼已开放。对手：{rival}。',
    'obj.trial_won': '已在船长试炼中战胜 {rival}。',
    'obj.postgame': '你已获得称号。后期海域的传说挑战已开放。',
    'obj.legends': '已击败的传说：{n} / {total}'
  });

  // ------------------------------------------------------------------- ship
  Object.assign(S, {
    'ship.decks': '{n} 层甲板', 'ship.edit_ok': '已停靠：可以编辑布局', 'ship.edit_port_only': '只能在港口编辑布局',
    'ship.layout': '布局检查', 'ship.capacity': '船员床位', 'ship.food_cap': '食物储量', 'ship.supply_cap': '补给储量',
    'ship.equip_cap': '装备储量', 'ship.stamina_max': '体力上限', 'ship.departure': '出航',
    'ship.depart_ok': '可以出航', 'ship.depart_blocked': '无法出航',
    'ship.deck_n': '第 {n} 层甲板', 'ship.cell': '格子 {x},{y}',
    'ship.legend_walk': '通道', 'ship.legend_entry': '入口', 'ship.legend_door': '门', 'ship.legend_stair': '楼梯', 'ship.legend_disabled': '无法到达',
    'ship.fixed_hull': '船体框架', 'ship.fixed_mast': '桅杆', 'ship.fixed_bulkhead': '舱壁',
    'ship.mode_select': '选择', 'ship.mode_stair': '放置楼梯', 'ship.rotate': '旋转',
    'ship.build_hint': '点击空格子放置 {facility}。按 R 旋转。',
    'ship.move_hint': '点击空格子移动 {facility}。',
    'ship.stair_hint': '点击空格子，在第 {a} 层和第 {b} 层甲板之间放置楼梯。',
    'ship.select_hint': '在甲板图上选择一个设施、门或楼梯。',
    'ship.selection': '选中项', 'ship.category': '类别', 'ship.level': '等级', 'ship.size': '尺寸', 'ship.status': '状态',
    'ship.status_active': '运作中', 'ship.status_damaged': '已损坏（效果减半）', 'ship.status_disabled': '无法到达（无效果）', 'ship.status_stowed': '已收起',
    'ship.disabled_effect': '重新连通之前，它不会产生任何效果。',
    'ship.damaged_effect': '已损坏：修复前效果减半。',
    'ship.jobs': '工作人员 {n} / {max}', 'ship.assign_worker': '指派工作人员……', 'ship.unassign': '取消指派',
    'ship.efficiency': '效率 {pct}', 'ship.staff_bonus': '人员加成：+{pct}', 'ship.pet_helpers': '宠物帮手：{names}',
    'ship.upgrade': '升级', 'ship.max_level': '已满级', 'ship.move': '移动', 'ship.stow': '收起', 'ship.place': '放置',
    'ship.stow_hint': '收进货舱。收起的设施保留等级，但不产生效果。',
    'ship.stowed': '已收起的设施', 'ship.demolish': '拆除', 'ship.demolish_confirm': '拆除 {facility}？',
    'ship.refund': '你将取回 {gold} 金币和 {materials} 材料。', 'ship.required': '必需',
    'ship.build_palette': '建造设施', 'ship.owned': '已建 {n} / {max}', 'ship.build': '建造',
    'ship.bulkhead': '舱壁', 'ship.bulkhead_info': '第 {deck} 层甲板第 {y} 行的舱壁。加装一扇门才能通过。',
    'ship.door_info': '第 {deck} 层甲板第 {y} 行舱壁上的门。', 'ship.add_door': '加装门', 'ship.remove_door': '拆除门',
    'ship.stair': '楼梯', 'ship.stair_info': '位于 {x},{y}，连接第 {a} 层和第 {b} 层甲板的楼梯。', 'ship.remove_stair': '拆除楼梯',
    'ship.stair_up': '上行楼梯', 'ship.stair_down': '下行楼梯',
    'ship.presets': '布局预设', 'ship.presets_hint': '保存当前布局，之后可以恢复。应用预设只会移动你已拥有的设施。',
    'ship.preset_n': '预设 {n}', 'ship.preset_info': '{n} 个设施', 'ship.preset_empty': '空', 'ship.preset_save': '保存到此处', 'ship.preset_apply': '应用',
    'ship.hulls': '船体', 'ship.current_hull': '当前', 'ship.hull_owned': '已淘汰', 'ship.upgrade_hull': '升级船体',
    'ship.hull_confirm': '升级为{hull}？', 'ship.hull_confirm_body': '设施会被移入货舱，可在更大的甲板上重新放置。船员、货物和进度都会保留。',
    'ship.tier': '{n} 阶', 'ship.services': '维修与生产', 'ship.repair': '维修', 'ship.damaged_facilities': '损坏的设施',
    'ship.damage_penalty': '严重损伤：修复前出航会额外消耗食物。',
    'ship.produce_food': '烹饪食物（+{n}）', 'ship.produce_supplies': '制作补给',
    'ship.production_hint': '厨房可以把金币变成食物，工坊可以把材料变成补给，即使在海上也能进行。',
    'ship.cannot_afford': '资源不足。'
  });

  // ------------------------------------------------------------------- crew
  Object.assign(S, {
    'crew.title': '船员', 'crew.roster': '名册', 'crew.formation': '编队', 'crew.reserve': '候补', 'crew.none': '请选择一名船员。',
    'crew.formation_hint': '六个战斗位置：前排两个、中排两个、后排两个。站位决定谁先受到攻击。',
    'crew.empty_slot': '— 空位 —', 'crew.slot_n': '位置 {n}',
    'crew.tactics': '默认战术', 'crew.tactics_hint': '遭遇战开始时使用。战斗中可随时在暂停菜单里调整。',
    'crew.origin': '出身', 'crew.traits': '性格', 'crew.aptitudes': '天赋', 'crew.affinity': '宠物亲和',
    'crew.event': '个人故事', 'crew.event_done': '已完成', 'crew.event_deliver': '交付纪念品',
    'crew.injured': '受伤', 'crew.injury_note': '受伤：治疗前属性 −{pct}。', 'crew.treat': '治疗',
    'crew.xp': '经验 {n} / {max}', 'crew.power': '战力 {n}', 'crew.branch_of': '{base} 的分支', 'crew.rename': '改名',
    'crew.dismiss': '解雇', 'crew.dismiss_confirm': '解雇 {name}？', 'crew.dismiss_body': '对方将永久离开船队，装备会退回货舱。',
    'crew.stats': '属性', 'crew.equipment': '装备', 'crew.weapons_allowed': '可用武器：{list}',
    'crew.choose_item': '选择物品……', 'crew.no_items_owned': '没有适合此栏位的物品', 'crew.no_item': '未装备',
    'crew.incompatible': '职业无法使用', 'crew.unequip': '卸下',
    'crew.skills': '主动技能', 'crew.passives': '被动技能', 'crew.class_passive': '职业被动',
    'crew.legacy': '传承被动', 'crew.legacy_n': '传承 {n}', 'crew.legacy_none': '— 无 —', 'crew.legacy_locked': '精通一个职业后解锁',
    'crew.legacy_hint': '从这名船员已精通的职业中选择最多两个被动（精通度 {n}）。',
    'crew.classes': '职业', 'crew.respec_rule': '转职会保留等级、精通度和资格。只有当前职业提供主动技能。',
    'crew.current_class': '当前', 'crew.change_class': '转职', 'crew.mastered': '已精通', 'crew.mastery': '精通度 {n} / {max}',
    'crew.need_mastery': '需要 {cls} 精通度 {n}', 'crew.respec_confirm': '让 {name} 转职为 {cls}？',
    'crew.respec_body': '新职业无法使用的装备会被移入货舱。',
    'crew.job': '船上工作', 'crew.job_current': '{facility} · 效率 {pct}', 'crew.job_none': '未分配工作。',
    'crew.jobs_preferred': '擅长的工作：{list}', 'crew.companion': '伙伴宠物：{pet}', 'crew.no_companion': '没有伙伴宠物。'
  });

  // --------------------------------------------------------------- sea chart
  Object.assign(S, {
    'map.title': '海图', 'map.locations': '地点', 'map.here': '你在这里', 'map.hidden_count': '还有 {n} 个未标记的地点',
    'map.uncharted': '{n} 个未标记', 'map.level': 'Lv {n}', 'map.pet_family': '宠物：{family}', 'map.specialty': '特产：{item}',
    'map.specialty_label': '特产', 'map.hazard': '环境危害：{hazard}', 'map.region_locked_n': '第 {n} 片海域——未解锁',
    'map.region_locked_hint': '赢得上一片海域的船长试炼即可开放此海域。',
    'map.route': '航线', 'map.route_to': '前往 {location} 的航线', 'map.select_hint': '在海图上选择一个已发现的地点来规划航行。',
    'map.you_are_here': '你就在这里。', 'map.voyage': '当前航行', 'map.origin': '出发地',
    'map.rooms_cleared': '已清理房间：{n} / {total}', 'map.objective': '目标', 'map.secret': '秘境',
    'map.port_services': '服务：{list}', 'map.emergency_hint': '紧急返航可免费带你回到最近的安全港口，即使没有食物或金币。',

    'route.distance': '航行时间', 'route.hours': '{n} 小时', 'route.food': '食物', 'route.food_value': '{n}（之后剩余：{after}）',
    'route.return': '最近的返程', 'route.return_value': '前往 {port} 需 {n} 食物', 'route.no_return': '没有可返回的已知港口',
    'route.stamina': '预计体力', 'route.stamina_value': '需要 {need} / 现有 {have}', 'route.hazards': '环境危害',
    'route.unknown': '未知', 'route.none': '无', 'route.capability': '推荐定位', 'route.level': '敌人等级',
    'route.events_exact': '海上事件预报', 'route.events_rough': '海上事件预报（粗略）',
    'route.return_warning': '这段航程之后，食物可能不够返航。紧急返航始终免费。',
    'route.first_discovery': '首次到访：会发现附近的地点。',
    'route.sail': '起航', 'route.fast': '快速航行', 'route.fast_hint': '快速航行只能在已到访且航线已标记的港口之间进行，并会跳过海上事件。',

    'site.title': '探索 {location}', 'site.fight': '战斗', 'site.search': '搜索', 'site.move': '穿过', 'site.move_free': '穿过已清理的房间不消耗体力。',
    'site.repeat': '再战一次', 'site.repeat_hint': '可选的重复战斗，可获得额外奖励。',
    'site.stamina_rule': '进入新房间会消耗体力。已清理的房间、撤退和离开都不消耗。',
    'legend.challenge': '挑战传说', 'legend.title': '{region}的传说', 'legend.won': '已击败传说'
  });

  // ------------------------------------------------------------------- port
  Object.assign(S, {
    'port.title': '港口', 'port.not_docked': '未停靠', 'port.not_docked_hint': '驶向港口即可交易、招募和投资。你最近的安全港口是 {location}。',
    'port.tab_invest': '投资', 'port.tab_market': '市场', 'port.tab_tavern': '酒馆', 'port.tab_workshop': '工坊', 'port.tab_board': '任务板', 'port.tab_services': '服务',
    'port.reputation': '声望：{list}',
    'port.invest_title': '港口投资', 'port.invest_hint': '每提升一级，都会在本港口永久解锁所列服务。',
    'port.track_level': '等级 {n} / 3', 'port.track_max': '已完全发展', 'port.invest_to': '投资至 {n} 级',
    'port.goods': '物资', 'port.food_rule': '食物只在出航时扣除一次，且不会退还。', 'port.stock': '{n} / {max}',
    'port.ingredients': '宠物食材', 'port.specialties': '地区特产', 'port.local_specialty': '本地特产',
    'port.specialty_rule': '特产可用于任务、委托、制作和孵蛋配方。在远离产地的地方出售更赚钱。',
    'port.owned': '持有 {n}', 'port.sell_price': '售价 {n}', 'port.sell_one': '出售 1 个', 'port.buy': '购买',
    'port.eggs': '宠物蛋', 'port.egg_offer': '{family}蛋', 'port.buy_egg': '购买宠物蛋',
    'port.equipment_shop': '装备', 'port.equip_stock': '储量 {n} / {max}', 'port.no_equipment': '当前市场等级没有出售装备。',
    'port.tavern_title': '酒馆', 'port.tavern_hint': '第 {day} 天会有新水手到来。酒馆等级 {level}。', 'port.recruit': '招募',
    'port.hired': '已招募', 'port.aptitudes_hidden': '天赋未显示（需要酒馆 2 级）', 'port.qualified': '具备资格：{cls}',
    'port.workshop_title': '工坊', 'port.workshop_ok': '这里可以制作装备。', 'port.affix': '词缀', 'port.no_affix': '无词缀',
    'port.no_recipes': '还不知道任何配方。配方来自支线任务和首领。', 'port.craft': '制作',
    'port.inventory': '库存 {n} / {max}', 'port.reinforce': '强化', 'port.salvage': '分解（+{n} 材料）', 'port.equipped_by': '{name} 装备中',
    'port.usable_by': '可用职业：{list}',
    'port.main_quest': '主线任务', 'port.quest_done': '已完成', 'port.quest_active': '已接受', 'port.deliver': '交付 {n} 个{item}',
    'port.side_quests': '支线任务', 'port.no_side': '本港口没有支线任务。', 'port.accept': '接受', 'port.complete': '完成',
    'port.reward': '奖励：{gold} 金币 · {xp} 经验 · {extra}',
    'port.contracts': '委托', 'port.contract_hint': '委托每三天轮换一次。最多可同时进行三个。',
    'port.contract_reward': '奖励：{gold} 金币 · {materials} 材料', 'port.contracts_elsewhere': '其他港口进行中的委托',
    'port.aid_title': '紧急援助', 'port.aid_hint': '负担不起基本开销时的免费帮助。你永远都能重新站起来。',
    'port.dock_work': '码头打工（+{n} 金币）', 'port.dock_work_hint': '船员去码头干一班活。耗时 4 小时，不花任何费用。',
    'port.dock_work_locked': '只有在金币不足时才能去码头打工。',
    'port.treatment': '治疗', 'port.no_injured': '没有受伤的船员。', 'port.recovery_room': '康复室：今天还剩 {n} 次免费治疗',
    'port.repair': '修船', 'port.wait_title': '休息', 'port.wait': '等待 6 小时', 'port.wait_hint': '消磨时间，让酒馆和委托轮换。'
  });

  // ---------------------------------------------------------------- pet lab
  Object.assign(S, {
    'pets.title': '宠物研究室', 'pets.count': '宠物 {n} / {max}', 'pets.eggs_count': '宠物蛋 {n} / {max}',
    'pets.hatchery_level': '孵化室 Lv {n}', 'pets.lab_level': '宠物研究室 Lv {n}', 'pets.no_hatchery': '船上没有孵化室', 'pets.no_lab': '船上没有宠物研究室',
    'pets.eggs': '宠物蛋', 'pets.no_eggs': '没有宠物蛋。', 'pets.no_eggs_hint': '宠物蛋来自秘密房间、岛屿秘洞、支线任务和港口市场（3 级）。',
    'pets.egg_sources': '宠物蛋来源', 'pets.grade': '品级 {n}',
    'pets.feed_title': '喂养{family}蛋', 'pets.feed_title_none': '请选择一枚宠物蛋',
    'pets.feed_rule': '按顺序喂入最多三种食材或特产。同一枚蛋、同样的顺序，孵出的宠物总是相同。',
    'pets.feed_n': '第 {n} 份', 'pets.empty_slot': '空', 'pets.clear': '清空', 'pets.max_inputs': '最多三份。',
    'pets.no_inputs': '没有食材或特产。', 'pets.inputs': '投入物', 'pets.nothing_queued': '还没有放入任何东西。',
    'pets.predicted_role': '倾向', 'pets.known_outcome': '已记录的结果', 'pets.unrecorded': '尚未记录',
    'pets.signatures': '族群特征序列', 'pets.signature_hint': '找到这个族群的线索，就能得知它的配方特征序列。',
    'pets.hatch': '孵化', 'pets.hatch_level': '需要孵化室', 'pets.prime': '完美孵化！', 'pets.none_left': '投入物已用完。',
    'pets.roster': '宠物', 'pets.no_pets': '还没有宠物。', 'pets.detail': '宠物详情', 'pets.roles': '定位', 'pets.ability': '能力', 'pets.power': '力量',
    'pets.affinity': '亲和：{color}',
    'pets.target_enemy': '攻击一名敌人', 'pets.target_owner': '协助主人', 'pets.target_allies': '协助全体队友',
    'pets.ab_power': '{pct} 攻击', 'pets.ab_heal': '治疗 {pct} 攻击', 'pets.ab_shield': '护盾 {pct} 最大生命',
    'pets.assignment': '分派', 'pets.unassigned': '未分派', 'pets.unassign': '取消分派', 'pets.with': '跟随 {name}', 'pets.at': '在 {facility}',
    'pets.helper_half': '天生不是帮手：效果减半。', 'pets.send_explore': '派去探索', 'pets.recall': '召回',
    'pets.evolution': '进化', 'pets.evolve': '进化', 'pets.evolve_hint': '需要宠物研究室，且宠物达到 {level} 级。', 'pets.evolved': '已进化',
    'pets.evolved_note': '进化是永久的，并会保留所有分派。'
  });

  // ------------------------------------------------------------------ codex
  Object.assign(S, {
    'codex.title': '图鉴', 'codex.captain': '{title} · 赢得试炼 {n} 次',
    'codex.tab_locations': '海域', 'codex.tab_enemies': '敌人', 'codex.tab_classes': '职业', 'codex.tab_pets': '宠物', 'codex.tab_items': '物品', 'codex.tab_clues': '线索',
    'codex.region_locked': '未解锁的海域', 'codex.arc': '主线', 'codex.hazard': '环境危害', 'codex.mechanic': '战斗规则', 'codex.pet_family': '宠物族群',
    'codex.trial': '船长试炼', 'codex.trial_won': '已获胜', 'codex.trial_pending': '尚未获胜', 'codex.none_value': '—',
    'codex.unknown_location': '未标记', 'codex.unknown_enemy': '未知敌人', 'codex.unknown_class': '未知职业', 'codex.unknown_pet': '未知',
    'codex.defeated': '已击败 {n}', 'codex.boss': '首领', 'codex.rival': '对手船长', 'codex.classes_hint': '有船员修习某个职业后，它才会出现在这里。',
    'codex.hatch_log': '孵化记录', 'codex.hatch_hint': '每次孵化都会被记录：同一族群、同样的投入顺序，会孵出同样的宠物。',
    'codex.no_hatches': '还没有孵化记录。', 'codex.family': '族群', 'codex.order': '投入顺序', 'codex.result': '结果',
    'codex.items_seen': '见过的物品', 'codex.recipes': '配方', 'codex.recipe_known': '已知', 'codex.recipe_cost': '{n} 材料 · {k} 个{item}',
    'codex.blueprints': '蓝图', 'codex.uniques': '独特装备', 'codex.none': '暂无。', 'codex.no_clues': '还没有找到线索。'
  });

  // ----------------------------------------------------------------- system
  Object.assign(S, {
    'system.title': '系统', 'system.storage_local': '浏览器存储', 'system.storage_memory': '临时存储',
    'system.storage_memory_hint': '此浏览器禁止本地存储，存档只会保留到页面关闭。请导出存档文件以保存进度。',
    'system.last_saved': '已于 {time} 保存', 'system.last_save_failed': '上次保存失败',
    'system.manual': '手动存档', 'system.manual_hint': '只有在你主动选择时才会写入手动存档栏位。',
    'system.slot_n': '栏位 {n}', 'system.slot_empty': '空', 'system.slot_corrupt': '存档已损坏（无法读取）',
    'system.save_here': '保存', 'system.load': '读取', 'system.delete': '删除',
    'system.overwrite_title': '覆盖存档？', 'system.overwrite_body': '栏位 {n} 将被当前游戏替换。',
    'system.load_title': '读取这个存档？', 'system.load_body': '上次自动存档之后未保存的进度将会丢失。',
    'system.load_recovery_body': '读取这个恢复存档？更新的进度仍保留在其他恢复栏位中。',
    'system.delete_title': '删除存档？', 'system.delete_body': '栏位 {n} 将被清除。',
    'system.recovery': '恢复存档', 'system.recovery_hint': '游戏会保留最近 {n} 次自动存档：停靠港口、战斗后、试炼和船体升级时。',
    'system.recovery_latest': '最新', 'system.recovery_older': '更早 {n} 次', 'system.no_recovery': '还没有恢复存档。',
    'system.transfer': '导出与导入', 'system.transfer_hint': '存档文件是纯 JSON 格式，两种语言通用。',
    'system.export': '导出存档', 'system.import': '导入存档', 'system.exported': '存档已导出。',
    'system.import_title': '导入这个存档？', 'system.import_body': '当前游戏将被替换。恢复存档会保留之前的状态。',
    'system.settings': '设置', 'system.text_scale': '文字大小', 'system.battle_speed': '战斗速度', 'system.reduce_motion': '减少动态效果',
    'system.pause_start': '战斗开始时暂停',
    'system.language': '语言', 'system.language_hint': '更改语言会重新启动游戏，不影响存档。',
    'system.language_current': '这是当前语言。', 'system.restart_language': '以此语言重新启动',
    'system.restart_title': '重新启动游戏？', 'system.restart_body': '游戏会先保存，然后以{lang}重新启动。',
    'system.captain': '船长', 'system.profile': '档案', 'system.seed': '世界种子', 'system.transactions': '事务数',
    'system.battles': '战斗', 'system.battles_value': '胜 {w} · 负 {l} · 撤退 {r}', 'system.voyages': '航行次数', 'system.postgame': '终局后',
    'system.title_screen': '标题画面', 'system.new_game': '新游戏', 'system.new_title': '开始新游戏？',
    'system.new_body': '当前游戏的手动存档会保留，但恢复存档将被清空。',
    'system.new_started': '新的航程开始了。', 'system.saved_slot': '已保存到栏位 {n}。', 'system.loaded': '存档已读取。',
    'system.crew_n': '{n} 名船员', 'system.trials_n': '{n} 次试炼',
    'system.shortcuts': '键盘快捷键',
    'system.shortcuts_list': '1–8 切换界面 · 战斗中：空格/P 暂停，1/2/4 调整速度，R 撤退，S 跳过，回车 继续 · 船只编辑：R 旋转，Esc 取消'
  });

  // ----------------------------------------------------------------- battle
  Object.assign(S, {
    'battle.title_sea': '{location}附近：{kind}', 'battle.title_room': '{room} · {location}', 'battle.title_legend': '{region}的传说',
    'battle.wave': '第 {n}/{max} 波', 'battle.time': '{n} 秒 / {max} 秒', 'battle.allies': '我方船员', 'battle.enemies': '敌人',
    'battle.pause': '暂停', 'battle.resume': '继续', 'battle.paused': '已暂停——调整战术后继续。',
    'battle.skip': '跳到结束', 'battle.skip_hint': '以当前战术立即结算剩余战斗。',
    'battle.retreat': '撤退', 'battle.retreating': '撤退中……{n} 秒', 'battle.retreat_hint': '船员需要 {n} 秒撤离。撤退不消耗任何东西，但会放弃奖励。',
    'battle.stance': '姿态', 'battle.priority': '技能优先级', 'battle.focus': '集火目标', 'battle.focus_auto': '自动',
    'battle.focus_hint': '点击以集火这名敌人。', 'battle.status': '{stance} · {priority} · 集火：{focus}',
    'battle.log': '战斗记录', 'battle.winding': '正在蓄力 {skill}（{n} 秒）', 'battle.interrupted': '被打断！', 'battle.miss': '未命中',
    'battle.basic_attack': '攻击', 'battle.mod_trial': '船长试炼',
    'battle.ev_wave': '第 {n} 波，共 {max} 波。', 'battle.ev_hit': '{src} 用{skill}击中 {tgt}，造成 {n} 点伤害。', 'battle.ev_crit': '暴击！{src} 用{skill}击中 {tgt}，造成 {n} 点伤害。',
    'battle.ev_absorbed': '（吸收 {n}）', 'battle.ev_miss': '{tgt} 躲开了 {src} 的攻击。', 'battle.ev_heal': '{src} 为 {tgt} 恢复 {n} 点生命。',
    'battle.ev_ko': '{tgt} 被击倒了。', 'battle.ev_skill': '{src} 使用了{skill}。', 'battle.ev_windup': '{src} 正对 {tgt} 蓄力{skill}！',
    'battle.ev_interrupt': '{tgt} 的{skill}被打断了。', 'battle.ev_stun': '{tgt} 被眩晕 {n} 秒。',
    'battle.ev_intercept': '{src} 替 {tgt} 挡下了攻击。', 'battle.ev_thorns': '{tgt} 受到 {src} 的 {n} 点反伤。',
    'battle.ev_trap': '陷阱对 {tgt} 造成 {n} 点伤害。', 'battle.ev_resist': '{tgt} 抵抗了效果。', 'battle.ev_dot': '{tgt} 受到 {n} 点灼烧伤害。',
    'battle.ev_pet': '{src} 使用了{ability}。', 'battle.ev_hazard': '环境危害：{hazard}来袭。', 'battle.ev_encore': '传说再度站起，返场再战！',
    'battle.ev_command_focus': '命令：集火 {value}。', 'battle.ev_command_stance': '命令：姿态改为{value}。',
    'battle.ev_command_priority': '命令：优先级改为{value}。', 'battle.ev_command_retreat': '命令：撤退！',
    'battle.ev_end_victory': '胜利！', 'battle.ev_end_defeat': '战败。', 'battle.ev_end_retreat': '船员撤离了战斗。',
    'battle.outcome_victory': '胜利', 'battle.outcome_defeat': '战败', 'battle.outcome_defeat_timeout': '战败——时间耗尽', 'battle.outcome_retreat': '已撤退',
    'battle.result_time': '{n} 秒 · 船员生命 {hp}', 'battle.result_error': '无法结算这场战斗。你的游戏没有被改动。',
    'battle.r_gold': '+{n} 金币', 'battle.r_materials': '+{n} 材料', 'battle.r_food': '+{n} 食物', 'battle.r_supplies': '+{n} 补给',
    'battle.r_item': '获得：{item}', 'battle.r_specialty': '+{n} {item}', 'battle.r_ingredients': '食材：{list}', 'battle.r_egg': '宠物蛋：{family}（品级 {n}）',
    'battle.r_clue': '线索：{clue}', 'battle.r_xp': '+{n} 经验', 'battle.r_ledger': '金币和材料会先记入未入账，停靠港口后入账。',
    'battle.r_arrived': '已抵达 {location}。',
    'battle.retreat_result': '你安全撤离了。没有任何损失，也没有消耗体力。',
    'battle.defeat_result': '损失了 {gold} 未入账金币和 {materials} 材料。船员被送回了 {location}。',
    'battle.defeat_injured': '受伤：{list}', 'battle.defeat_facility': '损坏：{facility}',
    'battle.defeat_keep': '等级、精通度、装备、宠物和海图永远不会丢失。', 'battle.continue': '继续'
  });

  // ------------------------------------------------------------- sea events
  Object.assign(S, {
    'sea.continue': '继续', 'sea.vessel.help': '分出 2 份食物', 'sea.vessel.ignore': '继续航行', 'sea.inspection.pay': '缴纳通行费', 'sea.inspection.refuse': '拒绝',
    'sea.pirate.title': '海盗袭击', 'sea.pirate.desc': '黑帆从{region}的海面逼近，他们要强行登船。', 'sea.pirate.effect': '登船战开始。',
    'sea.monster.title': '海怪', 'sea.monster.desc': '有个庞然大物从{region}的海水中升起。', 'sea.monster.effect': '战斗开始。',
    'sea.cache.title': '漂流箱', 'sea.cache.desc': '一只密封的木箱在{region}的浪涛中浮沉。', 'sea.cache.effect': '你获得了补给和材料。',
    'sea.vessel.title': '遇难船只', 'sea.vessel.desc': '一艘来自{region}的小船发出求救信号。', 'sea.vessel.effect': '提供帮助需要 2 份食物，可获得金币和好感。',
    'sea.shortcut.title': '隐秘洋流', 'sea.shortcut.desc': '你的领航员在{region}发现了一股快速洋流。', 'sea.shortcut.effect': '此海域内的航线少消耗 1 份食物；也许还会发现一个未标记的地点。',
    'sea.weather.title': '狂风骤雨', 'sea.weather.desc': '一场突如其来的暴风雨席卷了{region}。', 'sea.weather.effect': '如果没有领航员或防御工事舱，船体会受损并耽误 2 小时。',
    'sea.inspection.title': '红旗盘查', 'sea.inspection.desc': '一支挂着红旗的巡逻队在{region}拦下了你。', 'sea.inspection.effect': '缴纳 {n} 金币，或拒绝并耽误 6 小时。',
    'sea.clue.title': '漂流瓶', 'sea.clue.desc': '一只漂流瓶漂过，里面的字条写着{region}生物的事情。', 'sea.clue.effect': '你可能会得到一条宠物族群线索。'
  });

  // ------------------------------------------------------------------ errors
  Object.assign(S, {
    'err.unknown': '现在无法这样做。', 'err.internal': '出了点问题。你的游戏没有被改动。',
    'err.in_encounter': '请先结束当前战斗。', 'err.no_encounter': '当前没有进行中的战斗。', 'err.no_event': '没有需要处理的海上事件。',
    'err.event_pending': '请先处理海上事件。', 'err.need_port': '只能在停靠港口时进行。', 'err.wrong_port': '本港口不提供此项。',
    'err.already_docked': '你已经停靠在港口了。', 'err.same_location': '你已经在这里了。', 'err.unknown_location': '未知地点。',
    'err.not_revealed': '这个地点尚未标记在海图上。', 'err.region_locked': '这片海域仍未解锁。', 'err.not_at_site': '你不在那个地点。',
    'err.room_locked': '请先清理一个相邻的房间。', 'err.room_depleted': '这个房间已经空了。', 'err.trial_locked': '船长试炼将在主线完成后开放。',
    'err.fast_ports_only': '快速航行只能连接港口。', 'err.fast_not_visited': '快速航行需要两个港口都已到访。', 'err.fast_not_charted': '这条航线尚未标记。',
    'err.no_food': '需要 {need} 食物。', 'err.no_food_route': '食物不足以完成这段航线。', 'err.no_gold': '需要 {need} 金币。',
    'err.no_materials': '需要 {need} 材料。', 'err.no_supplies': '需要 {need} 补给。', 'err.no_specialty': '需要 {need} 个{item}。',
    'err.no_input': '你没有{item}。', 'err.no_stamina': '需要 {need} 体力（现有 {have}）。', 'err.stamina_full': '体力已满。',
    'err.food_full': '食物储存已满。', 'err.supplies_full': '补给储存已满。', 'err.equip_full': '装备储存已满。',
    'err.empty_formation': '编队中至少要有一名船员。', 'err.layout_blocked': '船只布局不允许出航。',
    'err.over_capacity': '船员超出床位。', 'err.need_facility': '需要{facility}。', 'err.need_infirmary': '需要船上的医务室或在港口进行。',
    'err.need_workshop': '需要船上的工坊或港口工坊。', 'err.need_workshop2': '需要 2 级工坊。',
    'err.need_bench': '需要材料工作台。', 'err.need_class_hall': '需要职业大厅。', 'err.need_muster': '需要集结甲板。',
    'err.need_explorer': '需要一只探索宠物。', 'err.market_level': '需要市场 {level} 级。', 'err.board_level': '需要任务板 {level} 级。',
    'err.max_level': '已达到最高等级。', 'err.build_limit': '已达到建造上限。', 'err.hull_tier': '需要 {tier} 阶船体。',
    'err.cannot_demolish_cabin': '船长室无法拆除。', 'err.out_of_bounds': '超出甲板范围。', 'err.cell_blocked': '这个格子被挡住了。',
    'err.cell_occupied': '这个格子已被占用。', 'err.cell_door': '门口必须保持通畅。', 'err.cell_entry': '甲板入口必须保持通畅。',
    'err.cell_stair': '那里有楼梯。', 'err.bad_cell': '无效的格子。', 'err.no_lower_deck': '下方没有甲板。',
    'err.no_preset': '这个预设是空的。', 'err.nothing_to_repair': '没有需要维修的地方。',
    'err.hull_owned': '你已经拥有这个或更好的船体。', 'err.hull_previous': '请先升级到上一级船体。',
    'err.hull_region': '抵达{region}后解锁。', 'err.hull_blueprint': '需要传说龙骨蓝图。', 'err.hull_required': '需要升级船体。',
    'err.job_full': '没有空闲的工作位置。', 'err.no_job_slots': '这个设施没有工作岗位。', 'err.last_crew': '不能解雇最后一名船员。',
    'err.already_hired': '已经招募过了。', 'err.not_injured': '没有受伤。', 'err.not_qualified': '不具备{cls}的资格。',
    'err.not_mastered': '请先精通这个职业。', 'err.same_class': '已经是这个职业了。', 'err.legacy_duplicate': '已经选择了这个被动。',
    'err.weapon_incompatible': '{cls}无法使用这件武器。', 'err.wrong_slot': '装备栏位不对。', 'err.equipped': '请先卸下它。',
    'err.no_recipe': '未知配方。', 'err.not_sold': '这里不出售。', 'err.nothing_to_deliver': '没有可交付的东西。',
    'err.already_accepted': '已经接受了。', 'err.contract_limit': '已有三个进行中的委托。', 'err.contract_incomplete': '尚未完成（{have}/{need}）。',
    'err.aid_not_needed': '你自己负担得起。', 'err.pet_full': '没有空间容纳更多宠物。', 'err.pet_level': '需要宠物达到 {level} 级。',
    'err.pet_role': '这只宠物不能担任{role}。', 'err.pet_owner': '这名船员不在编队中。', 'err.already_evolved': '已经进化过了。',
    'err.hatch_inputs': '请给宠物蛋喂入一到三份投入物。', 'err.no_legend': '这里没有传说。', 'err.postgame_only': '获得称号后开放。',
    'err.save_write_failed': '无法保存游戏。请释放一些存储空间或导出存档。', 'err.save_missing': '找不到存档。',
    'err.save_corrupt': '这个存档已损坏，无法读取。', 'err.save_newer': '这个存档来自更新的版本。', 'err.save_old': '这个存档的版本已不受支持。'
  });

  // --------------------------------------------------------------------- log
  Object.assign(S, {
    'log.empty': '还没有记录。', 'log.new_game': '你在明港接管了一艘小船。',
    'log.arrived': '抵达 {location}。', 'log.revealed': '在海图上标记了 {location}。', 'log.cleared': '清理了 {location}。',
    'log.banked': '入账 {gold} 金币和 {materials} 材料。', 'log.defeat': '战败。损失了 {gold} 金币和 {materials} 材料。',
    'log.retreated': '船员撤退了。', 'log.emergency_return': '紧急返航至 {location}。', 'log.boarded': '遭遇：{kind}。',
    'log.weather_damage': '暴风雨损坏了船体。', 'log.waited': '休息了 6 小时。', 'log.repaired': '船只已修复。',
    'log.built': '建造了{facility}。', 'log.upgraded': '{facility}升级到 {level} 级。', 'log.demolished': '拆除了{facility}（+{gold} 金币，+{materials} 材料）。',
    'log.hull_upgraded': '船体升级为{hull}。', 'log.recruited': '{crew} 加入了船队。', 'log.level_up': '{crew} 升到了 {level} 级。',
    'log.respec': '{crew} 从{from}转职为{to}。', 'log.treated': '{crew} 接受了治疗。', 'log.unequipped': '{item}已从 {crew} 身上退回货舱。',
    'log.crew_event_done': '{crew} 完成了「{event}」。', 'log.aid': '获得紧急援助：{kind}。', 'log.dock_work': '码头打工赚了 {gold} 金币。',
    'log.invested': '在 {port} 投资了{track}（{level} 级）。', 'log.crafted': '制作了{item}。', 'log.blueprint': '获得蓝图：{item}。',
    'log.equip_overflow': '{item}没有地方放，以 {n} 金币卖掉了。', 'log.food_overflow': '有 {n} 份食物放不进食物储藏室。',
    'log.supply_overflow': '有 {n} 份补给放不进货舱。', 'log.quest_accepted': '已接受：{quest}。', 'log.side_done': '已完成：{quest}。',
    'log.main_done': '主线步骤完成：{quest}。', 'log.contract_done': '委托完成（+{gold} 金币）。', 'log.clue': '新线索：{clue}',
    'log.egg_found': '找到一枚{family}蛋。', 'log.hatched': '孵化出了{species}。', 'log.hatched_prime': '完美孵化：{species}！',
    'log.evolved': '进化为{species}。', 'log.pet_found_secret': '你的探索宠物发现了一处秘境。',
    'log.trial_won': '在{region}的船长试炼中战胜了 {rival}。', 'log.region_unlocked': '新的海域开放了：{region}。',
    'log.legend_won': '击败了{region}的传说。', 'log.postgame': '你现在是七海最强船长了。'
  });

  // --------------------------------------------------- generic small families
  Object.assign(S, {
    'stat.hp': '生命', 'stat.atk': '攻击', 'stat.def': '防御', 'stat.spd': '速度', 'stat.crit': '暴击', 'stat.dodge': '闪避',
    'stat.hp_short': '命', 'stat.atk_short': '攻', 'stat.def_short': '防', 'stat.spd_short': '速',
    'skill.power': '{pct} 攻击', 'skill.heal': '治疗 {pct} 攻击', 'skill.cd': '冷却 {n} 秒', 'skill.cond_critical': '仅在有队友生命低于 35% 时',
    'item.set_format': '{tier}{type}', 'item.affix_format': '{affix}{name}', 'item.resist': '抵抗{hazard}',
    'pet.species_format': '{family}·{form}', 'blueprint.legend_keel': '传说龙骨蓝图',
    'odds.high': '很可能', 'odds.mid': '有可能', 'odds.low': '罕见',
    'contract.hunt': '在{region}击败 {need} 名敌人（{have}/{need}），然后向 {port} 回报。', 'contract.supply': '向 {port} 运送 {need} 份补给。',
    'contract.haul': '把 {need} 个{item}运到 {port}。', 'contract.hunt.title': '悬赏讨伐', 'contract.supply.title': '补给运送', 'contract.haul.title': '货物运输'
  });
  put('role.', { vanguard: '先锋', striker: '输出', controller: '控制', support: '支援', scout: '侦察' });
  pair('lane.', { front: ['前排', '承受大部分攻击。'], center: ['中排', '受前排掩护。'], rear: ['后排', '最安全；适合远程和支援。'] }, '', '.desc');
  pair('loctype.', {
    port: ['港口', '安全的港湾：交易、招募、投资，以及货物入账。'], island: ['岛屿', '有资源、战斗和隐藏秘洞的房间。'],
    dungeon: ['地下城', '由首领把守的深处地点。'], wreck: ['沉船', '短暂的打捞潜水。'], arena: ['竞技场', '船长试炼的举办地。'],
    secret: ['秘境', '与本海域宠物族群相关的隐藏地点。']
  }, '', '.desc');
  put('know.', { hidden: '未发现', revealed: '已发现', visited: '已到访', cleared: '已清理' });
  put('cat.', { damage: '伤害', control: '控制', support: '支援', survival: '生存' });
  put('slot.', { weapon: '武器', outfit: '服装', accessory: '饰品' });
  put('range.', { melee: '近战', ranged: '远程' });
  put('scope.', { enemy: '单个敌人', self: '自身', front_allies: '前排队友', enemy_lane: '一排敌人', enemies: '全体敌人', ally: '单个队友', allies: '全体队友' });
  put('color.', { red: '红', blue: '蓝', green: '绿', yellow: '黄', purple: '紫', white: '白' });
  put('archetype.', { skirmisher: '游击者', brute: '蛮兵', shooter: '射手', caster: '施法者', healer: '治疗者', boss: '首领', captain: '船长', decoy: '诱饵' });
  put('roomkind.', { battle: '战斗', resource: '资源', elite: '精英战', boss: '首领', event: '事件', trial: '船长试炼' });
  put('reward.family.', { materials: '材料', specialty: '特产', gold: '金币', ingredients: '食材', egg: '宠物蛋', supplies: '补给', equipment: '装备' });
  put('reward.kind.', { recipe: '一份配方', supplies: '补给', ingredients: '食材', clue: '一条宠物线索', egg: '一枚宠物蛋' });
  put('qtype.', {
    clear: '清理 {location}', visit: '前往 {location}', deliver: '在 {location} 交付 {count} 个{item}',
    trial: '赢得 {location} 的船长试炼', discover: '发现 {location}'
  });
  pair('side.', {
    survey: ['勘察 {location}', '港湾联盟希望把 {location} 的每个房间都标记清楚。'],
    salvage: ['打捞 {location}', '取回 {location} 沉船里剩下的东西。'],
    outpost: ['确保 {location}', '清理 {location}，好让联盟建立前哨。'],
    legend: ['{location}的传说', '古老的歌谣提到一处隐秘之地：找到 {location}。'],
    depths: ['深入 {location}', '潮缚学会想要 {location} 深处的样本。']
  }, '.title', '.desc');
  put('faction.', { conclave: '地平线议会', league: '港湾联盟', tidebound: '潮缚学会', pennants: '红旗帮' }, '.name');
  put('rank.', { 0: '陌生人', 1: '熟识', 2: '信赖', 3: '尊崇' });
  pair('aid.', {
    meal: ['免费餐食', '负担不起时，提供下一段航程所需的食物。'],
    treatment: ['免费治疗', '为受伤船员提供基本护理。'],
    repair: ['免费抢修', '必要的维修，让船只能够起航。']
  }, '', '.desc');
  put('legend.restriction.', { double_hazard: '双重危害', no_healing: '禁止治疗', four_crew: '仅限四人', endless_waves: '无尽波次', encore: '返场' });
  pair('stance.', {
    aggressive: ['猛攻', '伤害更高、防御更低；技能一就绪就会释放。'],
    balanced: ['均衡', '没有修正。'],
    defensive: ['防守', '受到伤害更少，进攻更慢；更早治疗。'],
    escape: ['脱离', '船员闪避更高，专注于保命。']
  }, '.name', '.desc');
  pair('priority.', {
    auto: ['自动', '每名船员根据当下情况选择最佳技能。'],
    survival: ['生存', '优先使用护盾、嘲讽和治疗。'],
    control: ['控制', '优先使用眩晕和减速；打断蓄力。'],
    damage: ['伤害', '优先使用伤害技能。'],
    support: ['支援', '优先使用增益和治疗。']
  }, '.name', '.desc');
  pair('track.', {
    market: ['市场', '出售商品，价格更优惠。'], tavern: ['酒馆', '更多、更强的新水手。'],
    workshop: ['工坊', '制作、强化和船体工程。'], quest_board: ['任务板', '支线任务和委托。'],
    navigation: ['航海局', '预报、航线标记和地图。']
  }, '.name', '.desc');
  Object.assign(S, {
    'track.market.l1': '补给、宠物食材和基础装备', 'track.market.l2': '本地特产和地区装备店', 'track.market.l3': '宠物蛋、地区饰品、九折优惠、更高的售价',
    'track.tavern.l1': '从八个职业中提供三名新水手', 'track.tavern.l2': '四名新水手，涵盖所有职业和出身，显示天赋', 'track.tavern.l3': '五名等级更高的新水手',
    'track.workshop.l1': '制作已知配方', 'track.workshop.l2': '强化装备、附加词缀、升级船体', 'track.workshop.l3': '工匠大师：制作和强化费用降低 25%',
    'track.quest_board.l1': '支线任务', 'track.quest_board.l2': '轮换委托', 'track.quest_board.l3': '揭示本海域的秘境',
    'track.navigation.l1': '本海域的精确海况预报和环境危害', 'track.navigation.l2': '标记本海域两个港口之间的航线', 'track.navigation.l3': '揭示本海域所有非秘境地点'
  });

  // ----------------------------------------------------------- modifiers etc.
  put('mod.', {
    defPct: '防御 +{pct}', intercept: '{pct} 几率替队友承受攻击', hpPct: '最大生命 +{pct}', thorns: '反弹 {pct} 的近战伤害',
    crit: '暴击率 +{pct}', spd: '速度 +{n}', dodge: '闪避 +{pct}', bossDmg: '对首领伤害 +{pct}', defIgnore: '无视 {pct} 防御',
    markedDmg: '对被标记的敌人伤害 +{pct}', atkPct: '攻击 +{pct}', cdr: '技能冷却 −{pct}', controlPct: '控制效果 +{pct}',
    healPct: '治疗量 +{pct}', auraRegen: '全队每秒恢复生命', foodSave: '每次出航节省 {n} 食物', supplyPct: '补给恢复的体力 +{pct}',
    xpPct: '经验 +{pct}', avoid: '海上事件 −{pct}', lootPct: '战斗战利品 +{pct}', auraDodge: '全队闪避 +{pct}', jobPct: '船上工作效率 +{pct}',
    teamShield: '全队开战时获得 {pct} 最大生命的护盾', petPct: '宠物力量 +{pct}', hazardResist: '免疫地区环境危害',
    goldPct: '战斗金币 +{pct}', auraAtk: '全队攻击 +{pct}', masteryPct: '职业精通 +{pct}', firstAid: '每场战斗一次，生命低时恢复 {pct} 最大生命',
    quickStart: '开战时拥有 {n} 技能能量', focusDmg: '对集火目标伤害 +{pct}', stunImmune: '免疫眩晕',
    lifesteal: '吸血 {pct}', escape: '撤退时间减半'
  });
  put('fx.', {
    stun: '眩晕 {secs} 秒', taunt: '嘲讽 {secs} 秒', shield: '护盾 {pct} 最大生命', slow: '减速 {secs} 秒', evade: '闪避 {secs} 秒',
    boss: '对首领 +{pct}', mark: '标记 {secs} 秒', pierce: '无视 {pct} 防御', reachAll: '可攻击任意一排', snipe: '狙击最虚弱的敌人',
    execute: '对重伤敌人额外伤害', sunder: '破坏护甲', cleanse: '移除减益', regen: '{dur} 秒内每秒恢复 {pct} 最大生命',
    buffAtk: '{dur} 秒内攻击 +{pct}', buffDef: '{dur} 秒内防御 +{pct}', meter: '技能能量 +{n}', trap: '布置陷阱（{pct} 攻击，眩晕 {stun} 秒）',
    dot: '{dur} 秒内每秒灼烧 {pct} 攻击', pet: '伙伴宠物出击（×{n}）', dispel: '驱散敌人的护盾和增益', cleanseAllies: '净化全体队友',
    plunder: '掠夺额外金币', windup: '蓄力 {secs} 秒，可被打断'
  });
  put('prop.', {
    guard: '守护：可能替队友挡下攻击', reach: '长柄：可越过前排攻击', ranged: '远程：可攻击任意一排',
    double: '连击：两次 60% 的攻击', mend: '疗愈：普通攻击会治疗受伤队友', nourish: '滋养：攻击同时治疗最虚弱的队友',
    splash: '溅射：波及同一排的其他敌人', sunder: '破甲：攻击会削弱护甲', pet: '宠物羁绊：伙伴行动更快、打得更狠',
    aura: '光环：提升全队攻击', chill: '寒霜：攻击会减速目标', pierce: '穿透：无视 25% 防御', crit: '锋锐：暴击率 +10%',
    lifesteal: '吸血：恢复造成伤害的 15%'
  });

  // ------------------------------------------------------------ hulls/facil.
  pair('hull.', {
    starter: ['漂木单桅船', '一艘单层甲板的小船，刚好放得下必需设施。'],
    voyager: ['远航双桅船', '增加一层带隔舱门的甲板，可用于生产和训练。'],
    adventurer: ['冒险护卫舰', '为风暴频发的中部海域打造的长船体。'],
    legend: ['传说大帆船', '四层甲板的旗舰，配得上最强的船长。']
  }, '.name', '.desc');
  put('faccat.', { command: '指挥', living: '生活', training: '训练', medical: '医疗', production: '生产', navigation: '航海', storage: '储存', pet: '宠物', social: '社交', defense: '防御' });
  pair('fac.', {
    captains_cabin: ['船长室', '必需。指挥中心；升级可提高体力上限。'],
    chart_table: ['海图桌', '精确的海况预报、已知环境危害，海盗更少。'],
    muster_deck: ['集结甲板', '船员每场战斗开始时获得额外技能能量。'],
    crew_quarters: ['船员舱', '必需。船员的床位。'],
    mess_hall: ['餐厅', '口粮恢复更多体力，航行消耗更少食物。'],
    practice_deck: ['训练甲板', '不在编队中的船员也能获得经验。'],
    class_hall: ['职业大厅', '更快精通职业。'],
    infirmary: ['医务室', '在海上治疗伤势，并减少战败造成的受伤。'],
    recovery_room: ['康复室', '在港口每天可免费治疗。'],
    galley: ['厨房', '用金币烹饪食物，在海上也可以。'],
    workshop: ['工坊', '制作装备，并用材料制作补给。'],
    material_bench: ['材料工作台', '从战斗和分解中获得更多材料。'],
    lookout: ['瞭望台', '抵达时发现相邻地点。'],
    compass_room: ['罗盘室', '跨海域航行更省，并知晓环境危害。'],
    tide_archive: ['潮汐档案馆', '全体船员获得更多经验。'],
    pantry: ['食物储藏室', '必需。储存食物。'],
    cargo_hold: ['货舱', '更多补给和装备储存空间。'],
    secure_locker: ['保险柜', '额外的装备储存空间。'],
    hatchery: ['孵化室', '孵化宠物蛋，并能存放更多宠物蛋。'],
    pet_lab: ['宠物研究室', '让宠物进化，并能饲养更多宠物。'],
    creature_pens: ['生物围栏', '可饲养更多宠物。'],
    tavern_corner: ['酒馆角', '每家酒馆多一名新水手，招募更便宜。'],
    story_deck: ['故事甲板', '个人故事奖励更多经验。'],
    music_room: ['音乐室', '全体船员获得更多经验。'],
    boarding_gate: ['登船门', '登船战开始时船员获得大量技能能量。'],
    barricade_room: ['防御工事舱', '登船战中受到的伤害更少；抵御暴风雨。'],
    guard_post: ['警卫哨', '登船战开始时前排船员获得护盾。']
  }, '.name', '.desc');

  // ------------------------------------------------------------- classes etc.
  pair('class.', {
    guard: ['护卫', '用盾牌和嘲讽守护前线。'],
    duelist: ['决斗者', '迅捷的剑士，专门惩罚单个目标。'],
    spearfighter: ['枪兵', '长柄战士，可越过前排攻击。'],
    gunner: ['枪手', '从后排进行远程输出。'],
    brawler: ['拳斗士', '近身打手，擅长击碎护甲。'],
    medic: ['医师', '用治疗和净化让船员保持战斗。'],
    cook: ['厨师', '在战斗中给船员加餐，在海上节省食物。'],
    navigator: ['领航员', '读懂大海：标记目标、避开麻烦。'],
    tinkerer: ['工匠', '屏障、陷阱和小机关。'],
    beastkeeper: ['驯兽师', '与伙伴宠物并肩作战。'],
    mystic: ['秘术师', '使用范围攻击的元素施法者。'],
    quartermaster: ['军需官', '旗帜、增益和更好的战利品。'],
    guardian: ['守护者', '护卫分支：守护整条战线的坚墙。'],
    bulwark: ['壁垒', '护卫分支：会反击的重甲。'],
    blade_dancer: ['剑舞者', '决斗者分支：横扫一排的旋舞斩击。'],
    challenger: ['挑战者', '决斗者分支：点名挑战并击倒首领。'],
    harpooner: ['鱼叉手', '枪兵分支：把敌人拖进攻击范围。'],
    dragoon: ['龙骑兵', '枪兵分支：从空中跃下突刺。'],
    sharpshooter: ['神射手', '枪手分支：精准射击弱点。'],
    skirmisher: ['游击手', '枪手分支：覆盖所有排的齐射。'],
    breaker: ['破坏者', '拳斗士分支：粉碎护甲和护盾。'],
    grappler: ['摔角手', '拳斗士分支：擒抱与摔投。'],
    surgeon: ['外科医生', '医师分支：强力的急救治疗。'],
    lifekeeper: ['守命者', '医师分支：为全队持续再生。'],
    provisioner: ['补给官', '厨师分支：海上的补给与体力。'],
    feastmaster: ['宴会大师', '厨师分支：振奋全队的盛宴。'],
    pathfinder: ['探路者', '领航员分支：捷径与伏击。'],
    tide_reader: ['观潮者', '领航员分支：扭转战局。'],
    engineer: ['工程师', '工匠分支：炮塔与装甲板。'],
    trapper: ['陷阱师', '工匠分支：网与套索。'],
    beastwarden: ['兽群守卫', '驯兽师分支：守护群体的宠物。'],
    wildspeaker: ['野性呼唤者', '驯兽师分支：释放野性。'],
    stormcaller: ['唤雷者', '秘术师分支：连锁闪电。'],
    hexbreaker: ['破咒者', '秘术师分支：驱散与守护。'],
    purser: ['事务长', '军需官分支：每场战斗获得更多金币。'],
    standard_bearer: ['旗手', '军需官分支：高举战旗。']
  }, '.name', '.desc');
  put('skill.', {
    shield_bash: '盾击', hold_the_line: '坚守阵线', guardian_wall: '守护之墙', quake_slam: '震地猛击', lunge: '突刺', riposte: '还击',
    whirling_blades: '旋舞之刃', call_out: '点名挑战', piercing_thrust: '穿刺', sweep_spear: '横扫长枪', harpoon_pull: '鱼叉拖拽',
    sky_dive: '凌空俯冲', aimed_shot: '瞄准射击', smoke_shell: '烟雾弹', headshot: '爆头', scatter_volley: '散射齐射', haymaker: '重拳',
    brawl: '乱斗', armor_crush: '碎甲', suplex: '抱摔', first_aid: '急救', cleanse: '净化', emergency_surgery: '紧急手术',
    renewal: '复苏', hearty_snack: '丰盛点心', spice_bomb: '香料弹', supply_drop: '空投补给', grand_feast: '盛宴', mark_target: '标记目标',
    quick_read: '快速判读', shortcut_strike: '捷径突袭', ebb_tide: '退潮', deploy_barrier: '展开屏障', spring_trap: '弹簧陷阱',
    turret: '炮塔', snare_net: '捕网', sic_em: '上啊！', soothing_call: '安抚呼唤', pack_guard: '群体守护', call_of_wild: '野性呼唤',
    frost_bolt: '寒霜箭', arc_burst: '电弧爆发', chain_lightning: '连锁闪电', dispel_hex: '驱散诅咒', rally_banner: '集结旗', brace: '稳住',
    tribute: '贡金', hold_colors: '高举战旗', e_slash: '斩击', e_crush: '碾压', e_volley: '齐射', e_hex: '诅咒', e_mend: '修补',
    e_roar: '咆哮', e_charge: '冲锋', e_shell: '缩壳', e_stun_all: '冲击波'
  }, '.name');
  put('passive.', {
    steadfast: '坚定', sentinel: '哨兵', iron_hide: '铁皮', keen_edge: '锋刃', flowing_step: '流水步', giant_slayer: '巨人杀手',
    armor_breaker: '破甲者', tidebreaker: '破潮', momentum: '势头', steady_aim: '稳定瞄准', eagle_eye: '鹰眼', quick_reload: '快速装填',
    thick_skin: '厚皮', shatter: '粉碎', iron_grip: '铁腕', bedside_manner: '体贴照护', precise_hands: '妙手', life_ward: '生命守护',
    thrifty_kitchen: '节俭厨房', ration_master: '口粮大师', comfort_food: '暖心料理', weather_eye: '观天眼', trailblazer: '开拓者',
    foresight: '先见', handy: '巧手', reinforced_plating: '强化装甲', hidden_blades: '暗刃', beast_bond: '兽之羁绊',
    alpha_bond: '头领羁绊', wild_heart: '野性之心', attunement: '共鸣', static_field: '静电场', warding: '守护结界',
    ledger_keeper: '账簿管家', deep_pockets: '大口袋', inspiring_presence: '鼓舞人心'
  }, '.name');

  // --------------------------------------------------------- crew identity
  put('origin.', {
    dawnwater_fishers: '晨水渔民', ember_forges: '余烬锻造氏族', verdant_villages: '翠绿村落', glass_reefs: '琉璃礁潜水者',
    crown_courts: '王冠宫廷世家', storm_harbors: '风暴港水手', moon_isles: '月岛梦者', trench_divers: '海沟打捞者',
    ring_nomads: '环礁游民', horizon_wanderers: '地平线浪人'
  });
  put('trait.', { brave: '勇敢', cautious: '谨慎', cheerful: '开朗', stubborn: '固执', curious: '好奇', loyal: '忠诚', thrifty: '节俭', calm: '冷静', reckless: '鲁莽', kind: '善良', proud: '骄傲', sleepy: '贪睡' });
  put('apt.', { quick_learner: '学得快', devoted: '专心', deckhand: '甲板好手', brawny: '强壮', sharp: '敏锐', nimble: '灵巧', tough: '坚韧', beast_friend: '动物之友' }, '.name');
  pair('event.', {
    homesick: ['思乡', '离开一段时间后，停靠其家乡海域（{origin}）的港口。'],
    proving: ['证明自己', '让其留在编队中赢得战斗（{n}/5）。'],
    feast: ['像样的一餐', '为船员分发口粮（{n}/5）。'],
    collector: ['纪念品', '在任意港口交付一件其家乡海域（{origin}）的特产。']
  }, '.title', '.desc');

  // ------------------------------------------------------------- equipment
  put('wtype.', { blade: '刀剑', shield: '盾牌', spear: '长枪', gun: '火枪', fist: '指虎', kit: '医疗包', ladle: '汤勺', staff: '法杖', tool: '工具', whip: '鞭子', banner: '战旗' });
  put('otype.', { coat: '外套', armor: '护甲' });
  put('itemtier.', { 1: '漂木', 2: '港湾', 3: '余烬', 4: '翠绿', 5: '棱光', 6: '王冠', 7: '风暴', 8: '月光', 9: '深渊', 10: '地平线' });
  put('affix.', { sturdy: '坚固的', keen: '锋利的', swift: '迅捷的', warded: '护佑的', mighty: '强力的' }, '.name');
  put('item.', {
    a_lucky_shell: '幸运贝壳', a_ember_charm: '余烬护符', a_vine_band: '藤蔓手环', a_prism_lens: '棱镜', a_crown_seal: '王冠印章',
    a_storm_anchor: '风暴之锚', a_moon_lantern: '月光灯笼', a_abyss_ring: '深渊戒指', a_scale_talisman: '鳞片护身符', a_horizon_compass: '地平线罗盘',
    a_escape_rope: '逃生绳', a_work_gloves: '工作手套',
    u_gullfeather_saber: '鸥羽军刀', u_mira_spyglass: '米拉的望远镜', u_cinder_maul: '余烬战锤', u_flint_heartstone: '弗林特的心石',
    u_fernwhip: '蕨鞭', u_rook_mask: '鲁克的面具', u_prism_rifle: '棱光步枪', u_selene_mirror: '瑟琳的镜子', u_crest_rapier: '纹章细剑',
    u_cassian_signet: '卡西安的印戒', u_gale_harpoon: '疾风鱼叉', u_nessa_stormcloak: '内莎的风暴斗篷', u_lantern_staff: '灯笼法杖',
    u_orin_charm: '奥林的护符', u_abyss_cleaver: '深渊砍刀', u_vale_ring: '维尔的戒指', u_leviathan_tooth: '利维坦之牙',
    u_brakka_shell: '布拉卡的甲壳', u_dawnbreaker: '破晓', u_aurelia_crown: '奥蕾莉亚的王冠', u_storm_crown: '风暴王冠',
    u_moonveil: '月纱', u_trench_seal: '海沟封印', u_ringbreaker: '破环者', u_horizon_star: '地平线之星'
  }, '.name');

  // ------------------------------------------------------------------ goods
  put('spec.', {
    saltleaf_grain: '盐叶谷', ember_ore: '余烬矿石', verdant_resin: '翠绿树脂', prism_quartz: '棱光石英', crown_silk: '王冠丝绸',
    stormwood: '风暴木', moon_ink: '月墨', abyss_alloy: '深渊合金', leviathan_scale: '利维坦鳞片', horizon_glass: '地平线玻璃'
  }, '.name');
  put('ing.', { fire_pepper: '火椒', sea_pearl: '海珍珠', kelp_sprig: '海带芽', sun_honey: '太阳蜜', dusk_ink: '暮色墨', salt_crystal: '盐晶' }, '.name');

  // ------------------------------------------------------------------- pets
  put('petfam.', {
    tidefin: '潮鳍', cinderback: '烬背', mossling: '苔仔', glasswing: '琉璃翼', pearlcub: '珍珠幼兽',
    cloudray: '云鳐', dreammoth: '梦蛾', gloomjaw: '幽颚', shellwarden: '甲壳守卫', starwake: '星痕'
  }, '.name');
  put('petform.', { companion: '斗士', helper: '护理者', explorer: '斥候', companion_evo: '冠军', helper_evo: '守护者', explorer_evo: '寻路者' });
  pair('petrole.', {
    companion: ['伙伴', '在战斗中陪伴一名船员作战。'],
    helper: ['船上帮手', '在船上设施工作，提升设施效果。'],
    explorer: ['探索者', '侦察新地点，寻找秘境。']
  }, '', '.desc');
  put('petability.', { splash: '水花', burn: '余烬吐息', mend: '修复', mark: '聚光', shell: '甲壳守护', gust: '疾风', lull: '摇篮曲', maul: '撕咬', ward: '守护', radiance: '光辉' });

  // ------------------------------------------------------------- the world
  const REGIONS = {
    dawnwater: ['晨水浅滩', '温暖平静的海域，新船长在这里学习航海。', '海鸥的赌约', [
      '海鸥劫掠者占领了鸥岩。把他们赶走，港口才会认真对待你。',
      '你获胜的消息传到了盐沼码头。驶往那里，去见码头管理者。',
      '旧瞭望台下的盐水地窖里有东西在蠢动。清理地窖。',
      '明港在劫掠之后需要盐叶谷来补充存粮。把它带回来。',
      '米拉·鸥船长在试炼环等你。赢下她的赌约，下一片海域就会开放。']],
    emberreach: ['余烬海', '布满熔炉与烟雾的火山群岛，甲板会着火。', '龙骨下的火焰', [
      '小恶魔成群占据了玄武岛。清理这座岛，让熔炉重新呼吸。',
      '落灰港陷入了沉寂。驶往那里查明原因。',
      '熔炉深处涌出了大量魔像。清理那里。',
      '烬港需要余烬矿石来重新点燃它的大熔炉。',
      '弗林特·烬船长坐镇熔炉竞技场。在船长试炼中击败他。']],
    verdant_maw: ['翠绿之口', '充满孢子与根须的丛林之海，会让粗心的人精疲力竭。', '扎根的神殿', [
      '藤蔓潜伏者占据了缠木岛。开出一条路。',
      '蕨水驿站发来求救。回应他们。',
      '根须正在堵塞荆根洞窟。把它们砍掉。',
      '根港需要翠绿树脂来密封船体。',
      '鲁克·蕨船长在翠绿竞技场等你。证明你自己。']],
    glass_current: ['琉璃洋流', '会让人目眩、暗藏诱饵的水晶礁。', '魔镜，魔镜', [
      '碎晶剑客守卫着透镜岛。清理他们。',
      '镜湾的灯光暗了下来。前往港口看看。',
      '折射迷宫扭曲光线与感知。清理它。',
      '棱光港的灯塔需要棱光石英。',
      '瑟琳·棱光船长在棱光宫廷等候。打破她的幻象。']],
    crown_shoals: ['王冠浅滩', '由古老世家及其混编随从统治的富饶浅滩。', '失落的特许状', [
      '扒手横行于苍鹭岛。把他们赶出去。',
      '丝绸市场的行会想和你谈谈。去拜访他们。',
      '古老的家族墓穴里藏着被盗的特许状。清理墓穴。',
      '王冠港的特许状仪式需要王冠丝绸。',
      '卡西安·纹章船长在王冠比武场向你挑战。']],
    stormbelt: ['风暴带', '风暴永不停歇的海带，闪电会找上每一根桅杆。', '风暴之眼', [
      '疾风奔袭者在疾风岛劫掠。清理那里。',
      '信标驿失去了灯光。驶往那里。',
      '暴风洞窟中狂风怒吼。清理洞窟。',
      '疾风港需要风暴木来重建码头。',
      '内莎·疾风船长在风暴之眼等你。']],
    moonwake: ['月痕海', '梦境漂浮的银色海域，敌人会预告他们的攻击。', '梦之舞台', [
      '夜行者在回声环礁出没。清理那里。',
      '暮色泊地的水手们都睡着了。去看看他们。',
      '梦境迷宫每走一步都会变化。清理它。',
      '灯港需要月墨来重绘海图。',
      '奥林·灯笼船长占据着月痕舞台。把他从梦中唤醒。']],
    ashen_trench: ['灰烬海沟', '压得人喘不过气的深渊，海底的封印遗迹会封住技能。', '封印守护之物', [
      '遗物窃贼在沉没尖塔翻找。清理他们。',
      '遗物码头的潜水员带来了消息。去码头看看。',
      '海沟圣所里藏着封印守护之物。清理圣所。',
      '灰港需要深渊合金来加固封印。',
      '维尔·灰船长在灰烬封印等你。突破过去。']],
    leviathan_ring: ['利维坦之环', '环绕着沉睡巨兽的礁环；敌人会一波波袭来。', '巨兽体内', [
      '环礁掠夺者在骨礁筑巢。清理他们。',
      '迁徙驿站一直在追踪巨兽。前往那里。',
      '珊瑚巨像苏醒了。清理它。',
      '环堡需要利维坦鳞片来修筑海堤。',
      '布拉卡·礁船长在环礁竞技场等你。']],
    grand_horizon: ['大地平线', '最后的海域，只有精英船队才能生存。', '最强的船长', [
      '关门决斗者守卫着天顶岛。击败他们。',
      '议会港向你发出邀请。回应召唤。',
      '罗盘宝库藏着通往最终试炼的道路。清理它。',
      '地平线之门需要地平线玻璃来点亮最后的信标。',
      '卫冕冠军奥蕾莉亚·晨船长在地平线竞技场等你。']]
  };
  for (const [id, [name, desc, title, lines]] of Object.entries(REGIONS)) {
    S['region.' + id + '.name'] = name; S['region.' + id + '.desc'] = desc; S['arc.' + id + '.title'] = title;
    lines.forEach((l, i) => { S['arc.' + id + '.' + i] = l; });
  }
  put('mechanic.', {
    burning: '燃烧甲板', disruptor: '干扰者', decoys: '诱饵', mixed: '混编随从', intent: '攻击预告',
    sealed: '技能封印', waves: '波次进攻', elite: '精英敌人'
  }, '.name');
  put('hazard.', { heat: '酷热', poison: '孢子', glare: '强光', storm: '雷暴', dream: '梦雾', pressure: '水压', tide: '激流' }, '.name');
  // Pet clues quote one real Prime signature; the Pet Lab then lists all three.
  put('clue.pet.', {
    tidefin: '潮鳍笔记：按红、蓝、蓝的顺序喂养，可完美孵化出伙伴。全部特征序列已记录在宠物研究室。',
    cinderback: '烬背笔记：按红、红、黄的顺序喂养，可完美孵化出伙伴。全部特征序列已记录在宠物研究室。',
    mossling: '苔仔笔记：按绿、绿、蓝的顺序喂养，可完美孵化出船上帮手。全部特征序列已记录在宠物研究室。',
    glasswing: '琉璃翼笔记：按蓝、蓝、黄的顺序喂养，可完美孵化出船上帮手。全部特征序列已记录在宠物研究室。',
    pearlcub: '珍珠幼兽笔记：按白、白、绿的顺序喂养，可完美孵化出探索者。全部特征序列已记录在宠物研究室。',
    cloudray: '云鳐笔记：按黄、蓝、黄的顺序喂养，可完美孵化出伙伴。全部特征序列已记录在宠物研究室。',
    dreammoth: '梦蛾笔记：按紫、紫、黄的顺序喂养，可完美孵化出探索者。全部特征序列已记录在宠物研究室。',
    gloomjaw: '幽颚笔记：按红、紫、红的顺序喂养，可完美孵化出伙伴。全部特征序列已记录在宠物研究室。',
    shellwarden: '甲壳守卫笔记：按绿、蓝、绿的顺序喂养，可完美孵化出船上帮手。全部特征序列已记录在宠物研究室。',
    starwake: '星痕笔记：按白、黄、紫的顺序喂养，可完美孵化出探索者。全部特征序列已记录在宠物研究室。'
  });
  put('room.', {
    landing: '登陆点', grove: '树林', ridge: '山脊', heart: '岛屿中心', hollow: '隐藏秘洞', gate: '大门', west: '西厅', east: '东厅',
    depths: '深处', guardian: '守护者之间', vault: '秘密宝库', hold: '货舱', cabin: '船长舱', sanctum: '圣所', trial: '试炼环'
  }, '.name');
  put('loc.', {
    brightquay: '明港', saltmarsh_landing: '盐沼码头', gull_rock: '鸥岩', lantern_isle: '灯笼岛', coral_steps: '珊瑚阶',
    old_lookout: '旧瞭望台', brine_cellars: '盐水地窖', driftplank_wreck: '漂板沉船', dawn_trial_ring: '晨光试炼环', tidefin_grotto: '潮鳍洞穴',
    cinderport: '烬港', ashfall_harbor: '落灰港', basalt_isle: '玄武岛', smolder_key: '闷烧礁', obsidian_atoll: '黑曜环礁',
    magma_vents: '岩浆喷口', forge_depths: '熔炉深处', scorched_galleon: '焦黑大帆船', ember_crucible: '熔炉竞技场', cinderback_nest: '烬背巢穴',
    rootharbor: '根港', fernwater_post: '蕨水驿站', tanglewood_isle: '缠木岛', orchid_cay: '兰花礁', maw_shore: '巨口海岸',
    overgrown_shrine: '荒草神殿', thornroot_caves: '荆根洞窟', vine_wreck: '藤缠沉船', verdant_arena: '翠绿竞技场', moss_hollow: '苔藓秘洞',
    prismhaven: '棱光港', mirrorbay: '镜湾', shard_reef: '碎晶礁', lens_isle: '透镜岛', quartz_spire: '石英尖塔',
    crystal_vault: '水晶宝库', refraction_maze: '折射迷宫', glassbound_hulk: '琉璃困船', prism_court: '棱光宫廷', glasswing_lagoon: '琉璃翼潟湖',
    crownport: '王冠港', silkmarket: '丝绸市场', gilded_cay: '镀金礁', heron_isle: '苍鹭岛', regent_bank: '摄政沙洲',
    charter_archive: '特许状档案馆', old_family_crypt: '古老家族墓穴', treasury_wreck: '宝库沉船', crown_tourney: '王冠比武场', pearl_grotto: '珍珠洞穴',
    gale_harbor: '疾风港', beacon_rest: '信标驿', thunder_rock: '雷鸣岩', squall_isle: '疾风岛', lightning_reach: '闪电海角',
    drowned_beacon: '沉没信标', tempest_caverns: '暴风洞窟', stormwrack_hulk: '风暴残骸', eye_of_storm: '风暴之眼', cloudray_aerie: '云鳐高巢',
    lanternport: '灯港', dusk_mooring: '暮色泊地', nightbloom_isle: '夜花岛', echo_atoll: '回声环礁', starfall_key: '星落礁',
    forgotten_observatory: '遗忘天文台', dream_labyrinth: '梦境迷宫', moonlit_wreck: '月光沉船', moonwake_stage: '月痕舞台', dreammoth_glade: '梦蛾林间',
    ashport: '灰港', relic_dock: '遗物码头', cinder_shelf: '余烬岩架', sunken_spires: '沉没尖塔', abyss_ledge: '深渊岩台',
    sealed_ruins: '封印遗迹', trench_sanctum: '海沟圣所', relic_hunter_wreck: '寻宝者沉船', ashen_seal_arena: '灰烬封印竞技场', gloomjaw_den: '幽颚巢穴',
    ringhold: '环堡', migration_post: '迁徙驿站', shell_isle: '贝壳岛', bone_reef: '骨礁', titan_atoll: '巨人环礁',
    leviathan_gut: '利维坦之腹', coral_colossus: '珊瑚巨像', behemoth_wreck: '巨兽沉船', ring_arena: '环礁竞技场', shellwarden_shoal: '甲壳守卫浅滩',
    horizon_gate: '地平线之门', conclave_harbor: '议会港', sunrise_isle: '日出岛', zenith_cay: '天顶岛', dawnstar_reef: '晨星礁',
    ancient_gatehouse: '古代门楼', compass_vault: '罗盘宝库', rival_flagship_wreck: '对手旗舰残骸', horizon_arena: '地平线竞技场', starwake_haven: '星痕港湾'
  }, '.name');
  put('enemy.', {
    gull_raider: '海鸥劫掠者', reef_crab: '礁石蟹', spray_gunner: '浪花枪手', brine_witch: '盐水女巫', kelp_tender: '海带看护',
    lookout_warden: '瞭望台看守', cellar_king: '地窖之王',
    cinder_imp: '余烬小恶魔', magma_golem: '岩浆魔像', ash_slinger: '灰烬投石手', flame_seer: '火焰先知', ember_monk: '余烬僧侣',
    vent_tyrant: '喷口暴君', forge_colossus: '熔炉巨像',
    vine_stalker: '藤蔓潜伏者', bark_brute: '树皮蛮兵', thorn_archer: '荆棘弓手', spore_shaman: '孢子萨满', bloom_nurse: '花朵护士',
    shrine_tyrant: '神殿暴君', root_mother: '根之母',
    shard_fencer: '碎晶剑客', quartz_knight: '石英骑士', prism_sniper: '棱光狙击手', mirror_mage: '镜像法师', lens_cleric: '透镜牧师',
    vault_sentinel: '宝库哨兵', refraction_queen: '折射女王',
    cutpurse: '扒手', crown_enforcer: '王冠执法者', musket_noble: '火枪贵族', court_hexer: '宫廷咒术师', gilded_medic: '镀金医师',
    archive_keeper: '档案看守', family_patriarch: '家族族长',
    squall_runner: '疾风奔袭者', thunder_brute: '雷鸣蛮兵', gale_harpooner: '疾风鱼叉手', storm_witch: '风暴女巫', beacon_keeper: '信标看守',
    drowned_keeper: '溺亡看守', tempest_wyrm: '暴风巨龙',
    night_stalker: '夜行者', dream_ogre: '梦魇食人魔', star_archer: '星辰弓手', moon_oracle: '月之神谕', lull_spirit: '安眠之灵',
    observatory_ghost: '天文台幽灵', labyrinth_dreamer: '迷宫梦者',
    relic_thief: '遗物窃贼', abyss_brute: '深渊蛮兵', trench_gunner: '海沟枪手', ash_hexer: '灰烬咒术师', deep_priest: '深海祭司',
    seal_guardian: '封印守卫', trench_horror: '海沟恐魔',
    ring_raider: '环礁掠夺者', shell_titan: '甲壳巨人', bone_spitter: '吐骨者', tide_shaman: '潮汐萨满', reef_mender: '礁石修补者',
    gut_leviathan: '腹中利维坦', colossus_core: '巨像核心',
    gate_duelist: '关门决斗者', horizon_knight: '地平线骑士', sky_gunner: '天空枪手', dawn_mage: '黎明法师', conclave_medic: '议会医师',
    gate_warden: '大门守卫', compass_guardian: '罗盘守护者',
    pennant_deckhand: '红旗水手', pennant_bosun: '红旗水手长', pennant_gunner: '红旗枪手', pennant_hexer: '红旗咒术师', pennant_surgeon: '红旗军医',
    crystal_decoy: '水晶诱饵',
    mira_gull: '米拉·鸥船长', flint_cinder: '弗林特·烬船长', rook_fern: '鲁克·蕨船长', selene_prism: '瑟琳·棱光船长',
    cassian_crest: '卡西安·纹章船长', nessa_gale: '内莎·疾风船长', orin_lantern: '奥林·灯笼船长', vale_ash: '维尔·灰船长',
    brakka_reef: '布拉卡·礁船长', aurelia_dawn: '奥蕾莉亚·晨船长'
  }, '.name');

  const L = {
    meta: { code: 'zh-CN', nativeName: '简体中文', htmlLang: 'zh-CN', numberLocale: 'zh-CN' },
    names: {
      format: '{family}{given}',
      given: ['安', '宁', '远', '舟', '帆', '岚', '澜', '航', '晴', '星', '辰', '月', '海', '波', '涛', '川', '青', '云', '风', '雨',
        '琳', '瑶', '浩', '然', '朗', '博', '欣', '悦', '思', '睿', '小鱼', '阿潮'],
      family: ['林', '陈', '海', '岳', '江', '许', '沈', '白', '叶', '苏', '韩', '唐', '程', '秦', '顾', '蓝', '梁', '宋', '方', '范', '欧阳', '上官', '司马', '诸葛']
    },
    strings: S
  };
  root.P7S = root.P7S || {};
  root.P7S.LOCALES = root.P7S.LOCALES || {};
  root.P7S.LOCALES['zh-CN'] = L;
  if (typeof module !== 'undefined' && module.exports) module.exports = L;
})(typeof globalThis !== 'undefined' ? globalThis : this);
