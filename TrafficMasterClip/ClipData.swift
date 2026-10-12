//
//  ClipData.swift
//  TrafficMasterClip
//
//  Created by Влад on 12/10/26.
//

import Foundation
import SwiftUI

// MARK: - App Clip Data Models for Investor Demo

struct DemoQuestion: Identifiable, Sendable {
    let id: String
    let topic: String
    let difficulty: String
    let title: String
    let options: [String]
    let correctIndex: Int
    
    // ADrive (Classic) Presentation
    let adriveLawParagraph: String
    let adriveFrustrationRate: String
    let adriveStudyTimeMinutes: Int
    
    // TrafficMaster Presentation
    let tmRuleMnemonic: String
    let tmKeyInsight: String
    let tmMemoryBoost: String
    let tmAiExplanation: String
    let tmDaysToNextReview: Int
    let iconName: String
}

enum AppClipMode: String, CaseIterable, Identifiable {
    case battle = "Баттл"
    case interactiveQuiz = "Тест"
    case investorPitch = "Инвесторам"
    
    var id: String { rawValue }
}

enum StudyExperienceStyle {
    case adrive
    case trafficMaster
}

// MARK: - Curated Trick Questions

enum DemoQuestionsRepository {
    static let questions: [DemoQuestion] = [
        DemoQuestion(
            id: "q1_regulator_tram",
            topic: "Регулировщик и трамвай",
            difficulty: "82% ошибок в тестах",
            title: "Регулировщик стоит правым боком, правая рука вперед. Трамвай едет прямо, легковой авто — направо. Кто проедет первым?",
            options: [
                "Только трамвай",
                "Только легковой автомобиль",
                "Оба одновременно",
                "Движение запрещено"
            ],
            correctIndex: 1,
            adriveLawParagraph: "Пункт 36.1.3 ПДД РБ:\n«Со стороны правого бока при вытянутой вперед правой руке: движение всех ТС запрещено...»\n\nБоль курсанта: 4 страницы казуистики, суть непонятна.",
            adriveFrustrationRate: "82% повторных ошибок через 7 дней",
            adriveStudyTimeMinutes: 25,
            tmRuleMnemonic: "Правило рукавов: Трамвай едет только «из рукава в рукав». Рука вперед — шлагбаум для рельсов! Авто едет «из рукава в рукав» + ПРАВЕЕ. Авто свободно едет направо!",
            tmKeyInsight: "Регулировщик блокирует рельсы, но оставляет свободным правый карман для авто.",
            tmMemoryBoost: "+150% запоминание с 1-й попытки",
            tmAiExplanation: "Регулировщик работает как шлагбаум: правая рука физически перекрывает трамвайные пути. Поворот направо для машины безопасен и разрешен.",
            tmDaysToNextReview: 4,
            iconName: "tram.fill"
        ),
        DemoQuestion(
            id: "q2_simultaneous_change",
            topic: "Одновременное перестроение",
            difficulty: "67% споров в ГАИ",
            title: "Два авто одновременно перестраиваются в среднюю полосу: белый — слева, синий — справа. Кто обязан уступить?",
            options: [
                "Белый уступает синему (помеха справа)",
                "Синий уступает белому (белый быстрее)",
                "Уступает тот, кто позже включил поворотник",
                "По взаимной договоренности"
            ],
            correctIndex: 0,
            adriveLawParagraph: "Пункт 59 ПДД РБ:\n«При одновременном перестроении ТС, движущихся попутно, водитель уступает дорогу ТС справа...»\n\nБоль курсанта: статичный плоский рисунок путает траектории.",
            adriveFrustrationRate: "67% курсантов путают с обычным перестроением",
            adriveStudyTimeMinutes: 18,
            tmRuleMnemonic: "«Береги правый борт!» При взаимном маневре никто не главный: кто справа — тот первый.",
            tmKeyInsight: "Синий автомобиль находится справа от белого в точке схождения.",
            tmMemoryBoost: "+92% уверенности на дороге",
            tmAiExplanation: "Траектории равнозначны. Вступает базовый закон дорожной безопасности: помеха справа имеет приоритет.",
            tmDaysToNextReview: 6,
            iconName: "car.2.fill"
        ),
        DemoQuestion(
            id: "q3_equal_intersection_uturn",
            topic: "Разворот на перекрестке",
            difficulty: "74% провалов",
            title: "Равнозначный перекресток. Вы разворачиваетесь. Встречный авто едет прямо. Обязаны ли вы уступить?",
            options: [
                "Обязаны уступить (стал помехой справа)",
                "Имеете приоритет (уже начали маневр)",
                "Уступает встречный"
            ],
            correctIndex: 0,
            adriveLawParagraph: "Пункт 110 и 111 ПДД РБ:\n«При повороте налево или развороте водитель уступает дорогу...»",
            adriveFrustrationRate: "74% считают, что начатый маневр дает приоритет",
            adriveStudyTimeMinutes: 20,
            tmRuleMnemonic: "Разворот на 180° меняет стороны! Встречный стал вашей правой помехой. Завершая разворот — пропусти его!",
            tmKeyInsight: "Приоритет оценивается в точке пересечения, а не на старте маневра.",
            tmMemoryBoost: "+120% долговременной фиксации",
            tmAiExplanation: "Динамика ситуации: въезжая на перекресток, он встречный, а в процессе разворота оказывается прямо у вас справа.",
            tmDaysToNextReview: 5,
            iconName: "arrow.triangle.swap"
        )
    ]
}

// MARK: - Investor Metrics Data

struct TractionMetric: Identifiable, Sendable {
    let id = UUID()
    let title: String
    let tmValue: String
    let classicValue: String
    let delta: String
    let subtitle: String
    let icon: String
}

enum InvestorMetricsRepository {
    static let metrics: [TractionMetric] = [
        TractionMetric(
            title: "Сдача теории с 1-й попытки",
            tmValue: "94.2%",
            classicValue: "61.8%",
            delta: "+32%",
            subtitle: "Пилотные группы автошкол",
            icon: "checkmark.seal.fill"
        ),
        TractionMetric(
            title: "Время на весь курс",
            tmValue: "18 часов",
            classicValue: "54 часа",
            delta: "-66%",
            subtitle: "Без зубрёжки выученного",
            icon: "clock.arrow.circlepath"
        ),
        TractionMetric(
            title: "Retention D30",
            tmValue: "58.4%",
            classicValue: "14.1%",
            delta: "4.1x",
            subtitle: "SM-2 интервалы",
            icon: "flame.fill"
        ),
        TractionMetric(
            title: "Виральный K-Factor",
            tmValue: "1.42",
            classicValue: "0.25",
            delta: "5.7x",
            subtitle: "Рекомендации друзьям",
            icon: "person.3.sequence.fill"
        )
    ]
}
