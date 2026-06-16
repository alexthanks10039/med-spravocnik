# Archived Node/PostgreSQL MVP

This directory contains the repository state that existed before the local
Python/FastAPI implementation was synchronized.

It is retained for reference because it includes useful UI concepts, Prisma
models, JWT middleware and Docker examples. It is not the active application
and is not started by the root setup instructions.

Known limitations of this MVP:

- Flutter uses an offline mock repository;
- RAG searches a small static array rather than the medical corpus;
- only BMI and eGFR calculators are implemented;
- the seed contains a published demo administrator password;
- there are no backend tests.
