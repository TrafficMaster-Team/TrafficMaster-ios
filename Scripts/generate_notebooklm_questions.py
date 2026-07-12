#!/usr/bin/env python3
"""Resumable NotebookLM question collector for the TrafficMaster mind map."""

from __future__ import annotations

import argparse
import json
import random
import re
import shutil
import subprocess
import sys
import time
import unicodedata
from pathlib import Path
from typing import Any


NOTEBOOK_ID = "ba0a1a63-2eca-4a44-aba9-c1483130f9a2"

TOPICS: tuple[tuple[str, str], ...] = (
    ("Общие положения", "Правостороннее движение"),
    ("Общие положения", "Основные термины (водитель, дорога, ТС)"),
    ("Общие положения", "Сигналы регулировщика"),
    ("Общие положения", "Значения сигналов светофора"),
    ("Права и обязанности участников ➔ Водители", "Документы для проверки"),
    ("Права и обязанности участников ➔ Водители", "Медицинское освидетельствование"),
    ("Права и обязанности участников ➔ Водители", "Техническое состояние ТС"),
    ("Права и обязанности участников ➔ Водители", "Ремни безопасности и шлемы"),
    ("Права и обязанности участников ➔ Водители", "Запрет на алкоголь и телефоны"),
    ("Права и обязанности участников ➔ Пешеходы", "Движение по тротуарам и обочинам"),
    ("Права и обязанности участников ➔ Пешеходы", "Световозвращающие элементы"),
    ("Права и обязанности участников ➔ Пешеходы", "Порядок перехода дороги"),
    ("Права и обязанности участников ➔ Пассажиры", "Безопасная посадка и высадка"),
    ("Права и обязанности участников ➔ Пассажиры", "Запрет отвлекать водителя"),
    ("Маневрирование и правила движения", "Подача сигналов поворота"),
    ("Маневрирование и правила движения", "Перестроение и разворот"),
    ("Маневрирование и правила движения", "Скоростные режимы (город/трасса)"),
    ("Маневрирование и правила движения", "Дистанция и боковой интервал"),
    ("Маневрирование и правила движения", "Обгон и встречный разъезд"),
    ("Проезд перекрестков и зон", "Регулируемые перекрестки"),
    ("Проезд перекрестков и зон", "Неравнозначные дороги"),
    ("Проезд перекрестков и зон", "Пешеходные переходы"),
    ("Проезд перекрестков и зон", "Железнодорожные переезды"),
    ("Проезд перекрестков и зон", "Автомагистрали"),
    ("Проезд перекрестков и зон", "Жилые и пешеходные зоны"),
    ("Технические нормы и ТС", "Государственный техосмотр"),
    ("Технические нормы и ТС", "Пользование световыми приборами"),
    ("Технические нормы и ТС", "Перевозка пассажиров и грузов"),
    ("Технические нормы и ТС", "Буксировка механических ТС"),
    ("Технические нормы и ТС", "Аварийная сигнализация и знак"),
    ("Изменения 2025 года (Указ № 295)", "Средства персональной мобильности"),
    ("Изменения 2025 года (Указ № 295)", "Регистрация устройств > 25 км/ч"),
    ("Изменения 2025 года (Указ № 295)", "Оценка соответствия ТР ТС 018/2011"),
    ("Изменения 2025 года (Указ № 295)", "Электронные паспорта ТС"),
    ("Изменения 2025 года (Указ № 295)", "Классификация по массе и управлению"),
)


def parse_args() -> argparse.Namespace:
    root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(
        description="Собирает вопросы из NotebookLM по карте и продолжает после сбоев."
    )
    parser.add_argument("--notebook-id", default=NOTEBOOK_ID)
    parser.add_argument("--questions-per-topic", type=int, default=20)
    parser.add_argument("--timeout", type=float, default=240)
    parser.add_argument(
        "--retries",
        type=int,
        default=5,
        help="Число попыток на тему за проход; 0 означает повторять до успеха.",
    )
    parser.add_argument("--profile", help="Профиль nlm, если используется не основной.")
    parser.add_argument(
        "--output",
        type=Path,
        default=root / "TrafficMaster" / "GeneratedQuestions" / "notebooklm_raw",
    )
    parser.add_argument("--force", action="store_true", help="Пересобрать готовые темы.")
    return parser.parse_args()


def slugify(value: str) -> str:
    normalized = unicodedata.normalize("NFKD", value).encode("ascii", "ignore").decode()
    slug = re.sub(r"[^a-zA-Z0-9]+", "-", normalized).strip("-").lower()
    return slug or "topic"


def make_prompt(section: str, topic: str, count: int) -> str:
    hierarchy = f"ПДД Республики Беларусь ➔ {section} ➔ {topic}"
    return f"""Сформируй ровно {count} уникальных экзаменационных вопросов по теме «{topic}».

Используй строго источники этого блокнота о ПДД Республики Беларусь и учитывай Указ № 295 от 04.08.2025. Не добавляй знаний вне источников.

Требования:
- стиль официальных тестовых вопросов ПДД;
- от 2 до 5 вариантов ответа;
- ровно один правильный ответ;
- correct_index — индекс с нуля;
- не используй вопросы, для которых требуется изображение;
- не повторяй один факт перестановкой слов;
- explanation кратко объясняет правило и указывает пункт, главу или приложение, если номер доступен в источнике;
- hierarchy строго «{hierarchy}»;
- origin строго «notebookLM».

Верни ТОЛЬКО валидный JSON-массив без markdown и вводного текста. Формат каждого объекта:
{{"hierarchy":"{hierarchy}","question":"...","image":null,"options":["..."],"correct_index":0,"correct_text":"...","explanation":"...","origin":"notebookLM"}}"""


def run_nlm(args: argparse.Namespace, prompt: str) -> str:
    command = [
        "nlm",
        "notebook",
        "query",
        args.notebook_id,
        prompt,
        "--json",
        "--timeout",
        str(args.timeout),
    ]
    if args.profile:
        command.extend(["--profile", args.profile])
    completed = subprocess.run(
        command,
        check=True,
        capture_output=True,
        text=True,
        timeout=args.timeout + 30,
    )
    return completed.stdout


def find_answer(value: Any) -> str | None:
    if isinstance(value, dict):
        answer = value.get("answer")
        if isinstance(answer, str):
            return answer
        for nested in value.values():
            found = find_answer(nested)
            if found:
                return found
    elif isinstance(value, list):
        for nested in value:
            found = find_answer(nested)
            if found:
                return found
    return None


def parse_questions(raw_output: str) -> list[dict[str, Any]]:
    try:
        wrapper = json.loads(raw_output)
        answer = find_answer(wrapper) or raw_output
    except json.JSONDecodeError:
        answer = raw_output

    answer = re.sub(r"^\s*```(?:json)?\s*|\s*```\s*$", "", answer, flags=re.I)
    start, end = answer.find("["), answer.rfind("]")
    if start < 0 or end < start:
        raise ValueError("NotebookLM не вернул JSON-массив")
    parsed = json.loads(answer[start : end + 1])
    if not isinstance(parsed, list):
        raise ValueError("Ответ NotebookLM не является массивом")
    return parsed


def validate_questions(
    questions: list[dict[str, Any]], section: str, topic: str, expected_count: int
) -> None:
    expected_hierarchy = f"ПДД Республики Беларусь ➔ {section} ➔ {topic}"
    if len(questions) != expected_count:
        raise ValueError(f"ожидалось {expected_count} вопросов, получено {len(questions)}")

    seen: set[str] = set()
    for index, question in enumerate(questions, start=1):
        text = question.get("question")
        options = question.get("options")
        correct_index = question.get("correct_index")
        if not isinstance(text, str) or not text.strip():
            raise ValueError(f"вопрос {index}: пустой текст")
        normalized = " ".join(text.lower().split())
        if normalized in seen:
            raise ValueError(f"вопрос {index}: точный дубль")
        seen.add(normalized)
        if question.get("hierarchy") != expected_hierarchy:
            raise ValueError(f"вопрос {index}: неверная hierarchy")
        if question.get("origin") != "notebookLM":
            raise ValueError(f"вопрос {index}: неверный origin")
        if question.get("image") is not None:
            raise ValueError(f"вопрос {index}: image должен быть null")
        if not isinstance(options, list) or not 2 <= len(options) <= 5:
            raise ValueError(f"вопрос {index}: нужно от 2 до 5 вариантов")
        if len(set(options)) != len(options) or not all(isinstance(x, str) and x.strip() for x in options):
            raise ValueError(f"вопрос {index}: пустые или повторяющиеся варианты")
        if not isinstance(correct_index, int) or not 0 <= correct_index < len(options):
            raise ValueError(f"вопрос {index}: неверный correct_index")
        if question.get("correct_text") != options[correct_index]:
            raise ValueError(f"вопрос {index}: correct_text не совпадает с вариантом")
        if not isinstance(question.get("explanation"), str) or not question["explanation"].strip():
            raise ValueError(f"вопрос {index}: пустое explanation")


def load_valid_batch(path: Path, section: str, topic: str, count: int) -> list[dict[str, Any]] | None:
    if not path.exists():
        return None
    try:
        questions = json.loads(path.read_text(encoding="utf-8"))
        validate_questions(questions, section, topic, count)
        return questions
    except (OSError, ValueError, json.JSONDecodeError, TypeError):
        return None


def atomic_write_json(path: Path, value: Any) -> None:
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(
        json.dumps(value, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    temporary.replace(path)


def collect_topic(
    args: argparse.Namespace, index: int, section: str, topic: str, path: Path
) -> list[dict[str, Any]]:
    prompt = make_prompt(section, topic, args.questions_per_topic)
    attempt = 0
    while True:
        attempt += 1
        print(f"[{index:02d}/{len(TOPICS)}] {topic}: попытка {attempt}", flush=True)
        try:
            raw = run_nlm(args, prompt)
            questions = parse_questions(raw)
            validate_questions(questions, section, topic, args.questions_per_topic)
            atomic_write_json(path, questions)
            return questions
        except KeyboardInterrupt:
            raise
        except Exception as error:  # noqa: BLE001 - the collector must survive external failures.
            debug_path = path.with_suffix(".last-response.txt")
            if "raw" in locals():
                debug_path.write_text(raw, encoding="utf-8")
            print(f"  Сбой: {error}", file=sys.stderr, flush=True)
            if args.retries and attempt >= args.retries:
                raise RuntimeError(f"не удалось собрать тему «{topic}»") from error
            delay = min(60.0, 2 ** min(attempt, 6)) + random.uniform(0, 1.5)
            print(f"  Повтор через {delay:.1f} с. Для безопасной остановки нажмите Ctrl+C.", flush=True)
            time.sleep(delay)


def preflight(args: argparse.Namespace) -> None:
    if shutil.which("nlm") is None:
        raise RuntimeError("Команда nlm не найдена. Установите NotebookLM CLI и выполните nlm login.")
    command = ["nlm", "notebook", "get", args.notebook_id, "--json"]
    if args.profile:
        command.extend(["--profile", args.profile])
    subprocess.run(command, check=True, capture_output=True, text=True, timeout=60)


def main() -> int:
    args = parse_args()
    if args.questions_per_topic < 1:
        raise ValueError("--questions-per-topic должен быть больше нуля")
    args.output.mkdir(parents=True, exist_ok=True)
    preflight(args)

    first_pass = True
    while True:
        pending = 0
        for index, (section, topic) in enumerate(TOPICS, start=1):
            filename = f"{index:02d}-{slugify(section)}-{slugify(topic)}.json"
            path = args.output / filename
            existing = None if args.force and first_pass else load_valid_batch(
                path, section, topic, args.questions_per_topic
            )
            if existing is not None:
                print(f"[{index:02d}/{len(TOPICS)}] {topic}: уже готово, пропускаю")
                continue
            try:
                collect_topic(args, index, section, topic, path)
            except RuntimeError as error:
                pending += 1
                print(f"  Тема отложена до следующего прохода: {error}", file=sys.stderr)
        first_pass = False
        if pending == 0:
            break
        print(f"Осталось тем: {pending}. Новый проход через 30 секунд.", flush=True)
        time.sleep(30)

    all_questions: list[dict[str, Any]] = []
    for index, (section, topic) in enumerate(TOPICS, start=1):
        filename = f"{index:02d}-{slugify(section)}-{slugify(topic)}.json"
        questions = load_valid_batch(
            args.output / filename, section, topic, args.questions_per_topic
        )
        if questions is None:
            raise RuntimeError(f"готовый пакет темы «{topic}» не найден")
        all_questions.extend(questions)

    merged_path = args.output / "all_questions.json"
    atomic_write_json(merged_path, all_questions)
    summary = {
        "notebook_id": args.notebook_id,
        "topics": len(TOPICS),
        "questions_per_topic": args.questions_per_topic,
        "question_count": len(all_questions),
        "merged_file": merged_path.name,
    }
    atomic_write_json(args.output / "manifest.json", summary)
    print(f"Готово: {len(all_questions)} вопросов в {merged_path}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        print("\nОстановлено. При следующем запуске готовые темы будут пропущены.")
        raise SystemExit(130)
    except (RuntimeError, ValueError, subprocess.SubprocessError) as error:
        print(f"Ошибка: {error}", file=sys.stderr)
        raise SystemExit(1)
