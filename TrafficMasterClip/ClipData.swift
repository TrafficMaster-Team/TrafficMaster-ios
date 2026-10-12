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
            difficulty: "Хардкор (82% ошибок в ADrive)",
            title: "Регулировщик обращен правым боком, правая рука вытянута вперед. Трамвай едет прямо, авто поворачивает направо. Кто проедет первым?",
            options: [
                "Только трамвай",
                "Только легковой автомобиль",
                "Оба транспортных средства одновременно",
                "Движение всех транспортных средств запрещено"
            ],
            correctIndex: 1,
            adriveLawParagraph: "Пункт 36.1.3 ПДД РБ:\n«Со стороны правого бока при вытянутой вперед правой руке регулировщика: движение всех транспортных средств запрещено. Со стороны груди всем ТС разрешено движение только направо...»\n\nРезультат: 4 страницы казуистики, ученик не понимает почему трамвай стоит, если рельсы свободны.",
            adriveFrustrationRate: "82% курсантов совершают повторную ошибку через 7 дней",
            adriveStudyTimeMinutes: 25,
            tmRuleMnemonic: "Правило рукавов: Трамвай едет только «из рукава в рукав»! Рука вперед — шлагбаум для рельсов. А легковушка всегда едет «из рукава в рукав» + ПРАВЕЕ. Поэтому авто свободно едет направо!",
            tmKeyInsight: "Регулировщик закрывает трамваю сквозной проезд рукой-шлагбаумом. Автомобиль уходит направо без пересечения конфликтующих потоков.",
            tmMemoryBoost: "+150% к запоминанию с 1-го раза",
            tmAiExplanation: "Представь, что регулировщик — это физический шлагбаум. Его вытянутая правая рука буквально блокирует трамвайные пути. А поворот направо со стороны правого борта всегда безопасен для маневра авто.",
            tmDaysToNextReview: 4,
            iconName: "tram.fill"
        ),
        DemoQuestion(
            id: "q2_simultaneous_change",
            topic: "Одновременное перестроение",
            difficulty: "Высокая (67% ошибок в ADrive)",
            title: "Два автомобиля на многополосной дороге одновременно перестраиваются: белый — из левой в среднюю, синий — из правой в среднюю. Кто уступает?",
            options: [
                "Белый уступает синему (помеха справа)",
                "Синий уступает белому (белый быстрее)",
                "Уступает тот, кто последним включил поворотник",
                "Проезжают по взаимной договоренности"
            ],
            correctIndex: 0,
            adriveLawParagraph: "Пункт 59 ПДД РБ:\n«При одновременном перестроении транспортных средств, движущихся попутно, водитель должен уступить дорогу транспортному средству, находящемуся справа...»\n\nВ старых тестах часто путают одиночное и взаимное перестроение из-за невнятной графики.",
            adriveFrustrationRate: "67% споров на экзамене ГАИ",
            adriveStudyTimeMinutes: 18,
            tmRuleMnemonic: "«Береги правый борт!» При взаимном перестроении включается базовый закон физики дорог: кто справа — тот в приоритете.",
            tmKeyInsight: "Синий автомобиль находится справа по отношению к белому в точке схождения траекторий.",
            tmMemoryBoost: "+92% уверенности на перекрестках",
            tmAiExplanation: "Когда траектории пересекаются равноправно, ни у кого нет выделенного приоритета полосы. В этот момент работает универсальный предохранитель ПДД — помеха справа.",
            tmDaysToNextReview: 6,
            iconName: "car.2.fill"
        ),
        DemoQuestion(
            id: "q3_equal_intersection_uturn",
            topic: "Разворот на равнозначном перекрестке",
            difficulty: "Ловушка (74% ошибок в ADrive)",
            title: "Равнозначный перекресток. Вы разворачиваетесь. Во время разворота справа оказывается автомобиль, ехавший изначально навстречу. Кто уступает?",
            options: [
                "Вы уступаете встречному (он стал помехой справа)",
                "Встречный уступает (вы уже на перекрестке)",
                "Тот, у кого меньше радиус разворота"
            ],
            correctIndex: 0,
            adriveLawParagraph: "Пункт 110 и 111 ПДД РБ:\n«При повороте налево или развороте водитель обязан уступить дорогу... При завершении маневра применяются общие правила проезда перекрестков...»",
            adriveFrustrationRate: "74% курсантов считают, что начатый маневр дает безусловный приоритет",
            adriveStudyTimeMinutes: 20,
            tmRuleMnemonic: "«Маневр меняет ориентацию в пространстве»: развернувшись на 180°, бывший встречный оказывается у вас справа. Завершая разворот — пропусти его!",
            tmKeyInsight: "Помеха справа оценивается не в начале маневра, а в момент пересечения траекторий.",
            tmMemoryBoost: "+120% долговременной фиксации",
            tmAiExplanation: "Коварство этого вопроса в динамике: когда ты подъехал к перекрестку — он встречный. Когда начал крутить руль — он стал твоей правой помехой. TrafficMaster визуализирует эту динамику вращения.",
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
            title: "Сдача теории ГАИ с 1-й попытки",
            tmValue: "94.2%",
            classicValue: "61.8%",
            delta: "+32.4%",
            subtitle: "По данным пилотных групп автошкол",
            icon: "checkmark.seal.fill"
        ),
        TractionMetric(
            title: "Среднее время подготовки",
            tmValue: "18 часов",
            classicValue: "54 часа",
            delta: "-66%",
            subtitle: "SM-2 исключает повторение того, что уже выучено",
            icon: "clock.arrow.circlepath"
        ),
        TractionMetric(
            title: "Retention D30 (Возвращаемость)",
            tmValue: "58.4%",
            classicValue: "14.1%",
            delta: "4.1x",
            subtitle: "Умные push-уведомления точно в срок забывания",
            icon: "flame.fill"
        ),
        TractionMetric(
            title: "Виральный K-Factor",
            tmValue: "1.42",
            classicValue: "0.25",
            delta: "5.7x",
            subtitle: "Курсанты рекомендуют сокурсникам в автошколе",
            icon: "person.3.sequence.fill"
        )
    ]
}
