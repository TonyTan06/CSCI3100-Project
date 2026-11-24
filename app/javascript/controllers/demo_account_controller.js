import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["email", "password"]

  fill(event) {
    this.emailTarget.value = event.currentTarget.dataset.email
    this.passwordTarget.value = event.currentTarget.dataset.password
  }
}
