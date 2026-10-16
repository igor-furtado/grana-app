document.querySelectorAll("[data-quiz]").forEach((quiz) => {
  const feedback = quiz.querySelector("[data-feedback]")

  quiz.querySelectorAll("button[data-answer]").forEach((button) => {
    button.addEventListener("click", () => {
      const isCorrect = button.dataset.answer === "correct"

      quiz.querySelectorAll("button[data-answer]").forEach((candidate) => {
        candidate.classList.remove("correct", "incorrect")
      })

      button.classList.add(isCorrect ? "correct" : "incorrect")
      feedback.textContent = isCorrect
        ? quiz.dataset.success
        : quiz.dataset.retry
    })
  })
})
