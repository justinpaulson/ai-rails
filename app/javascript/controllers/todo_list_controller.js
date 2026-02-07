import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "content", "chevron"]

  connect() {
    this.collapsed = false
  }

  toggle() {
    this.collapsed = !this.collapsed

    if (this.collapsed) {
      this.contentTarget.classList.add("hidden")
      this.chevronTarget.classList.add("rotate-180")
    } else {
      this.contentTarget.classList.remove("hidden")
      this.chevronTarget.classList.remove("rotate-180")
    }
  }
}
