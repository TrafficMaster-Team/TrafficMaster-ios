import type { Metadata } from "next";
import Link from "next/link";
import { LegalShell } from "../_components/LegalShell";

export const metadata: Metadata = {
  title: "Поддержка",
  description: "Помощь и контакты команды TrafficMaster.",
};

export default function SupportPage() {
  return (
    <LegalShell label="Помощь" updated="28 июля 2026">
      <h1>Поддержка TrafficMaster</h1>
      <p className="lede">
        Поможем со входом, синхронизацией, вопросами по обучению и удалением
        аккаунта.
      </p>

      <section>
        <h2>Перед обращением</h2>
        <ol>
          <li>Проверьте подключение к интернету.</li>
          <li>Полностью закройте и снова откройте приложение.</li>
          <li>Убедитесь, что используете актуальную версию TrafficMaster.</li>
        </ol>
      </section>

      <section>
        <h2>Что указать в сообщении</h2>
        <p>
          Опишите, что вы делали перед ошибкой, приложите скриншот и укажите
          модель iPhone и версию iOS. Не отправляйте пароль или другие секретные
          данные.
        </p>
      </section>

      <section className="contact-card">
        <h2>Связаться с командой</h2>
        <p>
          Основной канал поддержки — Telegram. Сообщения обрабатывает команда
          TrafficMaster.
        </p>
        <a href="https://t.me/traffic_master_team">
          Написать @traffic_master_team
        </a>
      </section>

      <section>
        <h2>Управление данными</h2>
        <p>
          Узнайте, какие данные используются приложением, или откройте
          инструкцию по полному удалению аккаунта.
        </p>
        <p>
          <Link href="/privacy">Политика конфиденциальности</Link>
          {" · "}
          <Link href="/delete-account">Удаление аккаунта</Link>
        </p>
      </section>
    </LegalShell>
  );
}
