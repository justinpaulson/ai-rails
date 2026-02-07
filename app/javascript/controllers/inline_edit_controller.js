import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["display", "input", "status"]
  static values = { url: String, field: String, syncId: String }

  connect() {
    this.originalValue = this.displayTarget.textContent.trim()
    this.editing = false
  }

  startEdit() {
    if (this.editing) return
    this.editing = true

    this.originalValue = this.displayTarget.textContent.trim()
    this.displayTarget.setAttribute("contenteditable", "true")
    this.displayTarget.focus()

    const range = document.createRange()
    range.selectNodeContents(this.displayTarget)
    const sel = window.getSelection()
    sel.removeAllRanges()
    sel.addRange(range)
  }

  handleKeydown(event) {
    if (!this.editing) return

    if (event.key === "Enter") {
      event.preventDefault()
      this.save()
    } else if (event.key === "Escape") {
      event.preventDefault()
      this.cancel()
    }
  }

  handleBlur() {
    if (!this.editing) return
    this.save()
  }

  cancel() {
    this.displayTarget.textContent = this.originalValue
    this.displayTarget.removeAttribute("contenteditable")
    this.editing = false
  }

  save() {
    const newValue = this.displayTarget.textContent.trim()
    this.displayTarget.removeAttribute("contenteditable")
    this.editing = false

    if (newValue === this.originalValue || newValue === "") {
      this.displayTarget.textContent = this.originalValue
      return
    }

    this.showStatus("saving")

    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
    const body = {}
    body[this.fieldValue] = { title: newValue }

    fetch(this.urlValue, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken,
        "Accept": "application/json"
      },
      body: JSON.stringify(body)
    })
    .then(response => {
      if (response.ok) {
        this.originalValue = newValue
        this.showStatus("saved")
        if (this.hasSyncIdValue) {
          const syncEl = document.getElementById(this.syncIdValue)
          if (syncEl) syncEl.textContent = newValue
        }
      } else {
        this.displayTarget.textContent = this.originalValue
        this.showStatus("error")
      }
    })
    .catch(() => {
      this.displayTarget.textContent = this.originalValue
      this.showStatus("error")
    })
  }

  showStatus(status) {
    if (!this.hasStatusTarget) return

    const messages = { saving: "Saving...", saved: "Saved", error: "Error" }
    this.statusTarget.textContent = messages[status] || ""
    this.statusTarget.classList.remove("hidden")
    this.statusTarget.classList.toggle("text-yellow-400", status === "saving")
    this.statusTarget.classList.toggle("text-green-400", status === "saved")
    this.statusTarget.classList.toggle("text-red-400", status === "error")

    if (status === "saved") {
      setTimeout(() => {
        this.statusTarget.classList.add("hidden")
        this.statusTarget.textContent = ""
      }, 2000)
    }
  }
}
