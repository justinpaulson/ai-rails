import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.scrollToBottom()
    this.observeNewMessages()
  }

  disconnect() {
    if (this.observer) {
      this.observer.disconnect()
    }
  }

  observeNewMessages() {
    const messagesContainer = this.element.querySelector("#messages")
    if (!messagesContainer) return

    this.observer = new MutationObserver((mutations) => {
      const hasNewNodes = mutations.some(mutation => mutation.addedNodes.length > 0)
      if (hasNewNodes) {
        this.scrollToBottom()
      }
    })

    this.observer.observe(messagesContainer, {
      childList: true,
      subtree: true
    })
  }

  scrollToBottom() {
    requestAnimationFrame(() => {
      this.element.scrollTop = this.element.scrollHeight
    })
  }
}
