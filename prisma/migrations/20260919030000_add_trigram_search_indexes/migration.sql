CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX "Drug_name_trgm_idx"
  ON "Drug" USING gin ("name" gin_trgm_ops);

CREATE INDEX "Drug_internationalName_trgm_idx"
  ON "Drug" USING gin ("internationalName" gin_trgm_ops);

CREATE INDEX "Disease_name_trgm_idx"
  ON "Disease" USING gin ("name" gin_trgm_ops);

CREATE INDEX "Disease_icd10_trgm_idx"
  ON "Disease" USING gin ("icd10" gin_trgm_ops);

CREATE INDEX "Disease_symptoms_trgm_idx"
  ON "Disease" USING gin ("symptoms" gin_trgm_ops);

CREATE INDEX "Disease_treatment_trgm_idx"
  ON "Disease" USING gin ("treatment" gin_trgm_ops);

CREATE INDEX "Article_title_trgm_idx"
  ON "Article" USING gin ("title" gin_trgm_ops);

CREATE INDEX "Article_description_trgm_idx"
  ON "Article" USING gin ("description" gin_trgm_ops);

CREATE INDEX "Article_content_trgm_idx"
  ON "Article" USING gin ("content" gin_trgm_ops);
