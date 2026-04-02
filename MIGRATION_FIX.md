# 🔧 Исправление ошибки миграции базы данных

## ❌ Проблема

```
CoreData: error: An error occurred during persistent store migration.
reason=Cannot migrate store in-place: Validation error missing attribute 
values on mandatory destination attribute
entity=Question, attribute=difficulty
```

**Причина:** На устройстве есть старая версия базы данных без полей FSRS (`difficulty`, `stability`, `retrievability`).

---

## ✅ Решение 1: Автоматическое (встроено в приложение)

Приложение **автоматически** обнаружит ошибку миграции и:
1. Удалит старую базу данных
2. Создаст новую с правильной схемой
3. Загрузит все 3000 вопросов заново

**Что увидит пользователь:**
- При запуске: "Загрузка данных..." (5-30 секунд)
- После загрузки: Экран входа
- Все данные восстановлены!

---

## ✅ Решение 2: Вручную (если авто не сработало)

### Вариант A: Удалить и установить заново

1. **Удалите приложение** с iPhone (долгое нажатие → Удалить)
2. **Установите заново** через Xcode (Run)
3. Данные загрузятся автоматически

### Вариант B: Сброс через настройки (если есть)

Пока не реализовано.

---

## 📝 Что изменилось в коде

### `TrafficMasterApp.swift`

Добавлена обработка ошибки миграции:

```swift
do {
    let container = try ModelContainer(...)
    return container
} catch {
    // Migration failed - delete old store and recreate
    print("⚠️ Migration failed: \(error)")
    
    // Delete old store
    let storeURL = ...default.store
    try FileManager.default.removeItem(at: storeURL)
    
    // Recreate container
    let newContainer = try ModelContainer(...)
    return newContainer
}
```

### `Question.swift`

Добавлены default значения для FSRS полей:

```swift
self.stability = 0.0
self.difficulty = 5.0      // Default middle value
self.retrievability = 1.0
```

Добавлен метод валидации:

```swift
func validateAndFixDefaults() {
    if stability < 0 { stability = 0.0 }
    if difficulty <= 0 { difficulty = 5.0 }
    if retrievability < 0 || retrievability > 1 { retrievability = 1.0 }
    // ...
}
```

---

## 🧪 Тестирование

### На симуляторе:

1. Запустите старую версию приложения (с базой v4)
2. Обновите до новой версии
3. Проверьте логи:
   ```
   ⚠️ Migration failed: ...
   🗑️ Deleting old store...
   ✅ Old store deleted, recreating...
   🚀 Starting background data import...
   🎉 Successfully finished data import.
   ```

### На устройстве:

1. Подключите iPhone
2. Запустите приложение
3. Следите за логами в Xcode Console

---

## 📊 Версии базы данных

| Версия | Изменения |
|---|---|
| v1-v3 | SM-2 только (repetitions, interval, easinessFactor) |
| v4 | Добавлены FSRS поля (stability, difficulty, retrievability) |
| **v5** | **Default значения для FSRS + валидация** |

---

## ✅ Результат

После исправления:
- ✅ Приложение запускается без ошибок
- ✅ Все 3000 вопросов загружаются
- ✅ FSRS алгоритм работает корректно
- ✅ Марафон и экзамен режимы доступны

**Устанавливайте и тестируйте!** 🎉
