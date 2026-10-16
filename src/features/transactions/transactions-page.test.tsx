import { render, screen, within } from "@testing-library/react"
import userEvent from "@testing-library/user-event"
import { describe, expect, it } from "vitest"

import { App } from "@/App"

describe("Tela de Transações", () => {
  it("filtra as transações pelos termos visíveis", async () => {
    const user = userEvent.setup()
    render(<App />)

    expect(screen.getByRole("heading", { name: "Transações" })).toBeVisible()
    expect(screen.getByText("Almoço no Mercado")).toBeVisible()

    await user.type(
      screen.getByPlaceholderText("Descrição, categoria ou conta"),
      "atlas"
    )

    expect(screen.getByText("Projeto Atlas")).toBeVisible()
    expect(screen.queryByText("Almoço no Mercado")).not.toBeInTheDocument()
    expect(screen.getAllByText("1 transação encontrada")[0]).toBeVisible()
  })

  it("cria uma transação durante a sessão", async () => {
    const user = userEvent.setup()
    render(<App />)

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

  it("edita uma transação durante a sessão", async () => {
    const user = userEvent.setup()
    render(<App />)

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
    render(<App />)

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
