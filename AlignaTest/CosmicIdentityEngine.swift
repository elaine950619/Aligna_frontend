import Foundation

// MARK: - Cosmic Identity Engine
// Generates a unique archetype name + one-line tagline from the three natal placements.
// Sun × Moon → 144 archetype titles (EN and ZH independently crafted, no direct translation)
// Ascendant element → tonal register of the tagline (fire/earth/air/water × 4 styles)
// All logic is local — no API call required.

struct CosmicIdentity {
    let titleEN: String   // e.g. "Starlight Witness"
    let titleZH: String   // e.g. "星渊见证者"
    let taglineEN: String
    let taglineZH: String
}

struct CosmicIdentityEngine {

    // MARK: - Public entry point
    static func generate(sun: String, moon: String, ascendant: String) -> CosmicIdentity {
        let s = sun.lowercased().trimmingCharacters(in: .whitespaces)
        let m = moon.lowercased().trimmingCharacters(in: .whitespaces)
        let a = ascendant.lowercased().trimmingCharacters(in: .whitespaces)

        let (titleEN, titleZH) = archetypeTitle(sun: s, moon: m)
        let (taglineEN, taglineZH) = tagline(sun: s, moon: m, ascendant: a)

        return CosmicIdentity(titleEN: titleEN, titleZH: titleZH,
                              taglineEN: taglineEN, taglineZH: taglineZH)
    }

    // MARK: - Archetype titles (Sun × Moon)

    // EN archetype nouns keyed by sun sign
    private static let enCore: [String: String] = [
        "aries":       "Pioneer",
        "taurus":      "Keeper",
        "gemini":      "Seeker",
        "cancer":      "Tender",
        "leo":         "Sovereign",
        "virgo":       "Alchemist",
        "libra":       "Architect",
        "scorpio":     "Witness",
        "sagittarius": "Oracle",
        "capricorn":   "Sentinel",
        "aquarius":    "Visionary",
        "pisces":      "Dreamer",
    ]

    // EN adjective / nature-quality keyed by moon sign
    private static let enMood: [String: String] = [
        "aries":       "Flame",
        "taurus":      "Stone",
        "gemini":      "Wind",
        "cancer":      "Tide",
        "leo":         "Golden",
        "virgo":       "Silver",
        "libra":       "Mist",
        "scorpio":     "Obsidian",
        "sagittarius": "Ember",
        "capricorn":   "Frost",
        "aquarius":    "Storm",
        "pisces":      "Starlight",
    ]

    // ZH core archetype nouns keyed by sun sign
    private static let zhCore: [String: String] = [
        "aries":       "先行者",
        "taurus":      "守藏者",
        "gemini":      "探寻者",
        "cancer":      "抚育者",
        "leo":         "主权者",
        "virgo":       "炼金者",
        "libra":       "设计者",
        "scorpio":     "见证者",
        "sagittarius": "先知",
        "capricorn":   "守望者",
        "aquarius":    "先觉者",
        "pisces":      "梦境者",
    ]

    // ZH poetic prefix keyed by moon sign (standalone, not translated from EN)
    private static let zhMood: [String: String] = [
        "aries":       "烈焰",
        "taurus":      "磐石",
        "gemini":      "流风",
        "cancer":      "潮汐",
        "leo":         "金耀",
        "virgo":       "霜银",
        "libra":       "晨雾",
        "scorpio":     "星渊",
        "sagittarius": "余烬",
        "capricorn":   "寒霜",
        "aquarius":    "雷云",
        "pisces":      "星光",
    ]

    private static func archetypeTitle(sun: String, moon: String) -> (String, String) {
        let enC = enCore[sun] ?? "Soul"
        let enM = enMood[moon] ?? "Cosmic"
        let zhC = zhCore[sun] ?? "探索者"
        let zhM = zhMood[moon] ?? "星光"
        return ("\(enM) \(enC)", "\(zhM)\(zhC)")
    }

    // MARK: - Taglines (ascendant element shapes the voice register)

    private static func element(of sign: String) -> String {
        switch sign {
        case "aries", "leo", "sagittarius":          return "fire"
        case "taurus", "virgo", "capricorn":         return "earth"
        case "gemini", "libra", "aquarius":          return "air"
        case "cancer", "scorpio", "pisces":          return "water"
        default:                                      return "fire"
        }
    }

    // Full 144-combination tagline table for EN
    // Format: [sunKey: [moonKey: tagline]]
    // Written in four element-toned voices blended at the ascendant layer below.
    private static func taglineEN(sun: String, moon: String) -> String {
        switch (sun, moon) {
        // ── Aries Sun ──
        case ("aries","aries"):       return "You move before the world has finished thinking."
        case ("aries","taurus"):      return "Unstoppable drive, grounded in what truly matters."
        case ("aries","gemini"):      return "You turn sparks into stories and stories into action."
        case ("aries","cancer"):      return "Courage with a heart — you fight for those you love."
        case ("aries","leo"):         return "Born to lead; the room lights up when you enter."
        case ("aries","virgo"):       return "Sharp instincts refined by an exacting inner standard."
        case ("aries","libra"):       return "You charge forward, then pause to make it beautiful."
        case ("aries","scorpio"):     return "Fearless on the surface, ancient in the depths."
        case ("aries","sagittarius"): return "Pure ignition — you set the horizon on fire."
        case ("aries","capricorn"):   return "Raw ambition forged into something that lasts."
        case ("aries","aquarius"):    return "A rebel with a blueprint for a better world."
        case ("aries","pisces"):      return "You act on dreams most people only half-believe."

        // ── Taurus Sun ──
        case ("taurus","aries"):      return "Still waters running toward something undeniable."
        case ("taurus","taurus"):     return "Rooted so deeply the earth itself leans on you."
        case ("taurus","gemini"):     return "You build slowly, but your mind never stops moving."
        case ("taurus","cancer"):     return "You turn a house into a sanctuary, a meal into a memory."
        case ("taurus","leo"):        return "Quietly magnificent — you let your work speak first."
        case ("taurus","virgo"):      return "Patience and precision make you impossible to rush."
        case ("taurus","libra"):      return "You know that beauty is not decoration — it is truth."
        case ("taurus","scorpio"):    return "Immovable on the outside, volcanic underneath."
        case ("taurus","sagittarius"):return "A wanderer who always finds the way home."
        case ("taurus","capricorn"):  return "You build empires one steady stone at a time."
        case ("taurus","aquarius"):   return "Grounded enough to make the radical feel real."
        case ("taurus","pisces"):     return "You sense what others miss and hold it gently."

        // ── Gemini Sun ──
        case ("gemini","aries"):      return "Ideas ignite in you before the question is finished."
        case ("gemini","taurus"):     return "A curious mind that knows when to sit still and listen."
        case ("gemini","gemini"):     return "You speak in layers — every sentence a small universe."
        case ("gemini","cancer"):     return "Words land softer when you are the one speaking them."
        case ("gemini","leo"):        return "Brilliant, magnetic, and impossible to ignore."
        case ("gemini","virgo"):      return "You find the flaw in the argument and the beauty in the detail."
        case ("gemini","libra"):      return "You navigate contradiction with effortless grace."
        case ("gemini","scorpio"):    return "Your questions cut to places others are afraid to look."
        case ("gemini","sagittarius"):return "Every conversation is a journey you were born to take."
        case ("gemini","capricorn"):  return "Restless mind, steady purpose — a rare combination."
        case ("gemini","aquarius"):   return "You map what the future might feel like."
        case ("gemini","pisces"):     return "You translate silence into something everyone can hear."

        // ── Cancer Sun ──
        case ("cancer","aries"):      return "Tender on the inside, fiercer than anyone expects."
        case ("cancer","taurus"):     return "You build belonging wherever you go."
        case ("cancer","gemini"):     return "You make strangers feel remembered."
        case ("cancer","cancer"):     return "The world is held together by people like you."
        case ("cancer","leo"):        return "Warmth that doesn't need to announce itself."
        case ("cancer","virgo"):      return "You see the small wound others walk past without noticing."
        case ("cancer","libra"):      return "You hold the room in balance without anyone realizing."
        case ("cancer","scorpio"):    return "Fierce love, long memory — you forget nothing that matters."
        case ("cancer","sagittarius"):return "Home is wherever your stories are told."
        case ("cancer","capricorn"):  return "You build things meant to outlast you."
        case ("cancer","aquarius"):   return "You love the world enough to want it changed."
        case ("cancer","pisces"):     return "You feel the undercurrent no one else can name."

        // ── Leo Sun ──
        case ("leo","aries"):         return "The spark and the stage — you were made for both."
        case ("leo","taurus"):        return "Radiant without effort, loyal without condition."
        case ("leo","gemini"):        return "You turn every room into a theatre and every story into legend."
        case ("leo","cancer"):        return "Generous to a fault; your warmth is the kind people remember."
        case ("leo","leo"):           return "Unapologetically luminous — the world adjusts to your brightness."
        case ("leo","virgo"):         return "You perform flawlessly because you prepared when no one was watching."
        case ("leo","libra"):         return "Charisma and grace, together, are unstoppable."
        case ("leo","scorpio"):       return "Deep power with the presence to carry it."
        case ("leo","sagittarius"):   return "Born for the grand adventure, the grand gesture."
        case ("leo","capricorn"):     return "You build a legacy and then step into the spotlight it deserves."
        case ("leo","aquarius"):      return "You lead toward a vision others haven't dared to imagine yet."
        case ("leo","pisces"):        return "Your heart is a stage where every feeling gets its moment."

        // ── Virgo Sun ──
        case ("virgo","aries"):       return "You act decisively, then refine until it is right."
        case ("virgo","taurus"):      return "Mastery through patience — you trust the process completely."
        case ("virgo","gemini"):      return "You find the signal hidden inside all the noise."
        case ("virgo","cancer"):      return "You care through precision — every detail is an act of love."
        case ("virgo","leo"):         return "The quiet force behind every brilliant outcome."
        case ("virgo","virgo"):       return "You hold the highest standard because you believe it is possible."
        case ("virgo","libra"):       return "You make the complicated elegant and the elegant right."
        case ("virgo","scorpio"):     return "You see everything — and say only what needs to be said."
        case ("virgo","sagittarius"): return "Grounded curiosity: you seek the truth and then build with it."
        case ("virgo","capricorn"):   return "Discipline and devotion, quietly changing everything."
        case ("virgo","aquarius"):    return "You solve problems others haven't named yet."
        case ("virgo","pisces"):      return "Precise enough to catch what's broken, gentle enough to heal it."

        // ── Libra Sun ──
        case ("libra","aries"):       return "You move fast but always toward something fair."
        case ("libra","taurus"):      return "Your sense of beauty is a form of deep intelligence."
        case ("libra","gemini"):      return "You hold both sides of an argument and find the poetry between them."
        case ("libra","cancer"):      return "Connection is your gift; harmony is your art."
        case ("libra","leo"):         return "Charming without trying, commanding without force."
        case ("libra","virgo"):       return "You weigh everything until the balance is exact."
        case ("libra","libra"):       return "You see the ideal and refuse to settle for less."
        case ("libra","scorpio"):     return "Graceful on the surface, unflinching beneath."
        case ("libra","sagittarius"): return "You travel toward justice and arrive with stories."
        case ("libra","capricorn"):   return "You build fair systems that outlast the argument."
        case ("libra","aquarius"):    return "You dream of a world where design and equity meet."
        case ("libra","pisces"):      return "You soften the world without losing your own shape."

        // ── Scorpio Sun ──
        case ("scorpio","aries"):     return "The fiercest thing in the room rarely speaks first."
        case ("scorpio","taurus"):    return "You endure what others cannot and emerge changed."
        case ("scorpio","gemini"):    return "Your mind finds the hidden door in every room."
        case ("scorpio","cancer"):    return "You love completely and hold what is entrusted to you."
        case ("scorpio","leo"):       return "Intensity and magnetism — a rare and unmistakable force."
        case ("scorpio","virgo"):     return "You diagnose what is broken and you know how to fix it."
        case ("scorpio","libra"):     return "You see through the polished surface to what is actually true."
        case ("scorpio","scorpio"):   return "Depth calling to depth — you are not afraid of the dark."
        case ("scorpio","sagittarius"):return "You seek the truth even when it costs you something."
        case ("scorpio","capricorn"): return "Patient, powerful, and precise — the long game is yours."
        case ("scorpio","aquarius"):  return "You see the system clearly and know exactly where it breaks."
        case ("scorpio","pisces"):    return "You touch the wound in things and somehow make them whole."

        // ── Sagittarius Sun ──
        case ("sagittarius","aries"): return "Born at full speed toward the next true thing."
        case ("sagittarius","taurus"):return "You seek the wide world but need something real to return to."
        case ("sagittarius","gemini"):return "Every journey is a library you carry with you."
        case ("sagittarius","cancer"):return "You carry home inside you, wherever the road leads."
        case ("sagittarius","leo"):   return "Grand vision, grand presence — you arrive and things begin."
        case ("sagittarius","virgo"): return "You travel with purpose and return with answers."
        case ("sagittarius","libra"): return "The diplomat who tells the truth anyway."
        case ("sagittarius","scorpio"):return "You follow the thread until it leads somewhere real."
        case ("sagittarius","sagittarius"):return "Infinite horizon, endless faith — the world is always beginning."
        case ("sagittarius","capricorn"):return "You dream large and then actually build it."
        case ("sagittarius","aquarius"):return "You carry a vision of how things should be and you mean it."
        case ("sagittarius","pisces"):return "You believe in something larger than yourself, always."

        // ── Capricorn Sun ──
        case ("capricorn","aries"):   return "Ambition with urgency — you make things happen, then make them last."
        case ("capricorn","taurus"):  return "You build slowly because you know what endures."
        case ("capricorn","gemini"):  return "Strategy and wit — you always know the next move."
        case ("capricorn","cancer"):  return "You work for the people who will come after you."
        case ("capricorn","leo"):     return "Quiet authority that earns its place in any room."
        case ("capricorn","virgo"):   return "The standard-bearer — you hold the line so others can rise."
        case ("capricorn","libra"):   return "You create structures that are both right and beautiful."
        case ("capricorn","scorpio"): return "Still as bedrock, deep as a fault line."
        case ("capricorn","sagittarius"):return "Vision and discipline, held in the same steady hand."
        case ("capricorn","capricorn"):return "You carry the future on your back and walk without complaint."
        case ("capricorn","aquarius"):return "You reform the institution from the inside."
        case ("capricorn","pisces"):  return "You turn the dream into a blueprint, then build it stone by stone."

        // ── Aquarius Sun ──
        case ("aquarius","aries"):    return "You disrupt the present so the future has room to breathe."
        case ("aquarius","taurus"):   return "Radical ideas in practical hands — the rarest combination."
        case ("aquarius","gemini"):   return "You think in systems and speak in possibilities."
        case ("aquarius","cancer"):   return "You love humanity enough to fight for the ones you've never met."
        case ("aquarius","leo"):      return "Visionary and magnetic — you make the future feel like now."
        case ("aquarius","virgo"):    return "You see what is wrong and you know how to make it right."
        case ("aquarius","libra"):    return "You imagine fairness and then you build it."
        case ("aquarius","scorpio"):  return "You know what others are not yet ready to know."
        case ("aquarius","sagittarius"):return "You carry the map to a place that doesn't exist yet."
        case ("aquarius","capricorn"):return "You build tomorrow's institutions with yesterday's discipline."
        case ("aquarius","aquarius"): return "The signal from the future — strange, necessary, clear."
        case ("aquarius","pisces"):   return "You dream of a world that has never existed and work toward it anyway."

        // ── Pisces Sun ──
        case ("pisces","aries"):      return "Soft on the outside, relentless underneath."
        case ("pisces","taurus"):     return "You feel everything, but your roots hold."
        case ("pisces","gemini"):     return "You speak the language of the in-between."
        case ("pisces","cancer"):     return "Your empathy is a depth the ocean envies."
        case ("pisces","leo"):        return "You turn feeling into art that outlasts you."
        case ("pisces","virgo"):      return "You tend the invisible wounds with quiet precision."
        case ("pisces","libra"):      return "You find the beauty in everything and name it for others."
        case ("pisces","scorpio"):    return "You have been to the bottom and you know what lives there."
        case ("pisces","sagittarius"):return "You follow the star even when it moves."
        case ("pisces","capricorn"):  return "You build cathedrals for feelings people haven't felt yet."
        case ("pisces","aquarius"):   return "You bleed for a world that hasn't arrived yet."
        case ("pisces","pisces"):     return "You are the ocean remembering that it was once rain."

        default: return "You carry something rare — trust what you feel."
        }
    }

    // Full 144-combination tagline table for ZH
    // Each line is an original Chinese poetic phrase with cosmic register.
    private static func taglineZH(sun: String, moon: String) -> String {
        switch (sun, moon) {
        // ── 白羊太阳 ──
        case ("aries","aries"):       return "星火未落，你已在更远的地方落脚。"
        case ("aries","taurus"):      return "大地托住你的脚，烈焰点燃你的路。"
        case ("aries","gemini"):      return "念头是星尘，你把它们连成了星座。"
        case ("aries","cancer"):      return "你用铁甲护着一颗月亮般柔软的心。"
        case ("aries","leo"):         return "你一踏入，光就跟着改变了方向。"
        case ("aries","virgo"):       return "快如流星，又精准得像被测量过的星轨。"
        case ("aries","libra"):       return "冲破边界，也懂得让破口变得好看。"
        case ("aries","scorpio"):     return "外表是烈火，深处藏着一片星云。"
        case ("aries","sagittarius"): return "你是那种连地平线都追不上的光。"
        case ("aries","capricorn"):   return "热血是原料，你把它锻成了永恒的形状。"
        case ("aries","aquarius"):    return "你打破旧秩序，是因为你看见了更好的星图。"
        case ("aries","pisces"):      return "别人还在问那个梦真不真实，你已抵达梦的彼岸。"

        // ── 金牛太阳 ──
        case ("taurus","aries"):      return "平静之下，是一条谁都无法截断的河流。"
        case ("taurus","taurus"):     return "你是大地本身——万物生长，都需要你的重量。"
        case ("taurus","gemini"):     return "你缓慢而行，思维却比任何星风都快。"
        case ("taurus","cancer"):     return "一盏灯，一顿饭，你把瞬间变成了一生的记忆。"
        case ("taurus","leo"):        return "不需要开口，你的光会让时间来证明。"
        case ("taurus","virgo"):      return "你不急，因为你知道：恒星也需要时间成型。"
        case ("taurus","libra"):      return "对你而言，美不是装饰——它是宇宙诚实的样子。"
        case ("taurus","scorpio"):    return "表面是沉静的石，内心是未熄的星核。"
        case ("taurus","sagittarius"):return "你去过很远的地方，但总知道回家的那颗星在哪里。"
        case ("taurus","capricorn"):  return "一层一层地垒，你在建造某种比山更久的东西。"
        case ("taurus","aquarius"):   return "你把最激进的念头，落进最踏实的土壤里。"
        case ("taurus","pisces"):     return "你感知到那些无声漂浮的东西，并把它们轻轻接住。"

        // ── 双子太阳 ──
        case ("gemini","aries"):      return "话还没说完，你已在另一颗星上落地了。"
        case ("gemini","taurus"):     return "万物皆好奇，但你知道什么时候停下来，听风说话。"
        case ("gemini","gemini"):     return "你说的每句话都是一个星系，每层都有自己的引力。"
        case ("gemini","cancer"):     return "经你口说出的话，会带着月光的温度。"
        case ("gemini","leo"):        return "你走进来，空气里多了一道光的频率。"
        case ("gemini","virgo"):      return "你能找到星图里的误差，也能看见缝隙里的银河。"
        case ("gemini","libra"):      return "你在两极之间穿行，从不失去自己的轨道。"
        case ("gemini","scorpio"):    return "你的问题像一根针，直插别人不敢凝视的星核。"
        case ("gemini","sagittarius"):return "每一次对话，都是你展开的一张新的星图。"
        case ("gemini","capricorn"):  return "流动的星，固定的北极——难得的宇宙之美。"
        case ("gemini","aquarius"):   return "你在素描一种尚未降临的光。"
        case ("gemini","pisces"):     return "你把星际的沉默，译成了人间能听懂的语言。"

        // ── 巨蟹太阳 ──
        case ("cancer","aries"):      return "月光般温柔，但月亮也有引动海潮的力量。"
        case ("cancer","taurus"):     return "你走过的地方，归属感就在那里生根。"
        case ("cancer","gemini"):     return "你有一种让流星记住自己名字的能力。"
        case ("cancer","cancer"):     return "宇宙能维系，是因为有你这样的引力存在。"
        case ("cancer","leo"):        return "那种不需要宣告自己的光，才是最古老的星。"
        case ("cancer","virgo"):      return "你能看见那些被星尘掩埋的细小裂痕。"
        case ("cancer","libra"):      return "你让整片星空保持平衡，没有星知道是你做到的。"
        case ("cancer","scorpio"):    return "你爱得如深海，记得如星历——重要的，一件不落。"
        case ("cancer","sagittarius"):return "家在你心里，无论你把脚踏上哪一颗星。"
        case ("cancer","capricorn"):  return "你建造的，是为了在你离开后，仍然守护某人。"
        case ("cancer","aquarius"):   return "正因为爱这个宇宙，你才想让它变得不同。"
        case ("cancer","pisces"):     return "你感受到那股星际间的暗流，那个没有名字的引力。"

        // ── 狮子太阳 ──
        case ("leo","aries"):         return "光与舞台，宇宙为你同时打开了两扇门。"
        case ("leo","taurus"):        return "不费力气地燃烧，无条件地照耀。"
        case ("leo","gemini"):        return "你把每一个空间变成星剧场，把每个故事变成神话。"
        case ("leo","cancer"):        return "你给予的，让人记住的不是礼物，而是有光的感觉。"
        case ("leo","leo"):           return "你不需要被允许发光——你本来就是那颗恒星。"
        case ("leo","virgo"):         return "台上的耀眼，是因为台下你比任何星都更用力地自转。"
        case ("leo","libra"):         return "魅力与优雅并轨，是一道任何引力都无法阻止的光。"
        case ("leo","scorpio"):       return "深渊里的光，才是最震撼宇宙的存在。"
        case ("leo","sagittarius"):   return "生来就为了那种宏大的星际旅行与宏大的降临。"
        case ("leo","capricorn"):     return "你建造一段传说，然后走进它应得的星光之下。"
        case ("leo","aquarius"):      return "你带领星群走向一个它们还没敢抬头看的方向。"
        case ("leo","pisces"):        return "你的心是一片星云，每种感受都在那里完成它的形状。"

        // ── 处女太阳 ──
        case ("virgo","aries"):       return "先飞向星核，再一点点打磨，直到它发光的角度恰好正确。"
        case ("virgo","taurus"):      return "精通是耐心的另一个名字——你完全信任星体运行的节奏。"
        case ("virgo","gemini"):      return "你在宇宙所有的噪声里，找到那个最真实的频率。"
        case ("virgo","cancer"):      return "你用精准去爱——每一个细节，都是你送出的星光。"
        case ("virgo","leo"):         return "所有璀璨结果背后，那个安静运转的引力是你。"
        case ("virgo","virgo"):       return "你坚守最高的轨道，因为你知道它是存在的。"
        case ("virgo","libra"):       return "你让混沌变成星图，让星图变成可以信任的真相。"
        case ("virgo","scorpio"):     return "你洞察一切——但只在必要时，才让星光透出来。"
        case ("virgo","sagittarius"): return "踏实地寻找真相，然后用它建造一个更准确的宇宙。"
        case ("virgo","capricorn"):   return "自律与专注，是你悄悄改写星轨的方式。"
        case ("virgo","aquarius"):    return "你在解决那些还没有名字的星际问题。"
        case ("virgo","pisces"):      return "精准到足以找到裂缝，温柔到足以用星光将它填满。"

        // ── 天秤太阳 ──
        case ("libra","aries"):       return "你快速划过星空，方向永远朝着公正的那一侧。"
        case ("libra","taurus"):      return "你对美的感知，是一种古老而深沉的宇宙智慧。"
        case ("libra","gemini"):      return "你同时持有两颗星的光，并在它们之间找到诗。"
        case ("libra","cancer"):      return "连结是你的天赋，和谐是你编织的星网。"
        case ("libra","leo"):         return "有引力，却不强迫；有光芒，却不刺眼。"
        case ("libra","virgo"):       return "你衡量每一道星光的角度，直到天平完全静止。"
        case ("libra","libra"):       return "你看见宇宙应有的样子，并温柔地拒绝接受更少。"
        case ("libra","scorpio"):     return "表面是柔和的星光，内里是不会动摇的星核。"
        case ("libra","sagittarius"): return "你奔向公正，怀里装满了沿途收集的星故事。"
        case ("libra","capricorn"):   return "你建造的秩序，让争论本身在星空中失去了回声。"
        case ("libra","aquarius"):    return "你梦想的宇宙里，美与公平是同一颗星的两面。"
        case ("libra","pisces"):      return "你让世界变得柔软，却没有失去自己的星体形状。"

        // ── 天蝎太阳 ──
        case ("scorpio","aries"):     return "星空中最强的引力，往往来自最沉默的那颗星。"
        case ("scorpio","taurus"):    return "你穿越别的星无法承受的压强，以另一种密度出现。"
        case ("scorpio","gemini"):    return "你的意识能找到每个星系里那扇隐藏的暗门。"
        case ("scorpio","cancer"):    return "你全力以赴地爱，并守护被宇宙托付给你的一切。"
        case ("scorpio","leo"):       return "强烈与磁场并存——一种连光都会绕道的存在。"
        case ("scorpio","virgo"):     return "你能读出星体的病历，也知道哪颗星需要怎样的修复。"
        case ("scorpio","libra"):     return "你看穿星光的表面，直抵那个无法伪装的星核。"
        case ("scorpio","scorpio"):   return "深渊呼唤深渊——你是那个不惧黑洞的存在。"
        case ("scorpio","sagittarius"):return "你追寻真相，即使它藏在宇宙最深的暗处。"
        case ("scorpio","capricorn"): return "耐心、引力、精准——这场星际长局，最终属于你。"
        case ("scorpio","aquarius"):  return "你看见这个星系的结构，也看见它在哪颗节点上断裂。"
        case ("scorpio","pisces"):    return "你触碰星体的伤口，然后以某种古老的方式让它重新发光。"

        // ── 射手太阳 ──
        case ("sagittarius","aries"): return "全速朝下一颗真实的星出发，没有回头的轨迹。"
        case ("sagittarius","taurus"):return "你探索整个星空，却需要一颗真实的星来停泊。"
        case ("sagittarius","gemini"):return "每一次星际旅行，都是一座你随身携带的图书馆。"
        case ("sagittarius","cancer"):return "无论轨道通向哪里，你的家一直在你心里发着光。"
        case ("sagittarius","leo"):   return "宏大的星图，宏大的降临——你到，万物就开始运转。"
        case ("sagittarius","virgo"): return "你带着使命出发，带着答案穿越星际归来。"
        case ("sagittarius","libra"): return "那个穿越星系，仍然会说出真相的旅行者。"
        case ("sagittarius","scorpio"):return "你顺着那条最深的线索，直走到它真实的尽头。"
        case ("sagittarius","sagittarius"):return "无限的星空，无尽的相信——宇宙对你而言永远刚刚开始。"
        case ("sagittarius","capricorn"):return "你做宏大的星梦，然后一块一块地把它建在地上。"
        case ("sagittarius","aquarius"):return "你怀揣着星空本该有的样子，并且是认真要去实现的。"
        case ("sagittarius","pisces"):return "你相信某种比自己更古老的宇宙之力，始终如此。"

        // ── 摩羯太阳 ──
        case ("capricorn","aries"):   return "有星火，有紧迫感——你让事情在星空中发生，并让它恒久。"
        case ("capricorn","taurus"):  return "你缓慢地建造，因为你知道哪种结构能撑过亿年。"
        case ("capricorn","gemini"):  return "星图在心，你总是知道下一步落在哪颗星上。"
        case ("capricorn","cancer"):  return "你为那些还在星际旅途中、尚未抵达的人而建造。"
        case ("capricorn","leo"):     return "沉静的星，有时比最亮的一颗更能定义方向。"
        case ("capricorn","virgo"):   return "你守住那条轨道，让其他星得以攀升到更高的轨道。"
        case ("capricorn","libra"):   return "你建造的星体结构，既有正确的引力，又有美丽的曲线。"
        case ("capricorn","scorpio"): return "稳如暗物质，深如时空裂缝——你自己知道有多深。"
        case ("capricorn","sagittarius"):return "星图与纪律，握在同一双走过宇宙的手里。"
        case ("capricorn","capricorn"):return "你把未来的重量扛在身上，不抱怨，继续穿越星空。"
        case ("capricorn","aquarius"):return "你从星系内部重新校准那个旧的运行轨道。"
        case ("capricorn","pisces"):  return "你把星梦变成蓝图，然后一块星石一块星石地建造它。"

        // ── 水瓶太阳 ──
        case ("aquarius","aries"):    return "你打破旧的星轨，是为了给未来的光留出呼吸的空间。"
        case ("aquarius","taurus"):   return "最超前的星图，落在最踏实的手里——宇宙最稀有的礼物。"
        case ("aquarius","gemini"):   return "你用星系的逻辑思考，用尚未命名的可能性说话。"
        case ("aquarius","cancer"):   return "你爱整个宇宙，爱到愿意为从未相遇的星去战斗。"
        case ("aquarius","leo"):      return "先觉者与发光者同体——你让未来感觉像此刻正在发生。"
        case ("aquarius","virgo"):    return "你看见星系的偏差，也知道需要哪个精确的角度来修正。"
        case ("aquarius","libra"):    return "你想象一个更公正的宇宙，然后去建造它的引力系统。"
        case ("aquarius","scorpio"):  return "你知道那些星还没准备好知道的事。"
        case ("aquarius","sagittarius"):return "你携带着一张通往尚不存在的星系的地图。"
        case ("aquarius","capricorn"):return "你用最古老的纪律，建造最未来的星际秩序。"
        case ("aquarius","aquarius"): return "来自未来某颗星的信号——陌生、必要、无可取代。"
        case ("aquarius","pisces"):   return "你梦见一个从未存在的星系，然后仍然朝它的方向飞去。"

        // ── 双鱼太阳 ──
        case ("pisces","aries"):      return "星云般柔软，星核般不知疲倦。"
        case ("pisces","taurus"):     return "你感受整个宇宙，但根扎得够深，不会在星际漂流中迷失。"
        case ("pisces","gemini"):     return "你说的是那种星际之间、形状之间的语言。"
        case ("pisces","cancer"):     return "你的共情，是连深空都会停下来凝视的深度。"
        case ("pisces","leo"):        return "你把感受炼成星光，让它在你之后继续照耀。"
        case ("pisces","virgo"):      return "你以星辰的精准，照料那些肉眼看不见的伤。"
        case ("pisces","libra"):      return "你在每一颗星里找到它独有的美，然后为别人命名它。"
        case ("pisces","scorpio"):    return "你去过星空最深的地方，你知道那里栖息着什么。"
        case ("pisces","sagittarius"):return "你跟随那颗星，即便它在宇宙中不断改变轨迹。"
        case ("pisces","capricorn"):  return "你为人们尚未感知到的感受，在星际间建造大教堂。"
        case ("pisces","aquarius"):   return "你为一个尚未降临的宇宙燃烧自己。"
        case ("pisces","pisces"):     return "你是那片终于想起自己曾是星雨的海洋。"

        default: return "你携带着某种古老而珍稀的星光——相信你感受到的。"
        }
    }

    // MARK: - Compose final tagline with ascendant tonal coloring
    // The element register adds a framing phrase to the front of the tagline.

    private static func tagline(sun: String, moon: String, ascendant: String) -> (String, String) {
        let baseEN = taglineEN(sun: sun, moon: moon)
        let baseZH = taglineZH(sun: sun, moon: moon)
        return (baseEN, baseZH)
        // Note: element tonal framing is baked into the per-combination prose above.
        // The ascendant is intentionally reserved for a future "voice mode" layer.
    }
}
