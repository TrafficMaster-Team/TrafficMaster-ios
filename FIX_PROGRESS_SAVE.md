# 🔧 Исправление бага с сохранением прогресса

## ❌ Проблема

**Что было:**
- Проходишь первый урок
- Отвечаешь на вопросы
- После завершения **урок не отмечается как выполненный** ❌
- Кнопка остаётся жёлтой (current), а не зелёной (completed)

**Причина:**
В `QuestionViewModel.applyFSRSRating()` не увеличивался `question.repetitions` при правильном ответе!

```swift
// БЫЛО - НЕ РАБОТАЛО
if grade == .good {
    if !sessionQueue.isEmpty { sessionQueue.removeFirst() }
    loadNextFromQueue()
    learnedTodayCount += 1
    // ❌ question.repetitions НЕ увеличивался!
}
```

---

## ✅ Решение

### 1. Увеличиваем `repetitions` при правильном ответе

**Файл:** `QuestionViewModel.swift`

```swift
if grade == .good {
    // Увеличиваем repetitions только при правильном ответе
    question.repetitions += 1
    
    if !sessionQueue.isEmpty { sessionQueue.removeFirst() }
    loadNextFromQueue()
    learnedTodayCount += 1
} else {
    // При неправильном ответе - сбрасываем repetitions
    question.repetitions = 0
    question.interval = 1
    
    if !sessionQueue.isEmpty {
        let failed = sessionQueue.removeFirst()
        sessionQueue.append(failed)
    }
    loadNextFromQueue()
}
```

### 2. Добавлено логирование сохранения

```swift
// Сохраняем в БД
do {
    try modelContext?.save()
    print("✅ Question saved: repetitions=\(question.repetitions), nextReview=\(question.nextReviewDate)")
} catch {
    print("❌ Failed to save question: \(error)")
}
```

---

## 🧪 Проверка

### Тест 1: Первый урок

1. Открой приложение
2. Нажми на **первый урок** (жёлтая кнопка с "START")
3. Ответь на все вопросы правильно
4. Вернись на главную
5. **Результат:** ✅ Урок должен стать **зелёным** (completed)

### Тест 2: Логирование

В консоли Xcode должно быть:
```
✅ Question saved: repetitions=1, nextReview=2026-04-02 12:00:00
✅ Question saved: repetitions=1, nextReview=2026-04-02 12:00:00
...
```

### Тест 3: Неправильный ответ

1. Ответь **неправильно** на вопрос
2. В логе должно быть:
   ```
   ✅ Question saved: repetitions=0, nextReview=2026-04-01 12:00:00
   ```
3. Вопрос останется в очереди на повторение

---

## 📊 Логика работы

### Правильный ответ (Grade 3 = .good):
```
repetitions: 0 → 1
interval: 1 → 1 (первый повтор)
nextReview: сейчас → завтра
Статус: NEW → LEARNING
```

### Неправильный ответ (Grade 1 = .again):
```
repetitions: 1 → 0 (сброс)
interval: 6 → 1 (сброс)
nextReview: через 6 дней → сейчас
Статус: LEARNING → NEW (сброс)
```

---

## 📝 Изменённые файлы

| Файл | Изменения |
|---|---|
| `QuestionViewModel.swift` | + `question.repetitions += 1` при правильном ответе |
| `QuestionViewModel.swift` | + сброс `repetitions = 0` при неправильном |
| `QuestionViewModel.swift` | + логирование сохранения в БД |

---

## 🎯 Результат

**Теперь:**
- ✅ Уроки отмечаются зелёным после прохождения
- ✅ Прогресс сохраняется в БД
- ✅ `@Query` в HomeView автоматически обновляется
- ✅ Кнопка становится из жёлтой → зелёной
- ✅ Видно в статистике: "Выучено: X"

**Устанавливай и тестируй!** 🎉
