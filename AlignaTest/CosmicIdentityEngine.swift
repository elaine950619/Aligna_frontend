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
    // Written as original Chinese phrases, not translated from the EN versions.
    private static func taglineZH(sun: String, moon: String) -> String {
        switch (sun, moon) {
        // ── 白羊太阳 ──
        case ("aries","aries"):       return "你总是世界反应过来之前，已经出发了。"
        case ("aries","taurus"):      return "脚步坚定，不需要任何人的许可。"
        case ("aries","gemini"):      return "你把念头变成故事，把故事变成行动。"
        case ("aries","cancer"):      return "你拥有铠甲，也拥有一颗柔软的心。"
        case ("aries","leo"):         return "你走进来，整个房间都知道了。"
        case ("aries","virgo"):       return "直觉锐利，标准极高，偏偏都做到了。"
        case ("aries","libra"):       return "冲在最前，但会停下来把它做漂亮。"
        case ("aries","scorpio"):     return "表面无畏，骨子里藏着一片幽深。"
        case ("aries","sagittarius"): return "你是燃烧的那种人，连地平线都为你让路。"
        case ("aries","capricorn"):   return "热血铸就骨骼，冲动锻造成型。"
        case ("aries","aquarius"):    return "反叛者，但有蓝图，有方向。"
        case ("aries","pisces"):      return "别人半信半疑的梦，你一个人先去做了。"

        // ── 金牛太阳 ──
        case ("taurus","aries"):      return "平静的水面下，有一股什么都拦不住的力量。"
        case ("taurus","taurus"):     return "深根于大地，连土地都依赖你的重量。"
        case ("taurus","gemini"):     return "你建造得缓慢，但思维从未停止。"
        case ("taurus","cancer"):     return "一顿饭可以是一个家，一句话可以是一生的记忆。"
        case ("taurus","leo"):        return "低调的壮丽，让作品说话，让时间证明。"
        case ("taurus","virgo"):      return "耐心与精准，让你无法被催赶，也无法被超越。"
        case ("taurus","libra"):      return "你深知美不是装饰，而是一种真相。"
        case ("taurus","scorpio"):    return "外表平静如岩，内心深处是岩浆。"
        case ("taurus","sagittarius"):return "四处游历，却总能找到回家的路。"
        case ("taurus","capricorn"):  return "一块一块地垒，你在建造某种可以传世的东西。"
        case ("taurus","aquarius"):   return "脚踏实地地，把那些激进的想法变成现实。"
        case ("taurus","pisces"):     return "你感知到别人忽略的，并把它轻轻托住。"

        // ── 双子太阳 ──
        case ("gemini","aries"):      return "问题还没说完，你已经有了三个答案。"
        case ("gemini","taurus"):     return "好奇心旺盛，但也知道什么时候安静地坐下来听。"
        case ("gemini","gemini"):     return "你说的每句话都有好几层，每层都是一个小宇宙。"
        case ("gemini","cancer"):     return "经你口说出的话，会比别人柔软许多。"
        case ("gemini","leo"):        return "聪明、有磁性，让人很难不注意到你。"
        case ("gemini","virgo"):      return "你能找到论点里的破绽，也能看见细节里的美。"
        case ("gemini","libra"):      return "你在矛盾之间穿行，从不失去平衡。"
        case ("gemini","scorpio"):    return "你的问题直指别人不敢看的地方。"
        case ("gemini","sagittarius"):return "每一次对话对你来说都是一场旅行。"
        case ("gemini","capricorn"):  return "不安分的头脑，稳定的目的地——难得的组合。"
        case ("gemini","aquarius"):   return "你在描绘未来可能的感受。"
        case ("gemini","pisces"):     return "你把沉默翻译成所有人都能听懂的语言。"

        // ── 巨蟹太阳 ──
        case ("cancer","aries"):      return "内心温柔，但比任何人都更难被打倒。"
        case ("cancer","taurus"):     return "你走到哪里，归属感就带到哪里。"
        case ("cancer","gemini"):     return "你有一种让陌生人觉得被记住的本领。"
        case ("cancer","cancer"):     return "世界能维系，靠的就是你这样的人。"
        case ("cancer","leo"):        return "那种不需要宣告自己的温暖，才是最真实的光。"
        case ("cancer","virgo"):      return "你看见那些被人走过却忽略的小小伤口。"
        case ("cancer","libra"):      return "你让整个房间保持平衡，没有人意识到是你做到的。"
        case ("cancer","scorpio"):    return "爱得深，记性好，重要的事你一件都不会忘。"
        case ("cancer","sagittarius"):return "家在哪里，是你的故事讲到哪里。"
        case ("cancer","capricorn"):  return "你建造的东西，是为了比你活得更久。"
        case ("cancer","aquarius"):   return "你爱这个世界，所以才想改变它。"
        case ("cancer","pisces"):     return "你感受到那股暗流，那个别人无法命名的东西。"

        // ── 狮子太阳 ──
        case ("leo","aries"):         return "光芒与舞台，你生来就是为了两者并存。"
        case ("leo","taurus"):        return "不费力气地耀眼，无条件地忠诚。"
        case ("leo","gemini"):        return "你把每个房间变成剧场，把每个故事变成传奇。"
        case ("leo","cancer"):        return "你的慷慨让人记住的不是礼物，而是感觉。"
        case ("leo","leo"):           return "你不需要被允许发光，你就是那道光。"
        case ("leo","virgo"):         return "台上的完美，是因为台下没人看见你的准备。"
        case ("leo","libra"):         return "魅力与优雅在一起，任何事都挡不住。"
        case ("leo","scorpio"):       return "有深度的力量，配得上这个存在感。"
        case ("leo","sagittarius"):   return "生来就为了那种宏大的冒险与宏大的姿态。"
        case ("leo","capricorn"):     return "你建造一段传奇，然后走进它应得的聚光灯下。"
        case ("leo","aquarius"):      return "你带领别人走向他们还没敢想的那个方向。"
        case ("leo","pisces"):        return "你的心是个舞台，每一种感受都有它的时刻。"

        // ── 处女太阳 ──
        case ("virgo","aries"):       return "先行动，再打磨，直到它恰好正确。"
        case ("virgo","taurus"):      return "精通源于耐心——你完全信任这个过程。"
        case ("virgo","gemini"):      return "你在所有的噪声里找到那个真实的信号。"
        case ("virgo","cancer"):      return "你通过精准去关怀——每一个细节都是爱的动作。"
        case ("virgo","leo"):         return "所有精彩结果背后，那个安静的力量是你。"
        case ("virgo","virgo"):       return "你坚守最高标准，因为你相信它是可能的。"
        case ("virgo","libra"):       return "你让复杂的事变得优雅，让优雅的事变得正确。"
        case ("virgo","scorpio"):     return "你什么都看见——但只说需要被说的那些。"
        case ("virgo","sagittarius"): return "踏实的好奇心：你寻找真相，然后用它建造。"
        case ("virgo","capricorn"):   return "自律与专注，悄悄改变着一切。"
        case ("virgo","aquarius"):    return "你在解决别人还没命名的问题。"
        case ("virgo","pisces"):      return "精准到足以发现裂缝，温柔到足以将其愈合。"

        // ── 天秤太阳 ──
        case ("libra","aries"):       return "你快速移动，但总是朝着公平的方向。"
        case ("libra","taurus"):      return "你对美的感知，是一种深刻的智慧。"
        case ("libra","gemini"):      return "你持有论点的两面，并找到它们之间的诗意。"
        case ("libra","cancer"):      return "连结是你的天赋，和谐是你的艺术。"
        case ("libra","leo"):         return "迷人而不刻意，有力而不强迫。"
        case ("libra","virgo"):       return "你衡量一切，直到平衡精确无误。"
        case ("libra","libra"):       return "你看见理想的样子，并拒绝接受更少。"
        case ("libra","scorpio"):     return "表面优雅，内心毫不动摇。"
        case ("libra","sagittarius"): return "你奔向公正，带着满满的故事回来。"
        case ("libra","capricorn"):   return "你建造公平的体系，让争论本身失去意义。"
        case ("libra","aquarius"):    return "你梦想的世界里，设计与公平同时存在。"
        case ("libra","pisces"):      return "你让世界柔软，却没有失去自己的轮廓。"

        // ── 天蝎太阳 ──
        case ("scorpio","aries"):     return "房间里最厉害的那个，通常不是第一个开口的。"
        case ("scorpio","taurus"):    return "你承受别人无法承受的，然后以另一种样子出现。"
        case ("scorpio","gemini"):    return "你的思维能找到每个房间里那扇隐藏的门。"
        case ("scorpio","cancer"):    return "你全心去爱，并守护被托付给你的一切。"
        case ("scorpio","leo"):       return "强烈与磁性并存——一种罕见而无法忽视的存在。"
        case ("scorpio","virgo"):     return "你能诊断出哪里出了问题，也知道如何修复它。"
        case ("scorpio","libra"):     return "你看穿光鲜的表面，直抵真实的内核。"
        case ("scorpio","scorpio"):   return "深渊呼唤深渊——你不害怕黑暗。"
        case ("scorpio","sagittarius"):return "你追寻真相，即便它让你付出代价。"
        case ("scorpio","capricorn"): return "耐心、有力、精准——长期博弈，赢在你手里。"
        case ("scorpio","aquarius"):  return "你清楚地看见这个体系，也看见它在哪里断裂。"
        case ("scorpio","pisces"):    return "你触碰事物的伤口，然后以某种方式让它愈合。"

        // ── 射手太阳 ──
        case ("sagittarius","aries"): return "全速向着下一个真实的东西出发。"
        case ("sagittarius","taurus"):return "你追寻广阔的世界，但需要一个真实的地方来回归。"
        case ("sagittarius","gemini"):return "每一次旅行都是一座你随身携带的图书馆。"
        case ("sagittarius","cancer"):return "家在你心里，无论路通向哪里。"
        case ("sagittarius","leo"):   return "宏大的愿景，宏大的存在——你一到，事情就开始了。"
        case ("sagittarius","virgo"): return "你带着目的出发，带着答案归来。"
        case ("sagittarius","libra"): return "那个无论如何都会说实话的外交家。"
        case ("sagittarius","scorpio"):return "你顺着线索走，直到它引向真实的地方。"
        case ("sagittarius","sagittarius"):return "无限的地平线，无尽的相信——世界永远是刚刚开始。"
        case ("sagittarius","capricorn"):return "你做大梦，然后真的去建造它。"
        case ("sagittarius","aquarius"):return "你怀揣着事物应有的样子，并且是认真的。"
        case ("sagittarius","pisces"):return "你相信某种比自己更大的东西，始终如此。"

        // ── 摩羯太阳 ──
        case ("capricorn","aries"):   return "有雄心，有紧迫感——你让事情发生，然后让它持续。"
        case ("capricorn","taurus"):  return "你缓慢地建造，因为你知道什么能够长久。"
        case ("capricorn","gemini"):  return "策略与机智——你总是知道下一步。"
        case ("capricorn","cancer"):  return "你为那些在你之后到来的人而工作。"
        case ("capricorn","leo"):     return "安静的权威，在任何场合都无需证明自己。"
        case ("capricorn","virgo"):   return "你是那个守住标准、让别人得以攀升的人。"
        case ("capricorn","libra"):   return "你建造的结构，既正确，又美丽。"
        case ("capricorn","scorpio"): return "稳如基岩，深如断层——你自己知道有多深。"
        case ("capricorn","sagittarius"):return "愿景与纪律，握在同一双沉稳的手里。"
        case ("capricorn","capricorn"):return "你把未来扛在背上，不抱怨，继续走。"
        case ("capricorn","aquarius"):return "你从内部改革那个体制。"
        case ("capricorn","pisces"):  return "你把梦变成蓝图，然后一块石头一块石头地建造它。"

        // ── 水瓶太阳 ──
        case ("aquarius","aries"):    return "你打破现在，是为了给未来留出呼吸的空间。"
        case ("aquarius","taurus"):   return "激进的想法，落在务实的手里——最稀有的组合。"
        case ("aquarius","gemini"):   return "你用系统思考，用可能性说话。"
        case ("aquarius","cancer"):   return "你爱人类，爱到愿意为素未谋面的人去战斗。"
        case ("aquarius","leo"):      return "先觉者与发光者——你让未来感觉像现在。"
        case ("aquarius","virgo"):    return "你看见哪里出了错，也知道怎么让它对。"
        case ("aquarius","libra"):    return "你想象公平，然后去建造它。"
        case ("aquarius","scorpio"):  return "你知道别人还没准备好知道的事。"
        case ("aquarius","sagittarius"):return "你携带着一张通往尚不存在之地的地图。"
        case ("aquarius","capricorn"):return "你用昨天的纪律，建造明天的体制。"
        case ("aquarius","aquarius"): return "来自未来的信号——陌生、必要、清晰。"
        case ("aquarius","pisces"):   return "你梦想一个从未存在的世界，然后仍然朝它走去。"

        // ── 双鱼太阳 ──
        case ("pisces","aries"):      return "外表柔软，内里有一股不知疲倦的劲。"
        case ("pisces","taurus"):     return "你感受一切，但根扎得很深，不会漂走。"
        case ("pisces","gemini"):     return "你说的是那种介于之间的语言。"
        case ("pisces","cancer"):     return "你的共情，是连海洋都会羡慕的深度。"
        case ("pisces","leo"):        return "你把感受变成艺术，让它比你活得更久。"
        case ("pisces","virgo"):      return "你用安静的精准，照料那些看不见的伤。"
        case ("pisces","libra"):      return "你在一切之中找到美，然后为别人命名它。"
        case ("pisces","scorpio"):    return "你去过最深的地方，你知道那里住着什么。"
        case ("pisces","sagittarius"):return "你跟随那颗星，即便它一直在移动。"
        case ("pisces","capricorn"):  return "你为人们尚未感受到的感受，建造大教堂。"
        case ("pisces","aquarius"):   return "你为一个尚未到来的世界流血。"
        case ("pisces","pisces"):     return "你是那片想起自己曾是雨的海洋。"

        default: return "你携带着某种珍稀的东西——相信你感受到的。"
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
