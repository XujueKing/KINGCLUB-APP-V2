/// Editorial summaries of brand product pages, reviewed 2026-10-05.
/// Exact expression names only: never infer an expression from a brand name.
/// Copy order: simplified Chinese, English, traditional Chinese, Thai.
/// SKU size, price and stock must always come from the store catalog.
class WineStory {
  const WineStory(this.source, this.introductions);
  final String source;
  final List<String> introductions;
}

const wineStories = <String, WineStory>{
  '轩尼诗VSOP': WineStory(
    'https://www.hennessy.com/en-us/collection/hennessy-vsop',
    [
      '轩尼诗 V.S.O.P 是一款干邑，香气带有甜杏与鲜果气息。香草和柔和橡木风味相互融合，口感顺滑，适合感受细腻的调配层次。',
      'Hennessy V.S.O.P is a cognac with sweet apricot aromas. Vanilla and mellow oak combine in a smooth palate that reflects its carefully blended character.',
      '軒尼詩 V.S.O.P 是一款干邑，香氣帶有甜杏與鮮果氣息。香草和柔和橡木風味相互融合，口感順滑，適合感受細膩的調配層次。',
      'Hennessy V.S.O.P เป็นคอนญักที่มีกลิ่นแอปริคอตหวาน ผสานรสวานิลลาและไม้โอ๊กนุ่มนวล ให้สัมผัสเรียบลื่นและมิติจากการเบลนด์อย่างพิถีพิถัน',
    ],
  ),
  '轩尼诗XO': WineStory('https://www.hennessy.com/en-us/collection/hennessy-xo', [
    '轩尼诗 XO 是一款干邑，风味层次从蜜饯果香延伸至辛香料、巧克力与橡木。酒体饱满，尾韵悠长，适合慢慢感受香气的变化。',
    'Hennessy XO is a full-bodied cognac with layers of candied fruit, spice, chocolate and oak. Its long finish reveals gradually changing aromas.',
    '軒尼詩 XO 是一款干邑，風味層次從蜜餞果香延伸至辛香料、巧克力與橡木。酒體飽滿，尾韻悠長，適合慢慢感受香氣的變化。',
    'Hennessy XO เป็นคอนญักรสเข้มข้น มีมิติของผลไม้เชื่อม เครื่องเทศ ช็อกโกแลต และไม้โอ๊ก พร้อมรสสัมผัสที่คงอยู่ยาวนาน',
  ]),
  '芝华士12年': WineStory('https://www.chivas.com/en/collection/chivas-12/', [
    '芝华士 12 年是一款苏格兰调和威士忌，以果园水果、蜂蜜与石南花香为特色。口感圆润，呈现温和甜香与多层次风味。',
    'Chivas 12 is a blended Scotch whisky with orchard fruit, honey and heather aromas. Its rounded palate brings gentle sweetness and layered flavours.',
    '芝華士 12 年是一款蘇格蘭調和威士忌，以果園水果、蜂蜜與石南花香為特色。口感圓潤，呈現溫和甜香與多層次風味。',
    'Chivas 12 เป็นสกอตช์วิสกี้แบบเบลนด์ มีกลิ่นผลไม้จากสวน น้ำผึ้ง และดอกเฮเทอร์ รสสัมผัสกลมกล่อมพร้อมความหวานนุ่มนวล',
  ]),
  '瑞典绝对伏特加': WineStory('https://www.absolut.com/en/products/absolut-vodka/', [
    'Absolut 原味伏特加在瑞典奥胡斯酿造及装瓶，以冬小麦和当地水源为原料。风味带有谷物与干果气息，口感圆润，也常用作鸡尾酒基酒。',
    'Absolut Original is made and bottled in Åhus, Sweden, using winter wheat and local water. Grain and dried-fruit notes give this vodka a rounded character and versatility in cocktails.',
    'Absolut 原味伏特加在瑞典奧胡斯釀造及裝瓶，以冬小麥和當地水源為原料。風味帶有穀物與乾果氣息，口感圓潤，也常用作雞尾酒基酒。',
    'Absolut Original ผลิตและบรรจุที่เมืองโอฮุส ประเทศสวีเดน จากข้าวสาลีฤดูหนาวและน้ำในท้องถิ่น มีกลิ่นธัญพืชและผลไม้แห้ง รสกลมกล่อม เหมาะเป็นส่วนผสมค็อกเทล',
  ]),
  '奔富 BIN407': WineStory(
    'https://www.penfolds.com/en/wines/featured/bin-407-collection',
    [
      '奔富 Bin 407 是澳大利亚赤霞珠干红葡萄酒，采用多产区葡萄酿造。成熟果香与橡木风味相互融合，结构鲜明；不同年份的表现各有特点。',
      'Penfolds Bin 407 is an Australian Cabernet Sauvignon sourced across regions. Ripe fruit and oak shape its structured character; the expression varies with each vintage.',
      '奔富 Bin 407 是澳洲赤霞珠干紅葡萄酒，採用多產區葡萄釀造。成熟果香與橡木風味相互融合，結構鮮明；不同年份的表現各有特點。',
      'Penfolds Bin 407 เป็นไวน์แดง Cabernet Sauvignon จากหลายแหล่งปลูกในออสเตรเลีย ผสานกลิ่นผลไม้สุกและไม้โอ๊ก มีโครงสร้างชัดเจน โดยแต่ละปีผลิตมีเอกลักษณ์ต่างกัน',
    ],
  ),
  '巴黎之花特级干型香槟': WineStory(
    'https://www.perrier-jouet.com/fr-fr/nos-champagnes/grand-brut',
    [
      '巴黎之花 Grand Brut 展现花香、鲜果与布里欧修面包的气息。口感清新而圆润，香草般的细腻风味与气泡交织，是品牌经典的干型香槟。',
      'Perrier-Jouët Grand Brut combines floral and fresh-fruit aromas with brioche and vanilla notes. This classic brut champagne balances freshness with a rounded palate.',
      '巴黎之花 Grand Brut 展現花香、鮮果與布里歐修麵包的氣息。口感清新而圓潤，香草般的細膩風味與氣泡交織，是品牌經典的干型香檳。',
      'Perrier-Jouët Grand Brut มีกลิ่นดอกไม้ ผลไม้สด ขนมปังบริยอช และวานิลลา เป็นแชมเปญบรูต์ที่ผสานความสดชื่นกับรสสัมผัสกลมกล่อม',
    ],
  ),
  '獭祭39': WineStory('https://dassai.com/us/product/main/39.html', [
    '獭祭 39 是以山田锦米酿造的纯米大吟酿，精米步合为 39%，并非酒精度。风味带有丰润果香与细腻甜感，尾韵明亮悠长。',
    'Dassai 39 is a junmai daiginjo sake made with Yamada Nishiki rice polished to 39% of its original size, not 39% alcohol. It offers juicy fruit, delicate sweetness and a bright, lasting finish.',
    '獺祭 39 是以山田錦米釀造的純米大吟釀，精米步合為 39%，並非酒精度。風味帶有豐潤果香與細膩甜感，尾韻明亮悠長。',
    'Dassai 39 เป็นสาเกจุนไมไดกินโจจากข้าวยามาดะนิชิกิที่ขัดเหลือ 39% ของขนาดเดิม ไม่ใช่แอลกอฮอล์ 39% ให้กลิ่นผลไม้ ความหวานละเอียด และรสปลายสดใสยาวนาน',
  ]),
  '百富12年双桶': WineStory(
    'https://shop.us.thebalvenie.com/products/the-balvenie-doublewood-12',
    [
      '百富 DoubleWood 12 年先在美国橡木桶中熟成，再转入欧洲橡木雪莉桶。两种木桶赋予这款单一麦芽威士忌香草、蜂蜜、果香与温暖辛香。',
      'Balvenie DoubleWood 12 matures in American oak before finishing in European oak sherry casks. The two woods bring vanilla, honey, fruit and warm spice to this single malt.',
      '百富 DoubleWood 12 年先在美國橡木桶中熟成，再轉入歐洲橡木雪莉桶。兩種木桶賦予這款單一麥芽威士忌香草、蜂蜜、果香與溫暖辛香。',
      'Balvenie DoubleWood 12 บ่มในถังอเมริกันโอ๊กก่อนบ่มต่อในถังเชอร์รีจากไม้ยูโรเปียนโอ๊ก ทำให้ซิงเกิลมอลต์นี้มีกลิ่นวานิลลา น้ำผึ้ง ผลไม้ และเครื่องเทศอุ่น ๆ',
    ],
  ),
  '酩悦皇室香槟': WineStory('https://www.moet.com/en-gb/foodpairing/moet-imperial', [
    '酩悦 Impérial 由黑皮诺、莫尼耶与霞多丽葡萄调配而成。青苹果、柑橘与白花香气中伴有面包气息，细腻气泡带来鲜活口感。',
    'Moët Impérial blends Pinot Noir, Meunier and Chardonnay. Green apple, citrus and white flowers meet brioche notes, with delicate bubbles and a lively palate.',
    '酩悅 Impérial 由黑皮諾、莫尼耶與霞多麗葡萄調配而成。青蘋果、柑橘與白花香氣中伴有麵包氣息，細膩氣泡帶來鮮活口感。',
    'Moët Impérial ผสมองุ่น Pinot Noir, Meunier และ Chardonnay ให้กลิ่นแอปเปิลเขียว ซิตรัส ดอกไม้ขาว และบริยอช พร้อมฟองละเอียดและรสสดชื่น',
  ]),
  '麦卡伦12年双雪莉桶': WineStory(
    'https://www.themacallan.com/en/single-malt-scotch-whisky/double-cask-12-years-old',
    [
      '麦卡伦 Double Cask 12 年采用经雪莉酒润养的美国与欧洲橡木桶熟成。风味融合太妃糖、香草、蜜饯柑橘和柔和辛香，呈现圆润的单一麦芽风格。',
      'Macallan Double Cask 12 matures in sherry-seasoned American and European oak. Toffee, vanilla, candied citrus and gentle spice create a rounded single malt character.',
      '麥卡倫 Double Cask 12 年採用經雪莉酒潤養的美國與歐洲橡木桶熟成。風味融合太妃糖、香草、蜜餞柑橘和柔和辛香，呈現圓潤的單一麥芽風格。',
      'Macallan Double Cask 12 บ่มในถังอเมริกันและยูโรเปียนโอ๊กที่ผ่านการปรุงด้วยเชอร์รี ผสานรสทอฟฟี วานิลลา ซิตรัสเชื่อม และเครื่องเทศอ่อน ๆ เป็นซิงเกิลมอลต์ที่กลมกล่อม',
    ],
  ),
  '麦卡伦 LITHA': WineStory(
    'https://www.themacallan.com/en-us/single-malt-scotch-whisky/discover-the-macallan-litha',
    [
      '麦卡伦 Litha 是一款单一麦芽威士忌，使用来自西班牙赫雷斯的初次装填雪莉橡木桶熟成。热带水果、巧克力与甜橡木构成其浓郁风味。',
      'Macallan Litha is a single malt matured in first-fill sherry-seasoned oak casks from Jerez, Spain. Tropical fruit, chocolate and sweet oak define its rich character.',
      '麥卡倫 Litha 是一款單一麥芽威士忌，使用來自西班牙赫雷斯的初次裝填雪莉橡木桶熟成。熱帶水果、巧克力與甜橡木構成其濃郁風味。',
      'Macallan Litha เป็นซิงเกิลมอลต์ที่บ่มในถังโอ๊กเชอร์รีแบบเติมครั้งแรกจากเมืองเฆเรซ ประเทศสเปน โดดเด่นด้วยผลไม้เขตร้อน ช็อกโกแลต และกลิ่นไม้โอ๊กหวาน',
    ],
  ),
  '黑桃A黄金香槟': WineStory('https://armanddebrignac.com/products/brut-gold/', [
    '黑桃 A Brut Gold 以三个年份的酒液调配，兼具鲜活果香与层次。桃、杏、柑橘花香与布里欧修面包气息交织，口感饱满而清新。',
    'Armand de Brignac Brut Gold blends three vintages. Peach, apricot and citrus blossom meet brioche notes, balancing a rich palate with freshness.',
    '黑桃 A Brut Gold 以三個年份的酒液調配，兼具鮮活果香與層次。桃、杏、柑橘花香與布里歐修麵包氣息交織，口感飽滿而清新。',
    'Armand de Brignac Brut Gold ผสมไวน์จากสามปีผลิต มีกลิ่นพีช แอปริคอต ดอกซิตรัส และบริยอช ให้รสเต็มอิ่มที่สมดุลกับความสดชื่น',
  ]),
  '1664白啤': WineStory(
    'https://www.1664blanc.com/en-ca/product-range/1664-blanc/',
    [
      '1664 Blanc 是一款小麦啤酒，柑橘清香与芫荽香料气息构成鲜明特色。口感轻盈清爽，带有柔和的果香。',
      '1664 Blanc is a wheat beer with citrus and coriander notes. Its light, refreshing character is complemented by gentle fruit aromas.',
      '1664 Blanc 是一款小麥啤酒，柑橘清香與芫荽香料氣息構成鮮明特色。口感輕盈清爽，帶有柔和的果香。',
      '1664 Blanc เป็นเบียร์ข้าวสาลีที่มีกลิ่นซิตรัสและเมล็ดผักชี ให้รสเบา สดชื่น พร้อมกลิ่นผลไม้นุ่มนวล',
    ],
  ),
  '1664桃红啤酒': WineStory(
    'https://www.1664blanc.com/en-ca/product-range/1664-blanc-rose/',
    [
      '1664 Blanc Rosé 在小麦啤酒风格中融入红色莓果风味。果香柔和，口感清新轻盈，带来不同于经典白啤的莓果气息。',
      '1664 Blanc Rosé brings red-berry flavour to a wheat beer. Soft fruit aromas and a light, refreshing palate distinguish it from the classic Blanc.',
      '1664 Blanc Rosé 在小麥啤酒風格中融入紅色莓果風味。果香柔和，口感清新輕盈，帶來不同於經典白啤的莓果氣息。',
      '1664 Blanc Rosé เป็นเบียร์ข้าวสาลีที่ผสานรสเบอร์รีแดง มีกลิ่นผลไม้อ่อน ๆ และรสเบาสดชื่น แตกต่างจาก Blanc สูตรคลาสสิก',
    ],
  ),
  '喜力啤酒': WineStory(
    'https://www.heineken.com/us/en/our-beers/heineken-original?qr=1',
    [
      '喜力 Original 是经典拉格啤酒，风味带有细微果香。口感清爽利落，标志性的绿色包装是品牌广为人知的形象。',
      'Heineken Original is a classic lager with subtle fruity notes and a crisp finish, recognised by its signature green packaging.',
      '喜力 Original 是經典拉格啤酒，風味帶有細微果香。口感清爽俐落，標誌性的綠色包裝是品牌廣為人知的形象。',
      'Heineken Original เป็นลาเกอร์คลาสสิกที่มีกลิ่นผลไม้อ่อน ๆ และรสปลายสดชื่น โดดเด่นด้วยบรรจุภัณฑ์สีเขียวอันเป็นเอกลักษณ์',
    ],
  ),
  '孟买蓝宝石金酒': WineStory(
    'https://www.bombaysapphire.com/us/en/products/bombay-sapphire/',
    [
      '孟买蓝宝石金酒采用十种植物原料，以蒸汽萃香工艺提取香气。杜松子与柑橘风味相互衬托，适合搭配汤力水或用于经典金酒鸡尾酒。',
      'Bombay Sapphire uses ten botanicals and vapour infusion. Juniper and citrus shape its aromatic profile, suited to tonic water and classic gin cocktails.',
      '孟買藍寶石琴酒採用十種植物原料，以蒸汽萃香工藝提取香氣。杜松子與柑橘風味相互襯托，適合搭配通寧水或用於經典琴酒雞尾酒。',
      'Bombay Sapphire ใช้พืชพรรณสิบชนิดและกระบวนการสกัดกลิ่นด้วยไอ มีเอกลักษณ์ของจูนิเปอร์และซิตรัส เหมาะผสมโทนิกหรือค็อกเทลจินคลาสสิก',
    ],
  ),
  '尊尼获加红方': WineStory(
    'https://www.johnniewalker.com/en-us/our-whisky/core-range/johnnie-walker-red-label',
    [
      '尊尼获加 Red Label 是苏格兰调和威士忌，以鲜明的辛香与烟熏风味为特色。个性清晰，常用于搭配汽水或调制威士忌长饮。',
      'Johnnie Walker Red Label is a blended Scotch whisky with distinctive spice and smoke. Its bold character works well in mixed drinks and whisky highballs.',
      '尊尼獲加 Red Label 是蘇格蘭調和威士忌，以鮮明的辛香與煙燻風味為特色。個性清晰，常用於搭配汽水或調製威士忌長飲。',
      'Johnnie Walker Red Label เป็นสกอตช์วิสกี้แบบเบลนด์ มีเอกลักษณ์ของเครื่องเทศและควัน รสชัดเจน เหมาะสำหรับเครื่องดื่มผสมและวิสกี้ไฮบอล',
    ],
  ),
  '罗斯福10号啤酒': WineStory(
    'https://www.trappistes-rochefort.com/en/beer/rochefort-10/',
    [
      'Rochefort 10 是深棕色的特拉普啤酒，泡沫呈米色。风味浓郁，包含咖啡、巧克力与香料气息；名称中的 10 并非酒精度。',
      'Rochefort 10 is a deep-brown Trappist beer with a beige head. Its rich profile includes coffee, chocolate and spice; the number 10 is not its alcohol percentage.',
      'Rochefort 10 是深棕色的特拉普啤酒，泡沫呈米色。風味濃郁，包含咖啡、巧克力與香料氣息；名稱中的 10 並非酒精度。',
      'Rochefort 10 เป็นเบียร์แทรปปิสต์สีน้ำตาลเข้มพร้อมฟองสีเบจ มีรสเข้มข้นของกาแฟ ช็อกโกแลต และเครื่องเทศ โดยเลข 10 ไม่ใช่เปอร์เซ็นต์แอลกอฮอล์',
    ],
  ),
  '野格利口酒': WineStory('https://www.jagermeister.com/products/jagermeister', [
    '野格是一款德国草本利口酒，由 56 种草本、根茎及香料调配，并经过橡木桶熟成。风味浓郁，草本香气与甜苦层次交织。',
    'Jägermeister is a German herbal liqueur made with 56 herbs, roots and spices and matured in oak. Its intense herbal character combines sweet and bitter layers.',
    '野格是一款德國草本利口酒，由 56 種草本、根莖及香料調配，並經過橡木桶熟成。風味濃郁，草本香氣與甜苦層次交織。',
    'Jägermeister เป็นลิเคียวร์สมุนไพรจากเยอรมนี ใช้สมุนไพร รากไม้ และเครื่องเทศ 56 ชนิด ผ่านการบ่มในถังโอ๊ก ให้กลิ่นสมุนไพรเข้มข้นและรสหวานขมหลายมิติ',
  ]),
  '百加得白朗姆': WineStory('https://www.bacardi.com/our-rums/carta-blanca-rum/', [
    '百加得 Carta Blanca 是一款白朗姆酒，经美国白橡木桶熟成与木炭过滤。带有杏仁、果香与花香，尾韵清爽，是莫吉托等鸡尾酒常用的基酒。',
    'Bacardí Carta Blanca is a white rum matured in American white oak and charcoal filtered. Almond, fruit and floral notes lead to a clean finish, making it a classic Mojito base.',
    '百加得 Carta Blanca 是一款白蘭姆酒，經美國白橡木桶熟成與木炭過濾。帶有杏仁、果香與花香，尾韻清爽，是莫吉托等雞尾酒常用的基酒。',
    'Bacardí Carta Blanca เป็นไวต์รัมที่บ่มในถังอเมริกันไวต์โอ๊กและกรองด้วยถ่าน มีกลิ่นอัลมอนด์ ผลไม้ และดอกไม้ รสปลายสะอาด นิยมใช้เป็นส่วนผสมโมฮิโต',
  ]),
};
