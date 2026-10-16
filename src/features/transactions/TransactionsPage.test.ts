import { render, screen, within } from "@testing-library/vue"
import userEvent from "@testing-library/user-event"
import { createPinia } from "pinia"
import { describe, expect, it } from "vitest"

import App from "@/App.vue"

function renderApp() {
  return render(App, {
    global: {
      plugins: [createPinia()],
    },
  })
}

describe("Tela de Transações", () => {
  it("filtra as transações pelos termos visíveis", async () => {
    const user = userEvent.setup()
    renderApp()

    expect(screen.getByRole("heading", { name: "Transações" })).toBeVisible()
    expect(screen.getByText("Almoço no Mercado")).toBeVisible()

    const search = screen.getByPlaceholderText("Buscar...")
    expect(search).toHaveClass("text-xs", "pl-7")
    expect(search.parentElement?.querySelector(".lucide-search")).toBeVisible()

    await user.type(search, "atlas")

    expect(screen.getByText("Projeto Atlas")).toBeVisible()
    expect(screen.queryByText("Almoço no Mercado")).not.toBeInTheDocument()
    expect(screen.getAllByText("1 transação encontrada")[0]).toBeVisible()
  })

  it("mostra e aplica diretamente as opções de instituição", async () => {
    const user = userEvent.setup()
    renderApp()

    await user.click(
      screen.getByRole("button", { name: "Filtrar instituição" })
    )
    await user.click(screen.getByRole("button", { name: "Nubank" }))

    expect(screen.getByText("Almoço no Mercado")).toBeVisible()
    expect(screen.queryByText("Projeto Atlas")).not.toBeInTheDocument()
    expect(screen.getAllByText("3 transações encontradas")[0]).toBeVisible()
    expect(
      screen.getByRole("button", {
        name: "Alterar filtro de instituição: Nubank",
      })
    ).toBeVisible()
    expect(
      screen.getByRole("button", {
        name: "Remover filtro de instituição: Nubank",
      })
    ).toBeVisible()
  })

  it("combina e remove filtros da mesma coluna", async () => {
    const user = userEvent.setup()
    renderApp()

    await user.click(
      screen.getByRole("button", { name: "Filtrar instituição" })
    )
    await user.click(screen.getByRole("button", { name: "Nubank" }))
    await user.click(screen.getByRole("button", { name: "Itaú" }))

    expect(screen.getAllByText("5 transações encontradas")[0]).toBeVisible()
    expect(
      screen.getByRole("button", {
        name: "Remover filtro de instituição: Nubank",
      })
    ).toBeVisible()
    const additionalFilters = screen.getByRole("button", {
      name: "Mostrar 1 filtro adicional de instituição",
    })
    expect(additionalFilters).toHaveTextContent("+1")
    expect(additionalFilters.querySelector("svg")).not.toBeInTheDocument()

    await user.hover(additionalFilters)
    await user.click(
      await screen.findByRole("button", {
        name: "Remover filtro de instituição: Itaú",
      })
    )

    expect(screen.getByText("Almoço no Mercado")).toBeVisible()
    expect(screen.queryByText("Projeto Atlas")).not.toBeInTheDocument()
    expect(screen.getAllByText("3 transações encontradas")[0]).toBeVisible()
  })

  it("ordena as transações pelo cabeçalho da coluna", async () => {
    const user = userEvent.setup()
    renderApp()

    await user.click(screen.getByRole("button", { name: "Ordenar por valor" }))

    const rows = screen.getAllByRole("row")
    expect(within(rows[1]).getByText("Figma Professional")).toBeVisible()
    expect(
      screen.getByRole("button", {
        name: "Valor: ordem crescente. Alterar ordenação",
      })
    ).toBeVisible()
    expect(
      screen.queryByRole("button", { name: "Filtrar data" })
    ).not.toBeInTheDocument()
  })

  it("cria uma transação durante a sessão", async () => {
    const user = userEvent.setup()
    renderApp()

    await user.click(screen.getByRole("button", { name: "Nova transação" }))

    const dialog = screen.getByRole("dialog", { name: "Nova transação" })
    await user.type(
      within(dialog).getByLabelText("Descrição"),
      "Curso de fotografia"
    )
    await user.clear(within(dialog).getByLabelText("Valor"))
    await user.type(within(dialog).getByLabelText("Valor"), "320")
    const date = within(dialog).getByLabelText("Data")
    const save = within(dialog).getByRole("button", {
      name: "Salvar transação",
    })
    await user.clear(date)
    expect(save).toBeDisabled()
    await user.type(date, "2026-10-16")
    await user.click(save)

    expect(screen.getByText("Curso de fotografia")).toBeVisible()
    expect(
      screen.getByText((content) => content.includes("320,00"))
    ).toBeVisible()
  })

  it("associa os seletores do formulário aos seus rótulos", async () => {
    const user = userEvent.setup()
    renderApp()

    await user.click(screen.getByRole("button", { name: "Nova transação" }))

    const dialog = screen.getByRole("dialog", { name: "Nova transação" })
    expect(within(dialog).getByRole("combobox", { name: "Tipo" })).toBeVisible()
    expect(
      within(dialog).getByRole("combobox", { name: "Categoria" })
    ).toBeVisible()
    expect(
      within(dialog).getByRole("combobox", { name: "Instituição" })
    ).toBeVisible()
  })

  it("edita uma transação durante a sessão", async () => {
    const user = userEvent.setup()
    renderApp()

    await user.click(
      screen.getByRole("button", { name: "Editar Almoço no Mercado" })
    )

    const dialog = screen.getByRole("dialog", { name: "Editar transação" })
    const description = within(dialog).getByLabelText("Descrição")
    await user.clear(description)
    await user.type(description, "Almoço com o time")
    await user.click(
      within(dialog).getByRole("button", { name: "Salvar alterações" })
    )

    expect(screen.getByText("Almoço com o time")).toBeVisible()
    expect(screen.queryByText("Almoço no Mercado")).not.toBeInTheDocument()
  })

  it("exclui uma transação durante a sessão", async () => {
    const user = userEvent.setup()
    renderApp()

    await user.click(
      screen.getByRole("button", { name: "Excluir Almoço no Mercado" })
    )
    const confirmation = screen.getByRole("alertdialog")
    await user.click(
      within(confirmation).getByRole("button", { name: "Excluir" })
    )

    expect(screen.queryByText("Almoço no Mercado")).not.toBeInTheDocument()
    expect(screen.getAllByText("7 transações encontradas")[0]).toBeVisible()
  })
})
