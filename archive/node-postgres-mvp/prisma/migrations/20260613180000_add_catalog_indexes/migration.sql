-- CreateIndex
CREATE INDEX "User_role_idx" ON "User"("role");

-- CreateIndex
CREATE INDEX "Drug_name_idx" ON "Drug"("name");

-- CreateIndex
CREATE INDEX "Drug_internationalName_idx" ON "Drug"("internationalName");

-- CreateIndex
CREATE INDEX "Disease_name_idx" ON "Disease"("name");

-- CreateIndex
CREATE INDEX "Disease_icd10_idx" ON "Disease"("icd10");

-- CreateIndex
CREATE INDEX "Article_category_idx" ON "Article"("category");

-- CreateIndex
CREATE INDEX "Article_isPublished_updatedAt_idx" ON "Article"("isPublished", "updatedAt");
