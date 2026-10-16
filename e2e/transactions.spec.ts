import { expect, test } from "@playwright/test"

test("filtra e cria uma transação em memória", async ({ page }) => {
  await page.goto("/")

  await expect(page.getByRole("heading", { name: "Transações" })).toBeVisible()

  const search = page.getByPlaceholder("Buscar...")
  await search.fill("atlas")
  await expect(page.getByText("Projeto Atlas")).toBeVisible()
  await expect(page.getByText("Almoço no Mercado")).toBeHidden()

  await search.clear()
  await page.getByRole("button", { name: "Nova transação" }).click()
  const dialog = page.getByRole("dialog", { name: "Nova transação" })
  await dialog.getByLabel("Descrição").fill("Curso de fotografia")
  await dialog.getByLabel("Valor").fill("320")
  await dialog.getByRole("button", { name: "Salvar transação" }).click()

  await expect(page.getByText("Curso de fotografia")).toBeVisible()

  await page.reload()
  await expect(page.getByText("Curso de fotografia")).toHaveCount(0)
  await expect(page.getByText("8 transações encontradas").first()).toBeVisible()
})
