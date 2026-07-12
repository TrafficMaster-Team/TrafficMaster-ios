#!/usr/bin/env python3
"""Resumable, metadata-preserving NotebookLM collector for TrafficMaster."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import random
import re
import shutil
import subprocess
import sys
import time
import unicodedata
from datetime import UTC, datetime
from pathlib import Path
from typing import Any


NOTEBOOK_ID = "ba0a1a63-2eca-4a44-aba9-c1483130f9a2"
SCHEMA_VERSION = 2
SOURCE_TITLES = (
    "2005-189(007-070).pdf",
    "Правила дорожного движения Республики Беларусь",
    "Указ № 295 от 04.08.2025",
)

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


class TerminalUI:
    """Small dependency-free true-color UI that renders cleanly in Ghostty."""

    RESET = "\033[0m"
    BOLD = "\033[1m"
    DIM = "\033[2m"

    def __init__(self, no_color: bool) -> None:
        self.color = sys.stdout.isatty() and not no_color and "NO_COLOR" not in os.environ
        self.width = min(max(shutil.get_terminal_size((88, 24)).columns, 72), 104)

    def rgb(self, text: str, red: int, green: int, blue: int, *, bold: bool = False) -> str:
        if not self.color:
            return text
        weight = self.BOLD if bold else ""
        return f"\033[38;2;{red};{green};{blue}m{weight}{text}{self.RESET}"

    def muted(self, text: str) -> str:
        return self.rgb(text, 132, 146, 166)

    def header(self, target: int, output: Path) -> None:
        inner = self.width - 2
        title = " TrafficMaster · NotebookLM Collector "
        print(self.rgb("╭" + "─" * inner + "╮", 92, 184, 255))
        print(self.rgb("│", 92, 184, 255) + self.rgb(title.center(inner), 228, 241, 255, bold=True) + self.rgb("│", 92, 184, 255))
        subtitle = f" {len(TOPICS)} тем  ·  цель {target} вопросов  ·  безопасное продолжение включено "
        print(self.rgb("│", 92, 184, 255) + self.muted(subtitle.center(inner)) + self.rgb("│", 92, 184, 255))
        print(self.rgb("╰" + "─" * inner + "╯", 92, 184, 255))
        print(self.muted(f"  Сохранение: {output}"))
        print()

    def progress(self, current: int, target: int) -> str:
        width = 20
        ratio = 0 if target == 0 else min(current / target, 1)
        filled = round(width * ratio)
        bar = self.rgb("█" * filled, 92, 214, 156) + self.muted("░" * (width - filled))
        return f"{bar} {current:>3}/{target:<3}"

    def topic(self, index: int, topic: str, current: int, target: int, state: str) -> None:
        prefix = self.muted(f"{index:02d}/{len(TOPICS):02d}")
        if state == "done":
            icon = self.rgb("✓", 92, 214, 156, bold=True)
            suffix = self.rgb("готово", 92, 214, 156)
        elif state == "partial":
            icon = self.rgb("◐", 255, 190, 92, bold=True)
            suffix = self.rgb(f"дособрать {target - current}", 255, 190, 92)
        else:
            icon = self.rgb("○", 92, 184, 255, bold=True)
            suffix = self.rgb("новая тема", 92, 184, 255)
        print(f"  {prefix}  {icon}  {topic}  {self.muted('·')}  {suffix}")

    def attempt(self, attempt: int, current: int, target: int) -> None:
        print(f"         {self.rgb('↳', 92, 184, 255)} попытка {attempt}  {self.progress(current, target)}", flush=True)

    def success(self, added: int, total: int) -> None:
        print(f"         {self.rgb('✓', 92, 214, 156)} сохранено +{added}, всего {total}\n")

    def warning(self, message: str) -> None:
        print(f"         {self.rgb('!', 255, 190, 92, bold=True)} {message}", file=sys.stderr, flush=True)

    def error(self, message: str) -> None:
        compact = " ".join(str(message).split())
        print(f"         {self.rgb('×', 255, 104, 120, bold=True)} {compact}", file=sys.stderr, flush=True)

    def complete(self, count: int, path: Path, missing_hints: int) -> None:
        print(self.rgb("─" * self.width, 92, 184, 255))
        print(self.rgb(f"  ✓ Готово: {count} вопросов", 92, 214, 156, bold=True))
        print(f"  {self.muted(str(path))}")
        if missing_hints:
            print(self.muted(f"  У восстановленных вопросов без исходной подсказки: {missing_hints}"))


def parse_args() -> argparse.Namespace:
    root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(
        description="Собирает вопросы из NotebookLM и продолжает с сохраненного места."
    )
    parser.add_argument("--notebook-id", default=NOTEBOOK_ID)
    parser.add_argument("--questions-per-topic", type=int, default=20)
    parser.add_argument("--timeout", type=float, default=240)
    parser.add_argument(
        "--retries",
        type=int,
        default=5,
        help="Попыток на тему за проход; 0 означает повторять до успеха.",
    )
    parser.add_argument("--profile", help="Профиль nlm, если используется не основной.")
    parser.add_argument(
        "--output",
        type=Path,
        default=root / "TrafficMaster" / "GeneratedQuestions" / "notebooklm_raw",
    )
    parser.add_argument("--force", action="store_true", help="Пересобрать все темы.")
    parser.add_argument("--no-color", action="store_true", help="Отключить цвета ANSI.")
    parser.add_argument(
        "--status",
        action="store_true",
        help="Показать сохраненный прогресс без запросов к NotebookLM.",
    )
    return parser.parse_args()


def slugify(value: str) -> str:
    normalized = unicodedata.normalize("NFKC", value).lower().replace("ё", "е")
    slug = re.sub(r"[^\w]+", "-", normalized, flags=re.UNICODE).strip("-_ ")
    return slug or "тема"


def hierarchy_for(section: str, topic: str) -> str:
    return f"ПДД Республики Беларусь ➔ {section} ➔ {topic}"


def canonical_path(output: Path, index: int, topic: str) -> Path:
    return output / f"{index:02d}-{slugify(topic)}.json"


def make_prompt(
    section: str,
    topic: str,
    count: int,
    existing_questions: list[dict[str, Any]],
) -> str:
    hierarchy = hierarchy_for(section, topic)
    exclusions = "\n".join(f"- {item['question']}" for item in existing_questions)
    if not exclusions:
        exclusions = "- Нет ранее сохраненных вопросов."
    return f"""Сформируй ровно {count} НОВЫХ уникальных экзаменационных вопросов по теме «{topic}».

Используй строго источники этого блокнота о ПДД Республики Беларусь и учитывай Указ № 295 от 04.08.2025. Не добавляй знаний вне источников.

Уже сохраненные вопросы, которые нельзя повторять или перефразировать:
{exclusions}

Требования:
- стиль официальных тестовых вопросов ПДД;
- от 2 до 5 вариантов ответа, ровно один правильный;
- correct_index — индекс с нуля, correct_text дословно совпадает с правильным вариантом;
- image всегда null: не используй вопросы, для которых требуется изображение;
- explanation подробно, но компактно объясняет норму;
- hint дает полезную подсказку, но НЕ раскрывает правильный ответ;
- source_reference содержит точный пункт, главу, приложение или норму источника;
- source_titles содержит названия реально использованных источников блокнота;
- difficulty — только easy, medium или hard;
- tags — от 2 до 6 коротких тематических тегов;
- hierarchy строго «{hierarchy}»;
- origin строго «notebookLM».

Верни ТОЛЬКО валидный JSON-массив без markdown и вводного текста. Формат каждого объекта:
{{"hierarchy":"{hierarchy}","question":"...","image":null,"options":["..."],"correct_index":0,"correct_text":"...","hint":"...","explanation":"...","source_reference":"пункт ...","source_titles":["..."],"difficulty":"medium","tags":["..."],"origin":"notebookLM"}}"""


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
        wrapper = json.loads(raw_output, strict=False)
        answer = find_answer(wrapper) or raw_output
    except json.JSONDecodeError:
        answer = raw_output
    answer = re.sub(r"^\s*```(?:json)?\s*|\s*```\s*$", "", answer, flags=re.I)
    start, end = answer.find("["), answer.rfind("]")
    if start < 0 or end < start:
        raise ValueError("NotebookLM не вернул JSON-массив")
    parsed = json.loads(answer[start : end + 1], strict=False)
    if not isinstance(parsed, list):
        raise ValueError("ответ NotebookLM не является массивом")
    return parsed


def extract_reference(explanation: str) -> str | None:
    match = re.match(
        r"^Согласно\s+(.+?)(?=,|\.(?:\s|$))",
        explanation.strip(),
        flags=re.I,
    )
    return match.group(1).strip() if match else None


def question_id(hierarchy: str, text: str) -> str:
    payload = f"{hierarchy}\n{' '.join(text.lower().split())}".encode()
    return hashlib.sha256(payload).hexdigest()[:20]


def normalize_question(
    question: dict[str, Any],
    args: argparse.Namespace,
    section: str,
    topic: str,
    *,
    recovered: bool,
) -> dict[str, Any]:
    normalized = dict(question)
    hierarchy = hierarchy_for(section, topic)
    normalized["hierarchy"] = hierarchy
    normalized["origin"] = "notebookLM"
    normalized["image"] = None
    normalized["question_id"] = question_id(hierarchy, str(normalized.get("question", "")))
    normalized.setdefault("hint", None)
    normalized.setdefault(
        "source_reference",
        extract_reference(str(normalized.get("explanation", ""))),
    )
    normalized.setdefault("source_titles", [])
    normalized.setdefault("difficulty", None)
    normalized.setdefault("tags", [section.split(" ➔ ")[-1], topic])
    metadata = normalized.get("metadata")
    if not isinstance(metadata, dict):
        metadata = {}
    metadata.setdefault("schema_version", SCHEMA_VERSION)
    metadata.setdefault("notebook_id", args.notebook_id)
    metadata.setdefault("mind_map_section", section)
    metadata.setdefault("mind_map_topic", topic)
    metadata.setdefault("collector", "TrafficMaster NotebookLM Collector")
    metadata.setdefault("collected_at", datetime.now(UTC).isoformat())
    if recovered:
        normalized["source_reference"] = (
            extract_reference(str(normalized.get("explanation", "")))
            or normalized.get("source_reference")
        )
        metadata.setdefault("recovered_from_session", True)
        metadata.setdefault("available_source_titles", list(SOURCE_TITLES))
        if not normalized.get("hint"):
            metadata.setdefault("hint_status", "not_requested_in_original_prompt")
    normalized["metadata"] = metadata
    return normalized


def validate_questions(
    questions: list[dict[str, Any]],
    section: str,
    topic: str,
    *,
    expected_count: int | None = None,
    require_enriched: bool = False,
) -> None:
    if expected_count is not None and len(questions) != expected_count:
        raise ValueError(f"ожидалось {expected_count}, получено {len(questions)}")
    expected_hierarchy = hierarchy_for(section, topic)
    seen: set[str] = set()
    for index, question in enumerate(questions, start=1):
        text = question.get("question")
        options = question.get("options")
        correct_index = question.get("correct_index")
        if not isinstance(text, str) or not text.strip():
            raise ValueError(f"вопрос {index}: пустой текст")
        normalized_text = " ".join(text.lower().split())
        if normalized_text in seen:
            raise ValueError(f"вопрос {index}: точный дубль")
        seen.add(normalized_text)
        if question.get("hierarchy") != expected_hierarchy:
            raise ValueError(f"вопрос {index}: неверная hierarchy")
        if question.get("origin") != "notebookLM" or question.get("image") is not None:
            raise ValueError(f"вопрос {index}: неверные origin/image")
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
        if require_enriched:
            if not isinstance(question.get("hint"), str) or not question["hint"].strip():
                raise ValueError(f"вопрос {index}: пустая hint")
            if not isinstance(question.get("source_reference"), str) or not question["source_reference"].strip():
                raise ValueError(f"вопрос {index}: пустая source_reference")
            if question.get("difficulty") not in {"easy", "medium", "hard"}:
                raise ValueError(f"вопрос {index}: неверная difficulty")
            tags = question.get("tags")
            if not isinstance(tags, list) or not 2 <= len(tags) <= 6:
                raise ValueError(f"вопрос {index}: нужно от 2 до 6 tags")
            source_titles = question.get("source_titles")
            if not isinstance(source_titles, list) or not source_titles:
                raise ValueError(f"вопрос {index}: пустые source_titles")
            if not set(source_titles).issubset(SOURCE_TITLES):
                raise ValueError(f"вопрос {index}: неизвестный источник")


def atomic_write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    temporary.replace(path)


def batch_candidates(output: Path, index: int, canonical: Path) -> list[Path]:
    candidates = [canonical]
    candidates.extend(sorted(output.glob(f"{index:02d}-*.json")))
    return list(dict.fromkeys(candidates))


def load_partial_batch(
    args: argparse.Namespace,
    index: int,
    section: str,
    topic: str,
    canonical: Path,
) -> list[dict[str, Any]]:
    merged: list[dict[str, Any]] = []
    for candidate in batch_candidates(args.output, index, canonical):
        if not candidate.exists():
            continue
        try:
            raw = json.loads(candidate.read_text(encoding="utf-8"), strict=False)
            if not isinstance(raw, list):
                continue
            normalized = [
                normalize_question(
                    item,
                    args,
                    section,
                    topic,
                    recovered=(
                        not isinstance(item.get("metadata"), dict)
                        or item["metadata"].get("schema_version") != SCHEMA_VERSION
                        or item["metadata"].get("recovered_from_session") is True
                    ),
                )
                for item in raw
                if isinstance(item, dict)
            ]
            validate_questions(normalized, section, topic)
            merged = merge_questions(merged, normalized)
        except (OSError, ValueError, json.JSONDecodeError, TypeError):
            continue
    if merged:
        atomic_write_json(canonical, merged)
    return merged


def save_raw_response(
    output: Path, index: int, attempt: int, raw: str, *, kind: str = "questions"
) -> None:
    timestamp = datetime.now(UTC).strftime("%Y%m%dT%H%M%SZ")
    path = output / "_responses" / (
        f"{index:02d}-{kind}-{timestamp}-attempt-{attempt}.json"
    )
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(raw, encoding="utf-8")


def merge_questions(
    existing: list[dict[str, Any]], additions: list[dict[str, Any]]
) -> list[dict[str, Any]]:
    merged = list(existing)
    seen = {" ".join(item["question"].lower().split()) for item in existing}
    for item in additions:
        key = " ".join(item["question"].lower().split())
        if key not in seen:
            seen.add(key)
            merged.append(item)
    return merged


def collect_topic(
    args: argparse.Namespace,
    ui: TerminalUI,
    index: int,
    section: str,
    topic: str,
    path: Path,
    existing: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    missing = args.questions_per_topic - len(existing)
    prompt = make_prompt(section, topic, missing, existing)
    attempt = 0
    while True:
        attempt += 1
        ui.attempt(attempt, len(existing), args.questions_per_topic)
        raw: str | None = None
        try:
            raw = run_nlm(args, prompt)
            save_raw_response(args.output, index, attempt, raw)
            additions = parse_questions(raw)
            additions = [
                normalize_question(item, args, section, topic, recovered=False)
                for item in additions
            ]
            validate_questions(
                additions,
                section,
                topic,
                expected_count=missing,
                require_enriched=True,
            )
            merged = merge_questions(existing, additions)
            if len(merged) != args.questions_per_topic:
                raise ValueError("NotebookLM повторил уже сохраненный вопрос")
            atomic_write_json(path, merged)
            ui.success(len(additions), len(merged))
            return merged
        except KeyboardInterrupt:
            raise
        except Exception as error:  # noqa: BLE001 - external CLI failures must not stop the run.
            ui.error(str(error))
            if raw is not None:
                path.with_suffix(".last-response.txt").write_text(raw, encoding="utf-8")
            if args.retries and attempt >= args.retries:
                raise RuntimeError(f"тема «{topic}» временно отложена") from error
            delay = min(60.0, 2 ** min(attempt, 6)) + random.uniform(0, 1.5)
            ui.warning(f"повтор через {delay:.1f} с · Ctrl+C безопасно остановит сбор")
            time.sleep(delay)


def has_complete_metadata(question: dict[str, Any]) -> bool:
    return (
        isinstance(question.get("hint"), str)
        and bool(question["hint"].strip())
        and isinstance(question.get("source_reference"), str)
        and bool(question["source_reference"].strip())
        and question.get("difficulty") in {"easy", "medium", "hard"}
        and isinstance(question.get("tags"), list)
        and 2 <= len(question["tags"]) <= 6
        and isinstance(question.get("source_titles"), list)
        and bool(question["source_titles"])
    )


def make_enrichment_prompt(
    section: str, topic: str, questions: list[dict[str, Any]]
) -> str:
    payload = [
        {
            "question_id": item["question_id"],
            "question": item["question"],
            "correct_answer": item["correct_text"],
            "explanation": item["explanation"],
        }
        for item in questions
    ]
    return f"""Дополни метаданные для {len(questions)} уже готовых вопросов по теме «{topic}».

Используй строго источники этого блокнота. Не переписывай вопросы и ответы. Для каждого question_id верни:
- hint: полезная подсказка, которая НЕ раскрывает правильный ответ;
- source_reference: точный пункт, глава, приложение или норма источника;
- source_titles: непустой массив реально использованных названий из списка:
  1. 2005-189(007-070).pdf
  2. Правила дорожного движения Республики Беларусь
  3. Указ № 295 от 04.08.2025
- difficulty: только easy, medium или hard;
- tags: от 2 до 6 коротких тематических тегов.

Раздел карты: «{section}».

Вопросы:
{json.dumps(payload, ensure_ascii=False, indent=2)}

Верни ТОЛЬКО валидный JSON-массив без markdown:
[{{"question_id":"...","hint":"...","source_reference":"пункт ...","source_titles":["..."],"difficulty":"medium","tags":["..."]}}]"""


def validate_enrichment(
    enrichment: list[dict[str, Any]], expected_ids: set[str]
) -> None:
    if len(enrichment) != len(expected_ids):
        raise ValueError(
            f"метаданные: ожидалось {len(expected_ids)}, получено {len(enrichment)}"
        )
    returned_ids = {item.get("question_id") for item in enrichment}
    if returned_ids != expected_ids:
        raise ValueError("метаданные вернулись не для всех question_id")
    for index, item in enumerate(enrichment, start=1):
        if not isinstance(item.get("hint"), str) or not item["hint"].strip():
            raise ValueError(f"метаданные {index}: пустая hint")
        if not isinstance(item.get("source_reference"), str) or not item[
            "source_reference"
        ].strip():
            raise ValueError(f"метаданные {index}: пустая source_reference")
        if item.get("difficulty") not in {"easy", "medium", "hard"}:
            raise ValueError(f"метаданные {index}: неверная difficulty")
        tags = item.get("tags")
        if not isinstance(tags, list) or not 2 <= len(tags) <= 6:
            raise ValueError(f"метаданные {index}: нужно от 2 до 6 tags")
        source_titles = item.get("source_titles")
        if not isinstance(source_titles, list) or not source_titles:
            raise ValueError(f"метаданные {index}: пустые source_titles")
        if not set(source_titles).issubset(SOURCE_TITLES):
            raise ValueError(f"метаданные {index}: неизвестный источник")


def enrich_topic(
    args: argparse.Namespace,
    ui: TerminalUI,
    index: int,
    section: str,
    topic: str,
    path: Path,
    questions: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    missing = [item for item in questions if not has_complete_metadata(item)]
    if not missing:
        return questions
    prompt = make_enrichment_prompt(section, topic, missing)
    attempt = 0
    while True:
        attempt += 1
        print(
            f"         {ui.rgb('↳', 178, 132, 255)} метаданные · "
            f"{len(missing)} вопросов · попытка {attempt}",
            flush=True,
        )
        raw: str | None = None
        try:
            raw = run_nlm(args, prompt)
            save_raw_response(
                args.output, index, attempt, raw, kind="metadata"
            )
            enrichment = parse_questions(raw)
            expected_ids = {item["question_id"] for item in missing}
            validate_enrichment(enrichment, expected_ids)
            by_id = {item["question_id"]: item for item in enrichment}
            for question in questions:
                item = by_id.get(question["question_id"])
                if item is None:
                    continue
                for key in (
                    "hint",
                    "source_reference",
                    "source_titles",
                    "difficulty",
                    "tags",
                ):
                    question[key] = item[key]
                question["metadata"]["enriched_at"] = datetime.now(UTC).isoformat()
                question["metadata"]["hint_status"] = "complete"
            atomic_write_json(path, questions)
            ui.success(len(missing), len(questions))
            return questions
        except KeyboardInterrupt:
            raise
        except Exception as error:  # noqa: BLE001 - external CLI failures must not stop the run.
            ui.error(str(error))
            if raw is not None:
                path.with_suffix(".metadata.last-response.txt").write_text(
                    raw, encoding="utf-8"
                )
            if args.retries and attempt >= args.retries:
                raise RuntimeError(
                    f"метаданные темы «{topic}» временно отложены"
                ) from error
            delay = min(60.0, 2 ** min(attempt, 6)) + random.uniform(0, 1.5)
            ui.warning(f"повтор метаданных через {delay:.1f} с")
            time.sleep(delay)


def preflight(args: argparse.Namespace) -> None:
    if shutil.which("nlm") is None:
        raise RuntimeError("команда nlm не найдена; установите CLI и выполните nlm login")
    command = ["nlm", "notebook", "get", args.notebook_id, "--json"]
    if args.profile:
        command.extend(["--profile", args.profile])
    subprocess.run(command, check=True, capture_output=True, text=True, timeout=60)


def main() -> int:
    args = parse_args()
    if args.questions_per_topic < 1:
        raise ValueError("--questions-per-topic должен быть больше нуля")
    args.output.mkdir(parents=True, exist_ok=True)
    ui = TerminalUI(args.no_color)
    ui.header(len(TOPICS) * args.questions_per_topic, args.output)
    if args.status:
        total = 0
        missing_metadata = 0
        for index, (section, topic) in enumerate(TOPICS, start=1):
            path = canonical_path(args.output, index, topic)
            existing = load_partial_batch(args, index, section, topic, path)
            total += len(existing)
            missing_metadata += sum(
                not has_complete_metadata(item) for item in existing
            )
            state = (
                "done"
                if len(existing) >= args.questions_per_topic
                else "partial"
                if existing
                else "new"
            )
            ui.topic(index, topic, len(existing), args.questions_per_topic, state)
        print()
        print(f"  {ui.rgb('Собрано', 92, 214, 156, bold=True)}: {total}")
        print(f"  {ui.rgb('Нужно дополнить метаданные', 255, 190, 92)}: {missing_metadata}")
        return 0
    preflight(args)

    first_pass = True
    while True:
        pending = 0
        for index, (section, topic) in enumerate(TOPICS, start=1):
            path = canonical_path(args.output, index, topic)
            existing = [] if args.force and first_pass else load_partial_batch(
                args, index, section, topic, path
            )
            if len(existing) >= args.questions_per_topic:
                ui.topic(index, topic, len(existing), args.questions_per_topic, "done")
                continue
            state = "partial" if existing else "new"
            ui.topic(index, topic, len(existing), args.questions_per_topic, state)
            try:
                collect_topic(args, ui, index, section, topic, path, existing)
            except RuntimeError as error:
                pending += 1
                ui.warning(str(error))
        first_pass = False
        if pending == 0:
            break
        ui.warning(f"отложено тем: {pending}; новый проход через 30 секунд")
        time.sleep(30)

    print()
    print(ui.rgb("  Метаданные · подсказки · ссылки на нормы", 178, 132, 255, bold=True))
    print()
    while True:
        pending_metadata = 0
        for index, (section, topic) in enumerate(TOPICS, start=1):
            path = canonical_path(args.output, index, topic)
            questions = load_partial_batch(args, index, section, topic, path)
            missing = sum(not has_complete_metadata(item) for item in questions)
            if missing == 0:
                continue
            ui.topic(index, topic, len(questions), args.questions_per_topic, "done")
            try:
                enrich_topic(
                    args, ui, index, section, topic, path, questions
                )
            except RuntimeError as error:
                pending_metadata += 1
                ui.warning(str(error))
        if pending_metadata == 0:
            break
        ui.warning(
            f"отложено пакетов метаданных: {pending_metadata}; "
            "новый проход через 30 секунд"
        )
        time.sleep(30)

    all_questions: list[dict[str, Any]] = []
    for index, (section, topic) in enumerate(TOPICS, start=1):
        path = canonical_path(args.output, index, topic)
        questions = load_partial_batch(args, index, section, topic, path)
        if len(questions) < args.questions_per_topic:
            raise RuntimeError(f"готовый пакет темы «{topic}» не найден")
        all_questions.extend(questions)

    merged_path = args.output / "all_questions.json"
    atomic_write_json(merged_path, all_questions)
    missing_hints = sum(not item.get("hint") for item in all_questions)
    summary = {
        "schema_version": SCHEMA_VERSION,
        "notebook_id": args.notebook_id,
        "source_titles": list(SOURCE_TITLES),
        "topics": len(TOPICS),
        "questions_per_topic": args.questions_per_topic,
        "questions_per_topic_is_minimum": True,
        "question_count": len(all_questions),
        "questions_without_original_hint": missing_hints,
        "merged_file": merged_path.name,
        "completed_at": datetime.now(UTC).isoformat(),
    }
    atomic_write_json(args.output / "manifest.json", summary)
    ui.complete(len(all_questions), merged_path, missing_hints)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        print("\n\033[38;2;255;190;92m◼ Остановлено. Следующий запуск продолжит с сохраненного места.\033[0m")
        raise SystemExit(130)
    except (RuntimeError, ValueError, subprocess.SubprocessError) as error:
        print(f"\033[38;2;255;104;120m× Ошибка: {error}\033[0m", file=sys.stderr)
        raise SystemExit(1)
