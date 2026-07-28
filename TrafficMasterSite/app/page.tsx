import Link from "next/link";

const features = [
  {
    number: "01",
    title: "Интервальные повторения",
    text: "TrafficMaster планирует повторения по истории ответов, чтобы сложные вопросы возвращались вовремя.",
  },
  {
    number: "02",
    title: "Подготовка по главам",
    text: "Изучайте ПДД последовательно, отслеживайте прогресс и возвращайтесь к материалу, который требует внимания.",
  },
  {
    number: "03",
    title: "Понятные объяснения",
    text: "Подсказки, разбор вариантов и AI-репетитор помогают понять правило, а не запомнить номер ответа.",
  },
];

export default function Home() {
  return (
    <main>
      <header className="site-header">
        <Link className="brand" href="/" aria-label="TrafficMaster — главная">
          <span className="brand-mark">TM</span>
          <span>TrafficMaster</span>
        </Link>
        <nav aria-label="Основная навигация">
          <Link href="/privacy">Конфиденциальность</Link>
          <Link href="/support">Поддержка</Link>
        </nav>
      </header>

      <section className="hero">
        <div className="eyebrow">ПДД • интервальное повторение • iPhone</div>
        <h1>
          Учитесь осмысленно.
          <br />
          <span>Повторяйте вовремя.</span>
        </h1>
        <p className="hero-copy">
          TrafficMaster превращает подготовку к экзамену по ПДД в ясный
          ежедневный маршрут: новые вопросы, повторение пройденного и
          измеримый прогресс.
        </p>
        <div className="hero-actions">
          <Link className="primary-button" href="/support">
            Получить поддержку
          </Link>
          <Link className="secondary-button" href="/privacy">
            Как мы защищаем данные
          </Link>
        </div>
        <div className="signal-row" aria-label="Ключевые свойства">
          <span>Без рекламы</span>
          <span>Без трекинга</span>
          <span>HTTPS-синхронизация</span>
        </div>
      </section>

      <section className="feature-grid" aria-label="Возможности TrafficMaster">
        {features.map((feature) => (
          <article className="feature-card" key={feature.number}>
            <span className="feature-number">{feature.number}</span>
            <h2>{feature.title}</h2>
            <p>{feature.text}</p>
          </article>
        ))}
      </section>

      <section className="trust-panel">
        <div>
          <div className="eyebrow">Ваши данные — не бизнес-модель</div>
          <h2>Только то, что нужно для работы приложения.</h2>
        </div>
        <p>
          Учётные данные и прогресс используются для входа и синхронизации.
          Аватар остаётся на устройстве. Мы не продаём данные и не используем
          рекламные идентификаторы.
        </p>
      </section>

      <footer>
        <span>© 2026 TrafficMaster</span>
        <div>
          <Link href="/privacy">Политика</Link>
          <Link href="/support">Поддержка</Link>
          <Link href="/delete-account">Удаление аккаунта</Link>
        </div>
      </footer>
    </main>
  );
}
