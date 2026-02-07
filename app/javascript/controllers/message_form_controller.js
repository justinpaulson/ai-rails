import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "submit"]

  connect() {
    this.autoResize()
  }

  handleKeydown(event) {
    if (event.key === "Enter") {
      if (event.shiftKey) {
        event.preventDefault()
        const input = this.inputTarget
        const start = input.selectionStart
        const end = input.selectionEnd
        input.value = input.value.substring(0, start) + "\n" + input.value.substring(end)
        input.selectionStart = input.selectionEnd = start + 1
        this.autoResize()
      } else {
        event.preventDefault()
        this.element.requestSubmit()
      }
    }
  }

  autoResize() {
    const input = this.inputTarget
    input.style.height = "auto"
    input.style.height = Math.min(input.scrollHeight, 200) + "px"
  }

  reset() {
    this.inputTarget.value = ""
    this.inputTarget.style.height = "auto"
    this.inputTarget.focus()
  }
}
