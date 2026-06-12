import bcrypt from 'bcryptjs';
import { PrismaClient, Role } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  const password = await bcrypt.hash('Admin123!', 10);

  await prisma.user.upsert({
    where: { email: 'admin@med.local' },
    update: { role: Role.ADMIN },
    create: { email: 'admin@med.local', password, role: Role.ADMIN },
  });

  await Promise.all([
    prisma.disease.upsert({
      where: { id: 'seed-hypertension' },
      update: {},
      create: {
        id: 'seed-hypertension',
        name: 'Артериальная гипертензия',
        icd10: 'I10',
        symptoms: 'Часто протекает бессимптомно; возможны головная боль и головокружение.',
        diagnostics: 'Повторные измерения АД, домашний или суточный мониторинг, оценка органов-мишеней.',
        treatment: 'Изменение образа жизни и персонализированная антигипертензивная терапия.',
      },
    }),
    prisma.disease.upsert({
      where: { id: 'seed-pneumonia' },
      update: {},
      create: {
        id: 'seed-pneumonia',
        name: 'Внебольничная пневмония',
        icd10: 'J18',
        symptoms: 'Лихорадка, кашель, одышка, плевральная боль.',
        diagnostics: 'Оценка витальных функций, сатурации, тяжести и визуализация по показаниям.',
        treatment: 'Тактика зависит от тяжести, коморбидности и локальной резистентности.',
      },
    }),
    prisma.drug.upsert({
      where: { id: 'seed-amlodipine' },
      update: {},
      create: {
        id: 'seed-amlodipine',
        name: 'Амлодипин',
        internationalName: 'Amlodipine',
        form: 'Таблетки',
        dosage: 'Обычно 5 мг 1 раз в сутки; диапазон 2,5–10 мг.',
        indications: 'Артериальная гипертензия и стабильная стенокардия.',
        contraindications: 'Гиперчувствительность; осторожность при выраженной гипотензии.',
        sideEffects: 'Периферические отёки, головная боль, приливы.',
        analogs: ['Норваск', 'Амлотоп'],
      },
    }),
    prisma.drug.upsert({
      where: { id: 'seed-amoxicillin' },
      update: {},
      create: {
        id: 'seed-amoxicillin',
        name: 'Амоксициллин',
        internationalName: 'Amoxicillin',
        form: 'Таблетки и суспензия',
        dosage: 'Зависит от инфекции, возраста, массы тела и функции почек.',
        indications: 'Чувствительные бактериальные инфекции.',
        contraindications: 'Гиперчувствительность к бета-лактамным антибиотикам.',
        sideEffects: 'Тошнота, диарея, кожная сыпь.',
        analogs: ['Флемоксин Солютаб', 'Оспамокс'],
      },
    }),
  ]);

  await Promise.all([
    prisma.article.upsert({
      where: { slug: 'chest-pain-first-assessment' },
      update: {},
      create: {
        id: 'seed-chest-pain',
        title: 'Первичная оценка боли в груди',
        slug: 'chest-pain-first-assessment',
        category: 'Неотложная помощь',
        description: 'Короткий алгоритм первичной оценки и красные флаги.',
        content: 'Оцените витальные функции, характеристики боли и признаки гемодинамической нестабильности.',
        tags: ['неотложная помощь', 'кардиология', 'алгоритм'],
      },
    }),
    prisma.article.upsert({
      where: { slug: 'antibiotic-stewardship' },
      update: {},
      create: {
        id: 'seed-antibiotics',
        title: 'Рациональная антибиотикотерапия',
        slug: 'antibiotic-stewardship',
        category: 'Клинические рекомендации',
        description: 'Практические принципы выбора и пересмотра терапии.',
        content: 'Уточните очаг инфекции, тяжесть, аллергологический анамнез и локальную резистентность.',
        tags: ['антибиотики', 'безопасность', 'рекомендации'],
      },
    }),
  ]);

  console.log('Database seeded: admin@med.local / Admin123!');
}

main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
